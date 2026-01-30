import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/theme.dart';
import '../providers/providers.dart';
import '../models/console.dart';

class ConsoleSidebar extends ConsumerWidget {
  const ConsoleSidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final consolesAsync = ref.watch(consolesProvider);
    final selected = ref.watch(selectedConsoleProvider);

    return Container(
      width: 250,
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

class _CategorySection extends ConsumerWidget {
  final CategoryModel category;
  final String? selectedConsoleKey;

  const _CategorySection({required this.category, this.selectedConsoleKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            category.category.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.textMuted,
              letterSpacing: 1.2,
            ),
          ),
        ),
        ...category.consoles.map(
          (console) => _ConsoleItem(
            category: category.category,
            console: console,
            isSelected: console.key == selectedConsoleKey,
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

  const _ConsoleItem({
    required this.category,
    required this.console,
    required this.isSelected,
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
