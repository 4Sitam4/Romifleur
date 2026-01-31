import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:romifleur/services/config_service.dart';
import 'package:romifleur/services/rom_service.dart';
import 'package:romifleur/services/metadata_service.dart';
import 'package:romifleur/services/ra_service.dart';
import '../models/console.dart';
import '../models/rom.dart';
import '../models/download.dart';

// ===== SERVICE PROVIDERS =====
final configServiceProvider = Provider<ConfigService>((ref) => ConfigService());
final romServiceProvider = Provider<RomService>((ref) => RomService());
final metadataServiceProvider = Provider<MetadataService>(
  (ref) => MetadataService(),
);
final raServiceProvider = Provider<RaService>((ref) => RaService());

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
  final bool hideDemos;
  final bool hideBetas;
  final bool onlyRa;

  const RomsState({
    this.roms = const [],
    this.isLoading = false,
    this.error,
    this.searchQuery = '',
    this.selectedRegions = const {'Europe', 'USA', 'Japan'},
    this.hideDemos = true,
    this.hideBetas = true,
    this.onlyRa = false,
  });

  RomsState copyWith({
    List<RomModel>? roms,
    bool? isLoading,
    String? error,
    String? searchQuery,
    Set<String>? selectedRegions,
    bool? hideDemos,
    bool? hideBetas,
    bool? onlyRa,
  }) {
    return RomsState(
      roms: roms ?? this.roms,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedRegions: selectedRegions ?? this.selectedRegions,
      hideDemos: hideDemos ?? this.hideDemos,
      hideBetas: hideBetas ?? this.hideBetas,
      onlyRa: onlyRa ?? this.onlyRa,
    );
  }

  int get selectedCount => roms.where((r) => r.isSelected).length;
}

class RomsNotifier extends StateNotifier<RomsState> {
  final RomService romService;
  final RaService raService;
  String? _currentCategory;
  String? _currentConsoleKey;

  RomsNotifier(this.romService, this.raService) : super(const RomsState());

  Future<void> loadRoms(String category, String consoleKey) async {
    _currentCategory = category;
    _currentConsoleKey = consoleKey;
    _refresh();
  }

  Future<void> _refresh() async {
    if (_currentCategory == null || _currentConsoleKey == null) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      // 1. Fetch filtered list
      var roms = await romService.search(
        _currentCategory!,
        _currentConsoleKey!,
        state.searchQuery,
        regions: state.selectedRegions.toList(),
        hideDemos: state.hideDemos,
        hideBetas: state.hideBetas,
        deduplicate: true, // Always deduplicate for now
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

      state = state.copyWith(roms: roms, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void setSearch(String query) {
    state = state.copyWith(searchQuery: query);
    _refresh();
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
}

final romsProvider = StateNotifierProvider<RomsNotifier, RomsState>((ref) {
  return RomsNotifier(
    ref.watch(romServiceProvider),
    ref.watch(raServiceProvider),
  );
});

// ===== DOWNLOAD QUEUE PROVIDER =====
class DownloadQueueState {
  final List<DownloadItem> items;
  final DownloadProgress progress;
  final bool isLoading;

  const DownloadQueueState({
    this.items = const [],
    this.progress = const DownloadProgress(),
    this.isLoading = false,
  });

  DownloadQueueState copyWith({
    List<DownloadItem>? items,
    DownloadProgress? progress,
    bool? isLoading,
  }) {
    return DownloadQueueState(
      items: items ?? this.items,
      progress: progress ?? this.progress,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class DownloadQueueNotifier extends StateNotifier<DownloadQueueState> {
  final RomService romService;
  final ConfigService configService;

  DownloadQueueNotifier(this.romService, this.configService)
    : super(const DownloadQueueState());

  void addToQueue(String category, String console, List<RomModel> roms) {
    if (roms.isEmpty) return;

    final currentItems = List<DownloadItem>.from(state.items);

    for (var rom in roms) {
      // Prevent duplicates in queue
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
      }
    }

    // Reset progress if we added items and weren't active
    var p = state.progress;
    if (state.items.isEmpty && currentItems.isNotEmpty) {
      p = DownloadProgress(
        total: currentItems.length,
        current: 0,
        status: 'Ready',
      );
    } else {
      // Update total
      p = DownloadProgress(
        total: currentItems.length,
        current: state.progress.current,
        status: state.progress.status,
        isDownloading: state.progress.isDownloading,
      );
    }

    state = state.copyWith(items: currentItems, progress: p);
  }

  void removeFromQueue(int index) {
    if (index < 0 || index >= state.items.length) return;
    final items = List<DownloadItem>.from(state.items);
    items.removeAt(index);
    state = state.copyWith(items: items);
  }

  void clearQueue() {
    if (state.progress.isDownloading)
      return; // Prevent clearing while downloading
    state = state.copyWith(items: [], progress: const DownloadProgress());
  }

  Future<void> startDownloads() async {
    if (state.isLoading || state.progress.isDownloading) return;

    state = state.copyWith(isLoading: true);
    final itemsToDownload = List<DownloadItem>.from(state.items);
    final totalCount = itemsToDownload.length;
    final saveDir = await configService.getDownloadPath();

    int processedCount = 0;

    for (var item in itemsToDownload) {
      processedCount++;

      // Update Status
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
        final stream = romService.downloadFile(
          item.category,
          item.console,
          item.filename,
          saveDir: saveDir,
        );

        await for (final fileProgress in stream) {
          // Calculate smooth percentage
          // Weight: Download = 90%, Extraction = 10%
          double normalizedProgress;
          if (fileProgress <= 1.0) {
            normalizedProgress = fileProgress * 0.9;
          } else {
            normalizedProgress = 0.9 + ((fileProgress - 1.0) * 0.1);
          }

          final double itemContribution = 1.0 / totalCount;
          final double currentBase = (processedCount - 1) / totalCount;
          final double actual =
              (currentBase + (itemContribution * normalizedProgress)) * 100;

          state = state.copyWith(
            progress: DownloadProgress(
              current: processedCount,
              total: totalCount,
              currentFile: item.filename,
              status: fileProgress > 1.0
                  // Show Extracting % based on the 1.0-2.0 range
                  ? 'Extracting ${((fileProgress - 1.0) * 100).toInt()}%'
                  : 'Downloading ${item.filename} ${(fileProgress * 100).toInt()}%',
              percentage: actual,
              isDownloading: true,
            ),
          );
        }
      } catch (e) {
        print('Download Error: $e');
        state = state.copyWith(
          progress: DownloadProgress(
            current: processedCount,
            total: totalCount,
            currentFile: item.filename,
            status: 'Error: $e',
            isDownloading: true,
          ),
        );
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // Remove from queue as done (optional, but requested by user flow usually)
      // Actually, typical download managers keep list until cleared.
      // But for "Queue" typically it consumes items.
      // Let's remove this item from the list to show it's done?
      // Or keep it. Python backend kept it.
      // The UI usually shows the list. If we remove it, it disappears.
      // Let's keep it in list, but user can clear completed.
    }

    state = state.copyWith(
      isLoading: false,
      items: [], // Clear queue on completion
      progress: DownloadProgress(
        current: totalCount,
        total: totalCount,
        percentage: 100,
        status: 'All Done!',
        isDownloading: false,
      ),
    );
  }
}

final downloadQueueProvider =
    StateNotifierProvider<DownloadQueueNotifier, DownloadQueueState>((ref) {
      return DownloadQueueNotifier(
        ref.watch(romServiceProvider),
        ref.watch(configServiceProvider),
      );
    });
