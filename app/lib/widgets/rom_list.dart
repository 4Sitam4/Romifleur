import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';

import '../config/theme.dart';
import '../providers/providers.dart';
import '../models/rom.dart';

class RomListPanel extends ConsumerStatefulWidget {
  const RomListPanel({super.key});

  @override
  ConsumerState<RomListPanel> createState() => _RomListPanelState();
}

class _RomListPanelState extends ConsumerState<RomListPanel> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  String? _addToQueueMessage;
  Timer? _queueTimer;

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _queueTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedConsole = ref.watch(selectedConsoleProvider);
    final romsState = ref.watch(romsProvider);
    final isCompact =
        MediaQuery.of(context).size.width < 600 ||
        MediaQuery.of(context).size.height < 500 ||
        MediaQuery.of(context).orientation == Orientation.landscape;

    if (selectedConsole.console == null) {
      return _buildEmptyState();
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        border: Border(right: BorderSide(color: Colors.grey.shade800)),
      ),
      child: Stack(
        children: [
          Column(
            children: [
              // Adaptive Header & Search
              if (isCompact)
                _buildCompactHeader(selectedConsole.console!.name, romsState)
              else ...[
                _buildHeader(selectedConsole.console!.name, romsState),
                _buildSearchBar(romsState),
              ],

              // ROM List
              Expanded(
                child: romsState.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : romsState.error != null
                    ? _buildError(romsState.error!)
                    : romsState.roms.isEmpty
                    ? _buildNoResults()
                    : _buildRomList(
                        romsState.roms,
                        selectedConsole.console!.key,
                      ),
              ),
            ],
          ),

          // Floating Action Button for Add to Queue
          if (romsState.selectedCount > 0)
            Positioned(
              right: 16 + MediaQuery.of(context).padding.right,
              bottom: 16 + MediaQuery.of(context).padding.bottom,
              child: FloatingActionButton.extended(
                onPressed: () async {
                  final selectedRoms = ref
                      .read(romsProvider.notifier)
                      .getSelectedRoms();
                  ref
                      .read(downloadQueueProvider.notifier)
                      .addToQueue(
                        selectedConsole.category!,
                        selectedConsole.console!.key,
                        selectedRoms,
                      );
                  ref.read(romsProvider.notifier).deselectAll();

                  setState(() {
                    _addToQueueMessage = 'Added ${selectedRoms.length} games!';
                  });

                  _queueTimer?.cancel();
                  _queueTimer = Timer(const Duration(seconds: 2), () {
                    if (mounted) {
                      setState(() {
                        _addToQueueMessage = null;
                      });
                    }
                  });
                },
                backgroundColor: _addToQueueMessage != null
                    ? AppTheme.accentColor
                    : AppTheme.primaryColor,
                icon: Icon(
                  _addToQueueMessage != null
                      ? Icons.check
                      : Icons.add_shopping_cart,
                ),
                label: Text(
                  _addToQueueMessage ??
                      'Add to Queue (${romsState.selectedCount})',
                ),
              ),
            ),
        ],
      ),
    );
  }

  // COMPACT MODE: Header + Search + Filter Button in one row
  Widget _buildCompactHeader(String consoleName, RomsState state) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 4,
      ), // Reduced padding
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        border: Border(bottom: BorderSide(color: Colors.grey.shade800)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search $consoleName...',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () {
                            _searchController.clear();
                            ref.read(romsProvider.notifier).setSearch('');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.black12,
                ),
                onChanged: (value) =>
                    ref.read(romsProvider.notifier).setSearch(value),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Badge(
                label: Text(
                  '${(state.onlyRa ? 1 : 0) + (state.hideDemos ? 1 : 0) + (state.hideBetas ? 1 : 0)}',
                ),
                isLabelVisible:
                    (state.onlyRa || state.hideDemos || state.hideBetas),
                child: const Icon(Icons.tune),
              ),
              tooltip: 'Filters',
              onPressed: () => _showFilterSheet(state),
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterSheet(RomsState state) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allow full height
      backgroundColor: AppTheme.cardColor,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final currentState = ref.watch(romsProvider);
          return SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                // Combine viewInsets (keyboard) + padding (safe area) + spacing
                bottom:
                    MediaQuery.of(context).viewInsets.bottom +
                    MediaQuery.of(context).padding.bottom +
                    16,
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade700,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const Text(
                      "Filters",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // ... Filters wrap ...
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilterChip(
                          label: const Text('🏆 RA Only'),
                          selected: currentState.onlyRa,
                          onSelected: (_) =>
                              ref.read(romsProvider.notifier).toggleOnlyRa(),
                          selectedColor: AppTheme.achievementGold.withValues(
                            alpha: 0.3,
                          ),
                        ),
                        FilterChip(
                          label: const Text('Hide Demo'),
                          selected: currentState.hideDemos,
                          onSelected: (_) =>
                              ref.read(romsProvider.notifier).toggleHideDemos(),
                        ),
                        FilterChip(
                          label: const Text('Hide Beta'),
                          selected: currentState.hideBetas,
                          onSelected: (_) =>
                              ref.read(romsProvider.notifier).toggleHideBetas(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Regions",
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildRegionChip('Europe', '🇪🇺', currentState, ref),
                        _buildRegionChip('USA', '🇺🇸', currentState, ref),
                        _buildRegionChip('Japan', '🇯🇵', currentState, ref),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.games,
            size: 80,
            color: AppTheme.textMuted.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Select a console to browse ROMs',
            style: TextStyle(fontSize: 18, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String consoleName, RomsState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        border: Border(bottom: BorderSide(color: Colors.grey.shade800)),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [
          Text(
            consoleName,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          Wrap(
            spacing: 8,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${state.roms.length} games',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
              if (state.selectedCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.accentColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${state.selectedCount} selected',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.accentColor,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(RomsState state) {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search field
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search games...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        ref.read(romsProvider.notifier).setSearch('');
                      },
                    )
                  : null,
            ),
            onChanged: (value) {
              ref.read(romsProvider.notifier).setSearch(value);
            },
          ),
          const SizedBox(height: 12),

          // Search Filters (Wrap)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                label: const Text('🏆 RA Only'),
                selected: state.onlyRa,
                onSelected: (_) =>
                    ref.read(romsProvider.notifier).toggleOnlyRa(),
                selectedColor: AppTheme.achievementGold.withValues(alpha: 0.3),
                side: BorderSide(
                  color: state.onlyRa
                      ? AppTheme.achievementGold
                      : Colors.grey.shade700,
                ),
              ),
              FilterChip(
                label: const Text('Hide Demo'),
                selected: state.hideDemos,
                onSelected: (_) =>
                    ref.read(romsProvider.notifier).toggleHideDemos(),
              ),
              FilterChip(
                label: const Text('Hide Beta'),
                selected: state.hideBetas,
                onSelected: (_) =>
                    ref.read(romsProvider.notifier).toggleHideBetas(),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Region filters (Wrap)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'Regions:',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              _buildRegionChip('Europe', '🇪🇺', state, ref),
              _buildRegionChip('USA', '🇺🇸', state, ref),
              _buildRegionChip('Japan', '🇯🇵', state, ref),
              // Select/Deselect All buttons
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: () =>
                        ref.read(romsProvider.notifier).selectAll(),
                    child: const Text('All', style: TextStyle(fontSize: 12)),
                  ),
                  TextButton(
                    onPressed: () =>
                        ref.read(romsProvider.notifier).deselectAll(),
                    child: const Text('None', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRegionChip(
    String region,
    String flag,
    RomsState state,
    WidgetRef ref,
  ) {
    final isSelected = state.selectedRegions.contains(region);
    return FilterChip(
      label: Text('$flag $region', style: const TextStyle(fontSize: 12)),
      selected: isSelected,
      onSelected: (_) => ref.read(romsProvider.notifier).toggleRegion(region),
      selectedColor: AppTheme.primaryColor.withValues(alpha: 0.3),
      checkmarkColor: AppTheme.primaryColor,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildRomList(List<RomModel> roms, String consoleKey) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: roms.length,
      itemBuilder: (context, index) {
        final rom = roms[index];
        return _RomListItem(
          rom: rom,
          onToggle: () =>
              ref.read(romsProvider.notifier).toggleRomSelection(index),
          onTap: () => _showDetails(rom, consoleKey),
        );
      },
    );
  }

  Widget _buildError(String error) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppTheme.errorColor),
          const SizedBox(height: 8),
          Text(
            'Error loading ROMs',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            error,
            style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off, size: 48, color: AppTheme.textMuted),
          const SizedBox(height: 8),
          Text(
            'No games found',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Future<void> _showDetails(RomModel rom, String consoleKey) async {
    showDialog(
      context: context,
      builder: (context) =>
          _GameDetailsDialog(rom: rom, consoleKey: consoleKey),
    );
  }
}

class _GameDetailsDialog extends ConsumerStatefulWidget {
  final RomModel rom;
  final String consoleKey;

  const _GameDetailsDialog({required this.rom, required this.consoleKey});

  @override
  ConsumerState<_GameDetailsDialog> createState() => _GameDetailsDialogState();
}

class _GameDetailsDialogState extends ConsumerState<_GameDetailsDialog> {
  Map<String, dynamic>? _metadata;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMetadata();
  }

  Future<void> _loadMetadata() async {
    try {
      final metadata = ref.read(metadataServiceProvider);
      final data = await metadata.getMetadata(
        widget.consoleKey,
        widget.rom.filename,
      );
      if (mounted) {
        setState(() {
          _metadata = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // If we have an image URL, use it
    String? imageUrl = _metadata?['image_url'];
    // Use fallback placeholder if no image

    final isMobile = MediaQuery.of(context).size.width < 800;

    return Dialog(
      backgroundColor: AppTheme.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 700,
        height: isMobile ? MediaQuery.of(context).size.height * 0.9 : 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Header
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    widget.rom.title,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: isMobile ? 20 : 24,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _metadata == null || _metadata!.isEmpty
                  ? const Center(child: Text("No metadata found"))
                  : isMobile
                  ? _buildMobileContent(imageUrl)
                  : _buildDesktopContent(imageUrl),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopContent(String? imageUrl) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cover Image (Left)
        SizedBox(width: 250, child: _buildCoverImage(imageUrl)),
        const SizedBox(width: 24),

        // Details (Right)
        Expanded(child: SingleChildScrollView(child: _buildDetailsColumn())),
      ],
    );
  }

  Widget _buildMobileContent(String? imageUrl) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Center image on mobile
          SizedBox(height: 200, child: _buildCoverImage(imageUrl)),
          const SizedBox(height: 24),
          _buildDetailsColumn(),
        ],
      ),
    );
  }

  Widget _buildCoverImage(String? imageUrl) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade800),
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl != null && imageUrl.isNotEmpty
          ? Image.network(
              imageUrl,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) =>
                  const Center(child: Icon(Icons.broken_image, size: 64)),
            )
          : const Center(
              child: Icon(
                Icons.image_not_supported,
                size: 64,
                color: AppTheme.textMuted,
              ),
            ),
    );
  }

  Widget _buildDetailsColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_metadata!['description'] != null) ...[
          const Text(
            "SYNOPSIS",
            style: TextStyle(
              color: AppTheme.accentColor,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _metadata!['description'],
            style: const TextStyle(height: 1.5, fontSize: 14),
          ),
          const SizedBox(height: 24),
        ],

        _buildInfoRow("Developer", _metadata!['developer']),
        _buildInfoRow("Publisher", _metadata!['publisher']),
        _buildInfoRow("Genre", _metadata!['genre']),
        _buildInfoRow("Release Date", _metadata!['release_date']),
        _buildInfoRow("Rating", _metadata!['rating']),

        const SizedBox(height: 24),
        if (widget.rom.hasAchievements)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.achievementGold.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppTheme.achievementGold.withOpacity(0.3),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.emoji_events, color: AppTheme.achievementGold),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Compatible with RetroAchievements",
                    style: TextStyle(
                      color: AppTheme.achievementGold,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildInfoRow(String label, dynamic value) {
    if (value == null || value.toString().isEmpty)
      return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value.toString(),
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RomListItem extends StatelessWidget {
  final RomModel rom;
  final VoidCallback onToggle;
  final VoidCallback onTap;

  const _RomListItem({
    required this.rom,
    required this.onToggle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // Checkbox
              Checkbox(value: rom.isSelected, onChanged: (_) => onToggle()),
              const SizedBox(width: 8),

              // Title and info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rom.title,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (rom.region != null) ...[
                          Text(
                            rom.region!,
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          rom.size,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Achievement badge
              if (rom.hasAchievements)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.achievementGold.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.emoji_events,
                        size: 14,
                        color: AppTheme.achievementGold,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
