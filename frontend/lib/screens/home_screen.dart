import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/theme.dart';
import '../providers/providers.dart';
import '../widgets/console_sidebar.dart';
import '../widgets/rom_list.dart';
import '../widgets/download_panel.dart';
import 'settings_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0; // 0: Consoles, 1: Games, 2: Downloads

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(downloadQueueProvider.notifier).loadQueue();
    });
  }

  void _onConsoleSelected() {
    // Switch to Games tab automatically on mobile/tablet
    setState(() {
      _selectedIndex = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 1100) {
          return _buildDesktopLayout();
        } else if (constraints.maxWidth > 600) {
          return _buildTabletLayout();
        } else {
          return _buildMobileLayout();
        }
      },
    );
  }

  Widget _buildDesktopLayout() {
    return Scaffold(
      body: Row(
        children: [
          SizedBox(
            width: 280,
            child: ConsoleSidebar(
              onConsoleSelected: null,
            ), // No auto-switch on desktop
          ),
          const Expanded(child: RomListPanel()),
          const SizedBox(width: 350, child: DownloadPanel()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openSettings(),
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.settings),
      ),
    );
  }

  Widget _buildTabletLayout() {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              setState(() => _selectedIndex = index);
            },
            labelType: NavigationRailLabelType.all,
            backgroundColor: AppTheme.sidebarColor,
            selectedIconTheme: const IconThemeData(
              color: AppTheme.primaryColor,
            ),
            unselectedIconTheme: const IconThemeData(color: AppTheme.textMuted),
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: IconButton(
                icon: const Icon(Icons.settings),
                onPressed: _openSettings,
              ),
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.gamepad),
                label: Text('Consoles'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.sports_esports),
                label: Text('Games'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.download),
                label: Text('Downloads'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: _buildBodyContent()),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Romifleur'),
        actions: [
          IconButton(
            onPressed: _openSettings,
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: _buildBodyContent(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        backgroundColor: AppTheme.sidebarColor,
        selectedItemColor: AppTheme.primaryColor,
        unselectedItemColor: AppTheme.textMuted,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.gamepad), label: 'Consoles'),
          BottomNavigationBarItem(
            icon: Icon(Icons.sports_esports),
            label: 'Games',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.download),
            label: 'Downloads',
          ),
        ],
      ),
    );
  }

  Widget _buildBodyContent() {
    switch (_selectedIndex) {
      case 0:
        return ConsoleSidebar(onConsoleSelected: _onConsoleSelected);
      case 1:
        return const RomListPanel();
      case 2:
        return const DownloadPanel();
      default:
        return const SizedBox.shrink();
    }
  }

  void _openSettings() {
    showDialog(context: context, builder: (context) => const SettingsDialog());
  }
}
