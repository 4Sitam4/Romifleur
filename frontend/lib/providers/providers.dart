import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../models/console.dart';
import '../models/rom.dart';
import '../models/download.dart';

// ===== API SERVICE PROVIDER =====
final apiServiceProvider = Provider<ApiService>((ref) => ApiService());

// ===== CONSOLES PROVIDER =====
final consolesProvider = FutureProvider<List<CategoryModel>>((ref) async {
  final api = ref.read(apiServiceProvider);
  return api.getConsoles();
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
  final ApiService api;
  String? _currentCategory;
  String? _currentConsoleKey;

  RomsNotifier(this.api) : super(const RomsState());

  Future<void> loadRoms(String category, String consoleKey) async {
    _currentCategory = category;
    _currentConsoleKey = consoleKey;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final roms = await api.getRoms(
        category: category,
        consoleKey: consoleKey,
        query: state.searchQuery,
        regions: state.selectedRegions.toList(),
        hideDemos: state.hideDemos,
        hideBetas: state.hideBetas,
        onlyRa: state.onlyRa,
      );
      state = state.copyWith(roms: roms, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void setSearch(String query) {
    state = state.copyWith(searchQuery: query);
    _reload();
  }

  void toggleRegion(String region) {
    final regions = Set<String>.from(state.selectedRegions);
    if (regions.contains(region)) {
      regions.remove(region);
    } else {
      regions.add(region);
    }
    state = state.copyWith(selectedRegions: regions);
    _reload();
  }

  void toggleOnlyRa() {
    state = state.copyWith(onlyRa: !state.onlyRa);
    _reload();
  }

  void toggleHideDemos() {
    state = state.copyWith(hideDemos: !state.hideDemos);
    _reload();
  }

  void toggleHideBetas() {
    state = state.copyWith(hideBetas: !state.hideBetas);
    _reload();
  }

  void _reload() {
    if (_currentCategory != null && _currentConsoleKey != null) {
      loadRoms(_currentCategory!, _currentConsoleKey!);
    }
  }

  void toggleRomSelection(int index) {
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
  return RomsNotifier(ref.read(apiServiceProvider));
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
  final ApiService api;

  DownloadQueueNotifier(this.api) : super(const DownloadQueueState());

  Future<void> loadQueue() async {
    try {
      final items = await api.getQueue();
      final progress = await api.getProgress();
      state = state.copyWith(items: items, progress: progress);
    } catch (e) {
      // Ignore errors silently
    }
  }

  Future<void> addToQueue(
    String category,
    String console,
    List<RomModel> roms,
  ) async {
    final items = roms
        .map(
          (r) => DownloadItem(
            category: category,
            console: console,
            filename: r.filename,
            size: r.size,
          ),
        )
        .toList();

    await api.addBatchToQueue(items);
    await loadQueue();
  }

  Future<void> removeFromQueue(int index) async {
    await api.removeFromQueue(index);
    await loadQueue();
  }

  Future<void> clearQueue() async {
    await api.clearQueue();
    await loadQueue();
  }

  Future<void> startDownloads() async {
    state = state.copyWith(isLoading: true);
    await api.startDownloads();

    // Poll for progress
    while (true) {
      await Future.delayed(const Duration(seconds: 1));
      final progress = await api.getProgress();
      state = state.copyWith(progress: progress);

      if (!progress.isDownloading &&
          progress.current == progress.total &&
          progress.total > 0) {
        break;
      }
      if (!progress.isDownloading && progress.total == 0) {
        break;
      }
    }

    await loadQueue();
    state = state.copyWith(isLoading: false);
  }

  Future<void> refreshProgress() async {
    final progress = await api.getProgress();
    state = state.copyWith(progress: progress);
  }
}

final downloadQueueProvider =
    StateNotifierProvider<DownloadQueueNotifier, DownloadQueueState>((ref) {
      return DownloadQueueNotifier(ref.read(apiServiceProvider));
    });
