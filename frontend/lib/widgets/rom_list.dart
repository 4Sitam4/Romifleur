import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/theme.dart';
import '../providers/providers.dart';
import '../models/rom.dart';
import '../models/download.dart';

class RomListPanel extends ConsumerStatefulWidget {
  const RomListPanel({super.key});

  @override
  ConsumerState<RomListPanel> createState() => _RomListPanelState();
}

class _RomListPanelState extends ConsumerState<RomListPanel> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    final selectedConsole = ref.watch(selectedConsoleProvider);
    final romsState = ref.watch(romsProvider);

    if (selectedConsole.console == null) {
      return _buildEmptyState();
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        border: Border(right: BorderSide(color: Colors.grey.shade800)),
      ),
      child: Column(
        children: [
          // Header with console name and controls
          _buildHeader(selectedConsole.console!.name, romsState),

          // Search and filters
          _buildSearchBar(romsState),

          // ROM List
          Expanded(
            child: romsState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : romsState.error != null
                ? _buildError(romsState.error!)
                : romsState.roms.isEmpty
                ? _buildNoResults()
                : _buildRomList(romsState.roms),
          ),

          // Bottom action bar
          if (selectedConsole.console != null)
            _buildBottomBar(
              romsState,
              selectedConsole.category!,
              selectedConsole.console!.key,
            ),
        ],
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
      child: Row(
        children: [
          Text(
            consoleName,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
          const Spacer(),
          if (state.selectedCount > 0) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchBar(RomsState state) {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Column(
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

          // Region filters
          Row(
            children: [
              const Text(
                'Regions:',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(width: 12),
              _buildRegionChip('Europe', '🇪🇺', state),
              const SizedBox(width: 6),
              _buildRegionChip('USA', '🇺🇸', state),
              const SizedBox(width: 6),
              _buildRegionChip('Japan', '🇯🇵', state),
              const Spacer(),
              // Select All / Deselect All
              TextButton.icon(
                onPressed: () => ref.read(romsProvider.notifier).selectAll(),
                icon: const Icon(Icons.select_all, size: 16),
                label: const Text('All'),
              ),
              TextButton.icon(
                onPressed: () => ref.read(romsProvider.notifier).deselectAll(),
                icon: const Icon(Icons.deselect, size: 16),
                label: const Text('None'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRegionChip(String region, String flag, RomsState state) {
    final isSelected = state.selectedRegions.contains(region);
    return FilterChip(
      label: Text('$flag $region', style: const TextStyle(fontSize: 12)),
      selected: isSelected,
      onSelected: (_) => ref.read(romsProvider.notifier).toggleRegion(region),
      selectedColor: AppTheme.primaryColor.withOpacity(0.3),
      checkmarkColor: AppTheme.primaryColor,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildRomList(List<RomModel> roms) {
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

  Widget _buildBottomBar(RomsState state, String category, String consoleKey) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        border: Border(top: BorderSide(color: Colors.grey.shade800)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          ElevatedButton.icon(
            onPressed: state.selectedCount > 0
                ? () async {
                    final selectedRoms = ref
                        .read(romsProvider.notifier)
                        .getSelectedRoms();
                    await ref
                        .read(downloadQueueProvider.notifier)
                        .addToQueue(category, consoleKey, selectedRoms);
                    ref.read(romsProvider.notifier).deselectAll();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Added ${selectedRoms.length} games to queue',
                        ),
                        backgroundColor: AppTheme.accentColor,
                      ),
                    );
                  }
                : null,
            icon: const Icon(Icons.add_shopping_cart),
            label: Text('Add to Queue (${state.selectedCount})'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

class _RomListItem extends StatelessWidget {
  final RomModel rom;
  final VoidCallback onToggle;

  const _RomListItem({required this.rom, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: onToggle,
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
                      SizedBox(width: 4),
                      Text('🏆', style: TextStyle(fontSize: 12)),
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
