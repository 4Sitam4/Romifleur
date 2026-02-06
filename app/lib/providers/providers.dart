import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:romifleur/services/background_service.dart';
import 'package:romifleur/services/config_service.dart';
import 'package:romifleur/services/rom_service.dart';
import 'package:romifleur/services/metadata_service.dart';
import 'package:romifleur/services/ra_service.dart';
import 'package:romifleur/services/update_service.dart';
import 'package:romifleur/services/local_scanner_service.dart';
import 'package:romifleur/utils/cancellation_token.dart';
import 'package:romifleur/utils/logger.dart';
import '../models/console.dart';
import '../models/rom.dart';
import '../models/ownership_status.dart';
import '../models/download.dart';

const _log = AppLogger('Providers');

// ===== SERVICE PROVIDERS =====
final configServiceProvider = Provider<ConfigService>((ref) => ConfigService());
final romServiceProvider = Provider<RomService>((ref) => RomService());
final metadataServiceProvider = Provider<MetadataService>(
  (ref) => MetadataService(),
);
final raServiceProvider = Provider<RaService>((ref) => RaService());
final updateServiceProvider = Provider<UpdateService>((ref) => UpdateService());
final localScannerServiceProvider = Provider<LocalScannerService>(
  (ref) => LocalScannerService(),
);
final backgroundServiceProvider = Provider<BackgroundService>(
  (ref) => BackgroundService(),
);

// ===== CONSOLES PROVIDER =====
final consolesProvider = FutureProvider<List<CategoryModel>>((ref) async {
  final config = ref.watch(configServiceProvider);
  await config.init();

  final data = config.consoles;
  final List<CategoryModel> categories = [];

  data.forEach((catName, consolesMap) {
    final List<ConsoleModel> consoles = [];
    consolesMap.forEach((key, val) {
      final Map<String, dynamic> consoleData = Map.from(val);
      consoleData['key'] = key;
      consoles.add(ConsoleModel.fromJson(consoleData));
    });
    categories.add(CategoryModel(category: catName, consoles: consoles));
  });

  return categories;
});

// ===== SELECTED CONSOLE STATE =====
class SelectedConsoleState {
  final String? category;
  final ConsoleModel? console;

  const SelectedConsoleState({this.category, this.console});
}

final selectedConsoleProvider = StateProvider<SelectedConsoleState>((ref) {
  return const SelectedConsoleState();
});

// ===== ROMS PROVIDER =====
class RomsState {
  final List<RomModel> roms;
  final bool isLoading;
  final String? error;
  final String searchQuery;
  final Set<String> selectedRegions;
  final Set<String> selectedLanguages;
  final bool hideDemos;
  final bool hideBetas;
  final bool hideUnlicensed;
  final bool onlyRa;
  final bool hideOwned;
  final bool hidePartial;

  const RomsState({
    this.roms = const [],
    this.isLoading = false,
    this.error,
    this.searchQuery = '',
    this.selectedRegions = const {'Europe', 'USA', 'Japan', 'World'},
    this.selectedLanguages = const {},
    this.hideDemos = true,
    this.hideBetas = true,
    this.hideUnlicensed = true,
    this.onlyRa = false,
    this.hideOwned = false,
    this.hidePartial = false,
  });

  RomsState copyWith({
    List<RomModel>? roms,
    bool? isLoading,
    String? error,
    String? searchQuery,
    Set<String>? selectedRegions,
    Set<String>? selectedLanguages,
    bool? hideDemos,
    bool? hideBetas,
    bool? hideUnlicensed,
    bool? onlyRa,
    bool? hideOwned,
    bool? hidePartial,
  }) {
    return RomsState(
      roms: roms ?? this.roms,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedRegions: selectedRegions ?? this.selectedRegions,
      selectedLanguages: selectedLanguages ?? this.selectedLanguages,
      hideDemos: hideDemos ?? this.hideDemos,
      hideBetas: hideBetas ?? this.hideBetas,
      hideUnlicensed: hideUnlicensed ?? this.hideUnlicensed,
      onlyRa: onlyRa ?? this.onlyRa,
      hideOwned: hideOwned ?? this.hideOwned,
      hidePartial: hidePartial ?? this.hidePartial,
    );
  }

  int get selectedCount => roms.where((r) => r.isSelected).length;
}

class RomsNotifier extends StateNotifier<RomsState> {
  final RomService romService;
  final RaService raService;
  final LocalScannerService localScannerService;
  final ConfigService configService;
  String? _currentCategory;
  String? _currentConsoleKey;

