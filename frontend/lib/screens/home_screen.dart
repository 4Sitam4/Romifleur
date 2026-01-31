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
      // ref.read(downloadQueueProvider.notifier).loadQueue();
      // Queue is local now, minimal init needed
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
          Expanded(child: _buildBodyContent(showSettings: false)),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildMobileHeader(),
            Expanded(child: _buildBodyContent(showSidebarHeader: false)),
          ],
        ),
      ),
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

  Widget _buildMobileHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.sidebarColor,
        border: Border(bottom: BorderSide(color: Colors.grey.shade800)),
      ),
      child: Row(
        children: [
          Image.asset(
            'assets/logo-romifleur.png',
            height: 40,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return const Row(
                children: [
                  Icon(Icons.gamepad, color: AppTheme.textPrimary),
                  SizedBox(width: 8),
                  Text(
                    'Romifleur',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              );
            },
          ),
          const Spacer(),
          IconButton(
            onPressed: _openSettings,
            icon: const Icon(Icons.settings, color: AppTheme.textMuted),
            splashRadius: 24,
            constraints: const BoxConstraints(),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _buildBodyContent({
    bool showSidebarHeader = true,
    bool showSettings = true,
  }) {
    switch (_selectedIndex) {
      case 0:
        return ConsoleSidebar(
          onConsoleSelected: _onConsoleSelected,
          showHeader: showSidebarHeader,
          showSettings: showSettings,
        );
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
