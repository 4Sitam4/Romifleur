import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
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
      _checkConfiguration();
    });
  }

  Future<void> _checkConfiguration() async {
    // Web uses server-managed path, no setup needed here
    if (kIsWeb) return;

    final config = ref.read(configServiceProvider);
    await config.init(); // Ensure config is ready
    final path = await config.getDownloadPath();

    if (path == null) {
      if (mounted) {
        await _showSetupDialog();
        if (mounted) {
          await _showRaSetupDialog();
        }
      }
    }
  }

  Future<void> _showRaSetupDialog() async {
    final keyController = TextEditingController();
    bool? isValid;
    bool isChecking = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return WillPopScope(
            onWillPop: () async => false,
            child: AlertDialog(
              backgroundColor: AppTheme.cardColor,
              title: const Text('🏆 RetroAchievements'),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.emoji_events,
                      size: 48,
                      color: AppTheme.accentColor,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Enhance your experience by connecting your RetroAchievements account to filter games with achievements.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    InkWell(
                      onTap: () => launchUrl(
                        Uri.parse('https://retroachievements.org/settings'),
                        mode: LaunchMode.externalApplication,
                      ),
                      child: const Text(
                        'Get your API Key here (Settings Page)',
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: keyController,
                      decoration: InputDecoration(
                        labelText: 'Web API Key',
                        // hintText: 'Found in your RA Control Panel', // Removed redundant hint
                        border: const OutlineInputBorder(),
                        suffixIcon: isChecking
                            ? const Padding(
                                padding: EdgeInsets.all(12.0),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : isValid == null
                            ? null
                            : Icon(
                                isValid! ? Icons.check_circle : Icons.error,
                                color: isValid! ? Colors.green : Colors.red,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text(
                    'Skip',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  onPressed: isChecking
                      ? null
                      : () async {
                          final key = keyController.text.trim();
                          if (key.isEmpty) return;

                          setState(() => isChecking = true);
                          final ra = ref.read(raServiceProvider);
                          final valid = await ra.validateKey(key);
                          setState(() {
                            isChecking = false;
                            isValid = valid;
                          });

                          if (valid) {
                            final config = ref.read(configServiceProvider);
                            await config.setRaApiKey(key);
                            if (context.mounted) Navigator.of(context).pop();
                          }
                        },
                  child: const Text('Verify & Save'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _showSetupDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false, // Prevent back button
        child: AlertDialog(
          backgroundColor: AppTheme.cardColor,
          title: const Text('Welcome to Romifleur'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.folder_open,
                size: 64,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(height: 16),
              const Text(
                'To get started, please select a folder where your games will be downloaded.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      '📂 Folder Structure',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Games will be downloaded automatically into console subfolders:',
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Selected Folder/console_name/game.rom',
                      style: TextStyle(fontFamily: 'monospace', fontSize: 13),
                    ),
                    SizedBox(height: 16),
                    Text(
                      '💡 Recommendation',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Text('Create a "ROMs" folder and select it.'),
                    SizedBox(height: 12),
                    Text(
                      'Example (N64):',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textMuted,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    Text(
                      '.../ROMs/n64/Mario64.n64',
                      style: TextStyle(fontFamily: 'monospace', fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () async {
                final String? result = await FilePicker.platform
                    .getDirectoryPath();
                if (result != null && mounted) {
                  final config = ref.read(configServiceProvider);
                  await config.setDownloadPath(result);
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Select Folder'),
            ),
          ],
        ),
      ),
    );
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
      appBar: AppBar(
        title: Image.asset(
          'assets/logo-romifleur.png',
          height: 32,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return const Row(
              children: [
                Icon(Icons.gamepad, size: 24, color: AppTheme.textPrimary),
                SizedBox(width: 8),
                Text(
                  'Romifleur',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            );
          },
        ),
        backgroundColor: AppTheme.sidebarColor,
        elevation: 0,
        centerTitle: false,
        actions: [
          SafeArea(
            child: IconButton(
              onPressed: _openSettings,
              icon: const Icon(Icons.settings, color: AppTheme.textMuted),
              splashRadius: 24,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBodyContent(showSidebarHeader: false),
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