  // Cached local file scan results to avoid redundant filesystem scans on filter changes
  List<String>? _cachedLocalFiles;
  String? _cachedScanPath;
  String? _cachedScanSubfolder;

  RomsNotifier(
    this.romService,
    this.raService,
    this.localScannerService,
    this.configService,
  ) : super(const RomsState());

  Future<void> loadRoms(String category, String consoleKey) async {
    _currentCategory = category;
    _currentConsoleKey = consoleKey;
    _cachedLocalFiles = null; // Invalidate ownership cache on console change
    _refresh();
  }

  Future<void> _refresh({bool skipLoadingFlag = false}) async {
    if (_currentCategory == null || _currentConsoleKey == null) return;

    if (!skipLoadingFlag) {
      state = state.copyWith(isLoading: true, error: null);
    }

    try {
      // 1. Fetch filtered list (no deduplication - show all versions)
      var roms = await romService.search(
        _currentCategory!,
        _currentConsoleKey!,
        state.searchQuery,
        regions: state.selectedRegions.toList(),
        languages: state.selectedLanguages.toList(),
        hideDemos: state.hideDemos,
        hideBetas: state.hideBetas,
        hideUnlicensed: state.hideUnlicensed,
      );

      // 2. Filter RA if checked
      if (state.onlyRa) {
        await raService.init(); // ensure loaded
        final List<RomModel> filtered = [];
        for (var rom in roms) {
          if (await raService.checkRomCompatibility(
            _currentConsoleKey!,
            rom.filename,
          )) {
            filtered.add(
              RomModel(
                filename: rom.filename,
                size: rom.size,
                hasAchievements: true,
              ),
            );
          }
        }
        roms = filtered;
      }

      // 3. Scan for local ROMs and set ownership status
      try {
        roms = await _applyOwnershipStatus(roms);

        // 4. Filter by Ownership Logic (Client-side)
        if (state.hideOwned || state.hidePartial) {
          // Optimization check
          roms = roms.where((rom) {
            if (state.hideOwned &&
                rom.ownershipStatus == OwnershipStatus.fullMatch)
              return false;
            if (state.hidePartial &&
                rom.ownershipStatus == OwnershipStatus.partialMatch)
              return false;
            return true;
          }).toList();
        }
      } catch (e) {
        _log.warning('Ownership scan failed: $e');
        // Continue without ownership info
      }

      state = state.copyWith(roms: roms, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void setSearch(String query) {
    // Store the query in state and refresh in one go via _refresh
    // which will read searchQuery from state
    state = state.copyWith(searchQuery: query, isLoading: true);
    _refresh(skipLoadingFlag: true);
  }

  void toggleRegion(String region) {
    final regions = Set<String>.from(state.selectedRegions);
    if (regions.contains(region)) {
      regions.remove(region);
    } else {
      regions.add(region);
    }
    state = state.copyWith(selectedRegions: regions);
    _refresh();
  }

  void toggleOnlyRa() {
    state = state.copyWith(onlyRa: !state.onlyRa);
    _refresh();
  }

  void toggleHideDemos() {
    state = state.copyWith(hideDemos: !state.hideDemos);
    _refresh();
  }

  void toggleHideBetas() {
    state = state.copyWith(hideBetas: !state.hideBetas);
    _refresh();
  }

  void toggleHideUnlicensed() {
    state = state.copyWith(hideUnlicensed: !state.hideUnlicensed);
    _refresh();
  }

  void toggleHideOwned() {
    state = state.copyWith(hideOwned: !state.hideOwned);
    _refresh();
  }

  void toggleHidePartial() {
    state = state.copyWith(hidePartial: !state.hidePartial);
    _refresh();
  }

  void toggleLanguage(String language) {
    final languages = Set<String>.from(state.selectedLanguages);
    if (languages.contains(language)) {
      languages.remove(language);
    } else {
      languages.add(language);
    }
    state = state.copyWith(selectedLanguages: languages);
    _refresh();
  }

  void toggleRomSelection(int index) {
    if (index < 0 || index >= state.roms.length) return;
    final roms = List<RomModel>.from(state.roms);
    roms[index] = roms[index].copyWith(isSelected: !roms[index].isSelected);
    state = state.copyWith(roms: roms);
  }

  void selectAll() {
    final roms = state.roms.map((r) => r.copyWith(isSelected: true)).toList();
    state = state.copyWith(roms: roms);
  }

  void deselectAll() {
    final roms = state.roms.map((r) => r.copyWith(isSelected: false)).toList();
    state = state.copyWith(roms: roms);
  }

  List<RomModel> getSelectedRoms() {
    return state.roms.where((r) => r.isSelected).toList();
  }

  /// Refresh only ownership status without reloading roms
  Future<void> refreshOwnership() async {
    if (_currentConsoleKey == null) return;
    _cachedLocalFiles = null; // Force rescan after download
    try {
      final roms = await _applyOwnershipStatus(state.roms);
      state = state.copyWith(roms: roms);
    } catch (e) {
      _log.warning('Ownership refresh failed: $e');
    }
  }

  /// Apply ownership status to ROMs based on local scan
  Future<List<RomModel>> _applyOwnershipStatus(List<RomModel> roms) async {
    if (_currentConsoleKey == null) return roms;

    // Get console folder path
    final consoleConfig = configService.consoles.values
        .expand((m) => m.entries)
        .where((e) => e.key == _currentConsoleKey)
        .firstOrNull;

    final defaultFolder = consoleConfig?.value['folder'] ?? _currentConsoleKey!;
    final customPath = configService.getConsolePath(_currentConsoleKey!);

    // Determine scan path
    String scanPath;
    String? subfolder;

    if (customPath != null && customPath.isNotEmpty) {
      scanPath = customPath;
    } else {
      // For natives: use downloadPath + defaultFolder (as subfolder for SAF)
      // For web: just send the folder name (server handles it)
      final downloadPath = await configService.getEffectiveDownloadLocation();
      if (downloadPath != null) {
        scanPath = downloadPath;
        subfolder = defaultFolder;
      } else {
        scanPath = defaultFolder; // Web uses just folder name
      }
    }

    // Scan for local ROMs (use cached results if path hasn't changed)
    final extensions = [
      '.zip',
      '.7z',
      '.nes',
      '.sfc',
      '.smc',
      '.gba',
      '.gbc',
      '.gb',
      '.nds',
      '.3ds',
      '.cia',
      '.n64',
      '.z64',
      '.v64',
      '.iso',
      '.bin',
      '.chd',
      '.cso',
      '.pbp',
      '.gen',
      '.md',
      '.smd',
    ];

    List<String> localFiles;
    if (_cachedLocalFiles != null &&
        _cachedScanPath == scanPath &&
        _cachedScanSubfolder == subfolder) {
      localFiles = _cachedLocalFiles!;
    } else {
      localFiles = await localScannerService.scanLocalRoms(
        scanPath,
        extensions,
        subfolder: subfolder,
      );
      _cachedLocalFiles = localFiles;
      _cachedScanPath = scanPath;
      _cachedScanSubfolder = subfolder;
    }

    if (localFiles.isEmpty) return roms;

    // Apply ownership status to each ROM
    return roms.map((rom) {
      final status = localScannerService.checkOwnership(
        rom.filename,
        localFiles,
      );
      return rom.copyWith(ownershipStatus: status);
    }).toList();
  }
}

final romsProvider = StateNotifierProvider<RomsNotifier, RomsState>((ref) {
  return RomsNotifier(
    ref.watch(romServiceProvider),
    ref.watch(raServiceProvider),
    ref.watch(localScannerServiceProvider),
    ref.watch(configServiceProvider),
  );
});

// ===== DOWNLOAD QUEUE PROVIDER =====
class DownloadQueueState {
  final List<DownloadItem> items;
  final DownloadProgress progress;
  final bool isLoading;
  final String totalSize;

  const DownloadQueueState({
    this.items = const [],
    this.progress = const DownloadProgress(),
    this.isLoading = false,
    this.totalSize = '0 B',
  });

  DownloadQueueState copyWith({
    List<DownloadItem>? items,
    DownloadProgress? progress,
    bool? isLoading,
    String? totalSize,
  }) {
    return DownloadQueueState(
      items: items ?? this.items,
      progress: progress ?? this.progress,
      isLoading: isLoading ?? this.isLoading,
      totalSize: totalSize ?? this.totalSize,
    );
  }
}

class DownloadQueueNotifier extends StateNotifier<DownloadQueueState> {
  final RomService romService;
  final ConfigService configService;
  final RomsNotifier romsNotifier;
  final BackgroundService backgroundService;
  DownloadCancellationToken? _cancelToken;
  int _lastPercentage = -1;

  DownloadQueueNotifier(
    this.romService,
    this.configService,
    this.romsNotifier,
    this.backgroundService,
  ) : super(const DownloadQueueState());

  void cancelCurrentDownload() {
    _cancelToken?.cancel();
    _cancelToken = null;
  }

  void addToQueue(String category, String console, List<RomModel> roms) {
    if (roms.isEmpty) return;

    // User Requirement: Block adding while downloading
    if (state.progress.isDownloading || state.isLoading) {
      // In a real app we'd show a Toast. Here we just return.
      // The UI buttons will be disabled anyway.
      return;
    }

    final currentItems = List<DownloadItem>.from(state.items);
    double currentBytes = _parseSizeToBytes(state.totalSize);

    for (var rom in roms) {
      if (!currentItems.any(
        (i) => i.filename == rom.filename && i.console == console,
      )) {
        currentItems.add(
          DownloadItem(
            category: category,
            console: console,
            filename: rom.filename,
            size: rom.size,
          ),
        );
        currentBytes += _parseSizeToBytes(rom.size);
      }
    }

    var p = state.progress;
    if (state.items.isEmpty && currentItems.isNotEmpty) {
      p = DownloadProgress(
        total: currentItems.length,
        current: 0,
        status: 'Ready',
      );
    } else {
      p = DownloadProgress(
        total: currentItems.length,
        current: state.progress.current,
        status: state.progress.status,
        isDownloading: state.progress.isDownloading,
      );
    }

    state = state.copyWith(
      items: currentItems,
      progress: p,
      totalSize: _formatBytes(currentBytes),
    );
  }

  void removeFromQueue(int index) {
    if (index < 0 || index >= state.items.length) return;
    final items = List<DownloadItem>.from(state.items);
    final removed = items.removeAt(index);

    double currentBytes = _parseSizeToBytes(state.totalSize);
    currentBytes -= _parseSizeToBytes(removed.size);
    if (currentBytes < 0) currentBytes = 0;

    state = state.copyWith(items: items, totalSize: _formatBytes(currentBytes));
  }

  void clearQueue() {
    if (state.progress.isDownloading) return;
    state = state.copyWith(
      items: [],
      progress: const DownloadProgress(),
      totalSize: '0 B',
    );
  }

  double _parseSizeToBytes(String sizeStr) {
    if (sizeStr.isEmpty || sizeStr == 'N/A') return 0;

    final parts = sizeStr.trim().split(' ');
    if (parts.length != 2) return 0; // Simple fallback

    final value = double.tryParse(parts[0]) ?? 0.0;
    final unit = parts[1].toUpperCase();

    switch (unit) {
      case 'B':
        return value;
      case 'KIB':
      case 'KB':
        return value * 1024;
      case 'MIB':
      case 'MB':
        return value * 1024 * 1024;
      case 'GIB':
      case 'GB':
        return value * 1024 * 1024 * 1024;
      default:
        return value;
    }
  }

  String _formatBytes(double bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KiB', 'MiB', 'GiB', 'TiB'];
    var i = 0;
    double tmp = bytes;
    while (tmp >= 1024 && i < suffixes.length - 1) {
      tmp /= 1024;
      i++;
    }
    return '${tmp.toStringAsFixed(1)} ${suffixes[i]}';
  }

  /// Get available disk space in bytes for the given path.
  /// Returns null if unable to determine.
  Future<double?> _getAvailableSpace(String path) async {
    try {
      if (Platform.isWindows) {
        // Use PowerShell to get free space on Windows
        final drive = path.substring(0, 3); // e.g. "C:\"
        final result = await Process.run('powershell', [
          '-Command',
          '(Get-PSDrive ${drive[0]}).Free',
        ]);
        if (result.exitCode == 0) {
          return double.tryParse(result.stdout.toString().trim());
        }
      } else {
        // Linux / macOS: use df
        final result = await Process.run('df', ['-B1', path]);
        if (result.exitCode == 0) {
          final lines = result.stdout.toString().trim().split('\n');
          if (lines.length >= 2) {
            final parts = lines[1].split(RegExp(r'\s+'));
            if (parts.length >= 4) {
              return double.tryParse(parts[3]);
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> startDownloads() async {
    if (state.isLoading || state.progress.isDownloading) return;

    state = state.copyWith(isLoading: true);

    // Enable background mode (prevent sleep/doze)
    await backgroundService.enableBackgroundExecution();
    _lastPercentage = -1;

    final itemsToDownload = List<DownloadItem>.from(state.items);
    final totalCount = itemsToDownload.length;
    final saveDir = await configService.getEffectiveDownloadLocation();
    if (saveDir == null) {
      state = state.copyWith(
        isLoading: false,
        items: [],
        progress: const DownloadProgress(
          status: 'Error: Download path not set',
          isDownloading: false,
        ),
      );
      return;
    }

    // Check available disk space (non-SAF paths only)
    if (!configService.isSafUri(saveDir)) {
      try {
        final stat = await FileStat.stat(saveDir);
        if (stat.type != FileSystemEntityType.notFound) {
          final totalQueueBytes = state.items.fold<double>(
            0,
            (sum, item) => sum + _parseSizeToBytes(item.size),
          );
          // Use df / wmic to check available space cross-platform
          final availableBytes = await _getAvailableSpace(saveDir);
          if (availableBytes != null && totalQueueBytes > availableBytes * 0.95) {
            state = state.copyWith(
              isLoading: false,
              progress: DownloadProgress(
                status:
                    'Error: Not enough disk space (${_formatBytes(availableBytes)} available, ${state.totalSize} needed)',
                isDownloading: false,
              ),
            );
            await backgroundService.disableBackgroundExecution();
            return;
          }
        }
      } catch (e) {
        // If we can't check space, continue anyway
        _log.warning('Could not check disk space: $e');
      }
    }

    int processedCount = 0;
    _cancelToken = DownloadCancellationToken();

    // Speed Calculation State
    DateTime? _lastSpeedUpdate;
    int _lastBytesReceived = 0;
    double _currentSpeed = 0;
    final List<double> _speedBuffer = [];
    const int _bufferSize = 25; // Store last 25 samples for smoothing

    try {
      for (var item in itemsToDownload) {
        if (_cancelToken?.isCancelled ?? false) break;

        processedCount++;
        _lastSpeedUpdate = null;
        _lastBytesReceived = 0;
        _currentSpeed = 0;
        _speedBuffer.clear();

        state = state.copyWith(
          progress: DownloadProgress(
            current: processedCount,
            total: totalCount,
            currentFile: item.filename,
            status: 'Downloading...',
            percentage: ((processedCount - 1) / totalCount) * 100,
            isDownloading: true,
          ),
        );

        try {
          final customPath = configService.getConsolePath(item.console);

          final stream = romService.downloadFile(
            item.category,
            item.console,
            item.filename,
            saveDir: saveDir,
            customPath: customPath,
            cancelToken: _cancelToken,
          );

          await for (final event in stream) {
            if (_cancelToken?.isCancelled ?? false) {
              throw Exception('Download cancelled');
            }

            final fileProgress = event.progress;

            // Speed & ETA Calculation (Throttle updates to ~1s)
            final now = DateTime.now();
            if (_lastSpeedUpdate == null ||
                now.difference(_lastSpeedUpdate).inMilliseconds > 1000) {
              if (_lastSpeedUpdate != null) {
                final duration =
                    now.difference(_lastSpeedUpdate).inMilliseconds / 1000.0;
                final bytesDiff = event.receivedBytes - _lastBytesReceived;
                if (duration > 0) {
                  final instantSpeed = bytesDiff / duration;
                  
                  // SMA Smoothing: Average of last N samples
                  _speedBuffer.add(instantSpeed);
                  if (_speedBuffer.length > _bufferSize) {
                    _speedBuffer.removeAt(0);
                  }
                  
                  if (_speedBuffer.isNotEmpty) {
                    _currentSpeed = _speedBuffer.reduce((a, b) => a + b) / 
                                   _speedBuffer.length;
                  }
                }
              }
              _lastSpeedUpdate = now;
              _lastBytesReceived = event.receivedBytes;
            }

            String speedStr = '';
            String etaStr = '';

            if (fileProgress < 1.0 && _currentSpeed > 0) {
              final remainingBytes = event.totalBytes - event.receivedBytes;
              final secondsLeft = remainingBytes / _currentSpeed;
              speedStr = '${_formatBytes(_currentSpeed)}/s';
              if (secondsLeft < 60) {
                etaStr = '${secondsLeft.toInt()}s';
              } else {
                final minutes = (secondsLeft / 60).toInt();
                final seconds = (secondsLeft % 60).toInt();
                etaStr = '${minutes}m ${seconds}s';
              }
            }

            double normalizedProgress;
            if (fileProgress <= 1.0) {
              normalizedProgress = fileProgress * 0.9;
            } else {
              // Extraction phase (progress > 1.0)
              normalizedProgress = 0.9 + ((fileProgress - 1.0) * 0.1);
              speedStr = 'Extracting...';
              etaStr = '';
            }

            final double itemContribution = 1.0 / totalCount;
            final double currentBase = (processedCount - 1) / totalCount;
            final double actual =
                (currentBase + (itemContribution * normalizedProgress)) * 100;

            // Update UI/Notification (Throttle to match speed calc)
            // Update if:
            // 1. Download complete (progress >= 1.0)
            // 2. Speed was just updated (within last 100ms) - this syncs UI with speed calc
            // 3. First update (_lastSpeedUpdate is null)
            if (fileProgress >= 1.0 ||
                now.difference(_lastSpeedUpdate).inMilliseconds < 100) {
              
              // Notification
              final int currentPercent = actual.toInt();
              if (currentPercent != _lastPercentage || now.second % 5 == 0) {
                 _lastPercentage = currentPercent;
                backgroundService.showProgress(
                  fileProgress > 1.0 ? 'Extracting...' : 'Down: ${item.filename}',
                  currentPercent,
                  100,
                  subtext: fileProgress > 1.0
                      ? null
                      : '$speedStr - $etaStr remaining',
                );
              }

              // State (UI)
              state = state.copyWith(
                progress: state.progress.copyWith(
                  current: processedCount,
                  total: totalCount,
                  currentFile: item.filename,
                  status: fileProgress > 1.0
                      ? 'Extracting ${((fileProgress - 1.0) * 100).toInt()}%'
                      : 'Downloading ${item.filename} ${(fileProgress * 100).toInt()}%',
                  percentage: actual,
                  isDownloading: true,
                  speed: speedStr,
                  eta: etaStr,
                ),
              );
            }
          }

          // SUCCESS: Remove item and update total size
          final updatedItems = List<DownloadItem>.from(state.items);
          final indexToRemove = updatedItems.indexWhere(
            (i) => i.filename == item.filename && i.console == item.console,
          );

          if (indexToRemove != -1) {
            final removed = updatedItems.removeAt(indexToRemove);
            double currentBytes = _parseSizeToBytes(state.totalSize);
            currentBytes -= _parseSizeToBytes(removed.size);
            if (currentBytes < 0) currentBytes = 0;

            state = state.copyWith(
              items: updatedItems,
              totalSize: _formatBytes(currentBytes),
            );
          }
        } on FileSystemException catch (e) {
          final errorCode = e.osError?.errorCode;
          // ENOSPC (Linux/Mac: 28), ERROR_DISK_FULL (Windows: 112), ERROR_HANDLE_DISK_FULL (Windows: 39)
          if (errorCode == 28 || errorCode == 112 || errorCode == 39) {
            _log.error('Disk full: ${item.filename}');
            state = state.copyWith(
              progress: state.progress.copyWith(
                status: 'Error: Not enough disk space to save ${item.filename}',
                isDownloading: true,
                speed: '',
                eta: '',
              ),
            );
            _cancelToken = null;
            break; // Stop all downloads — disk is full
          }
          _log.error('File system error: $e');
          state = state.copyWith(
            progress: state.progress.copyWith(
              status: 'Error: ${e.message}',
              isDownloading: true,
              speed: '',
              eta: '',
            ),
          );
          await Future.delayed(const Duration(milliseconds: 500));
        } catch (e) {
          if ((e.toString().contains('cancelled'))) {
            _log.info('Download Cancelled: ${item.filename}');
            _cancelToken = null;
            break;
          }

          _log.error('Download Error: $e');
          state = state.copyWith(
            progress: state.progress.copyWith(
              status: 'Error: $e',
              isDownloading: true,
              speed: '',
              eta: '',
            ),
          );
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }
    } finally {
      _cancelToken = null;

      // Disable background mode
      await backgroundService.disableBackgroundExecution();

      // Refesh ownership ALWAYS (even if cancelled)
      await romsNotifier.refreshOwnership();

      state = state.copyWith(
        isLoading: false,
        // items: state.items, // Preserved
        progress: state.progress.copyWith(
          isDownloading: false,
          status: state.items.isEmpty ? 'All Done!' : 'Stopped',
          speed: '',
          eta: '',
        ),
      );
    }
  }
}

final downloadQueueProvider =
    StateNotifierProvider<DownloadQueueNotifier, DownloadQueueState>((ref) {
      return DownloadQueueNotifier(
        ref.watch(romServiceProvider),
        ref.watch(configServiceProvider),
        ref.read(romsProvider.notifier),
        ref.watch(backgroundServiceProvider),
      );
    });
