import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/theme.dart';
import '../providers/providers.dart';
import '../models/console.dart';

class ConsoleSidebar extends ConsumerWidget {
  final VoidCallback? onConsoleSelected;

  const ConsoleSidebar({super.key, this.onConsoleSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final consolesAsync = ref.watch(consolesProvider);
    final selected = ref.watch(selectedConsoleProvider);

    return Container(
      // Remove fixed width here, let parent decide
      decoration: BoxDecoration(
        color: AppTheme.sidebarColor,
        border: Border(right: BorderSide(color: Colors.grey.shade800)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.primaryColor, AppTheme.accentColor],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.gamepad,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Romifleur',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Console List
          Expanded(
            child: consolesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: AppTheme.errorColor,
                      size: 48,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Failed to load consoles',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => ref.refresh(consolesProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (categories) => ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final category = categories[index];
                  return _CategorySection(
                    category: category,
                    selectedConsoleKey: selected.console?.key,
                    onConsoleSelected: onConsoleSelected,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategorySection extends ConsumerStatefulWidget {
  final CategoryModel category;
  final String? selectedConsoleKey;
  final VoidCallback? onConsoleSelected;

  const _CategorySection({
    required this.category,
    this.selectedConsoleKey,
    this.onConsoleSelected,
  });

  @override
  ConsumerState<_CategorySection> createState() => _CategorySectionState();
}

class _CategorySectionState extends ConsumerState<_CategorySection> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.category.consoles.any(
      (c) => c.key == widget.selectedConsoleKey,
    );
  }

  @override
  void didUpdateWidget(_CategorySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedConsoleKey != oldWidget.selectedConsoleKey) {
      if (widget.category.consoles.any(
        (c) => c.key == widget.selectedConsoleKey,
      )) {
        _isExpanded = true;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            setState(() {
              _isExpanded = !_isExpanded;
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.category.category.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textMuted,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                Icon(
                  _isExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 16,
                  color: AppTheme.textMuted,
                ),
              ],
            ),
          ),
        ),

        if (_isExpanded)
          ...widget.category.consoles.map(
            (console) => _ConsoleItem(
              category: widget.category.category,
              console: console,
              isSelected: console.key == widget.selectedConsoleKey,
              onTap: widget.onConsoleSelected,
            ),
          ),
      ],
    );
  }
}

class _ConsoleItem extends ConsumerWidget {
  final String category;
  final ConsoleModel console;
  final bool isSelected;
  final VoidCallback? onTap;

  const _ConsoleItem({
    required this.category,
    required this.console,
    required this.isSelected,
    this.onTap,
  });

  IconData _getConsoleIcon() {
    final key = console.key.toLowerCase();
    if (key.contains('ps') || key.contains('playstation'))
      return Icons.sports_esports;
    if (key.contains('nintendo') || key.contains('nes') || key.contains('snes'))
      return Icons.videogame_asset;
    if (key.contains('gb') ||
        key.contains('gba') ||
        key.contains('nds') ||
        key.contains('3ds'))
      return Icons.phone_android;
    if (key.contains('sega') ||
        key.contains('dreamcast') ||
        key.contains('saturn'))
      return Icons.games;
    if (key.contains('atari')) return Icons.sports_esports_outlined;
    return Icons.gamepad;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          ref.read(selectedConsoleProvider.notifier).state =
              SelectedConsoleState(category: category, console: console);
          ref.read(romsProvider.notifier).loadRoms(category, console.key);
          onTap?.call();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryColor.withOpacity(0.15) : null,
            border: Border(
              left: BorderSide(
                color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                _getConsoleIcon(),
                size: 18,
                color: isSelected
                    ? AppTheme.primaryColor
                    : AppTheme.textSecondary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  console.name,
                  style: TextStyle(
                    fontSize: 14,
                    color: isSelected
                        ? AppTheme.textPrimary
                        : AppTheme.textSecondary,
                    fontWeight: isSelected
                        ? FontWeight.w500
                        : FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
