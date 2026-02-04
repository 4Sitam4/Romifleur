import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/saf_helper.dart'; // Conditional import for Web compatibility
import 'package:url_launcher/url_launcher.dart';
import '../config/theme.dart';
import '../providers/providers.dart';
import '../widgets/console_sidebar.dart';
import '../widgets/rom_list.dart';
import '../widgets/download_panel.dart';
import 'settings_screen.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

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
    final location = await config.getEffectiveDownloadLocation();

    if (location == null) {
      if (mounted) {
        await _showSetupDialog();
        if (mounted) {
          await _showRaSetupDialog();
        }
      }
    }

    if (mounted) {
      _checkForUpdates();
    }
  }

  Future<void> _checkForUpdates() async {
    // Check updates for all platforms including Web/Docker
    try {
      final updateService = ref.read(updateServiceProvider);
      final updateInfo = await updateService.checkForUpdates();

      if (updateInfo != null && updateInfo.hasUpdate && mounted) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppTheme.cardColor,
            title: Row(
              children: [
                const Icon(Icons.new_releases, color: AppTheme.accentColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Update Available: ${updateInfo.latestVersion}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 500,
              height: 400, // Fixed height for scrolling
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'A new version is available (Current: ${updateInfo.currentVersion})',
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  Expanded(
                    child: Markdown(
                      data: updateInfo.changelogDiff,
                      styleSheet: MarkdownStyleSheet(
                        p: const TextStyle(color: AppTheme.textPrimary),
                        h1: const TextStyle(
                          color: AppTheme.accentColor,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        h2: const TextStyle(
                          color: AppTheme.accentColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        h3: const TextStyle(
                          color: AppTheme.primaryColor,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        listBullet: const TextStyle(
                          color: AppTheme.textSecondary,
                        ),
                        strong: const TextStyle(color: Colors.white),
                        blockquote: TextStyle(
                          color: AppTheme.textMuted,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Later',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  launchUrl(
                    Uri.parse(
                      'https://github.com/4Sitam4/Romifleur/releases/latest',
                    ),
                    mode: LaunchMode.externalApplication,
                  );
                },
                child: const Text('View Release'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      print('Update check failed: $e');
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
                final config = ref.read(configServiceProvider);

                if (!kIsWeb && Platform.isAndroid) {
                  // Android: Use SAF for proper SD card support
                  try {
                    final safUtil = SafUtil();
                    final result = await safUtil.pickDirectory(
                      writePermission: true,
                      persistablePermission: true,
                    );
                    if (result != null && mounted) {
                      print('✅ SAF folder selected: ${result.uri}');
                      // Store the SAF URI, not the path
                      await config.setDownloadUri(result.uri);
                      Navigator.of(context).pop();
                    }
                  } catch (e) {
                    print(
                      '⚠️ SAF picker failed: $e - falling back to FilePicker',
                    );
                    // Fallback to FilePicker if SAF fails
                    final granted = await _requestStoragePermission();
                    if (!granted) return;

                    final String? result = await FilePicker.platform
                        .getDirectoryPath();
                    if (result != null && mounted) {
                      print('📁 FilePicker result: $result');
                      // Check if FilePicker returned a content:// URI (Android 11+)
                      if (result.startsWith('content://')) {
                        await config.setDownloadUri(result);
                      } else {
                        await config.setDownloadPath(result);
                      }
                      Navigator.of(context).pop();
                    }
                  }
                } else {
                  // Other platforms: use FilePicker
                  final String? result = await FilePicker.platform
                      .getDirectoryPath();
                  if (result != null && mounted) {
                    await config.setDownloadPath(result);
                    Navigator.of(context).pop();
                  }
                }
              },
              child: const Text('Select Folder'),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _requestStoragePermission() async {
    // Android 11+ (API 30+) requires MANAGE_EXTERNAL_STORAGE for arbitrary folder access
    // But verify if we really need it. For "PathAccessException", standard filtering might fail.
    // Ideally we should try basic storage first.

    // Check for Manage External Storage (Android 11+)
    if (await Permission.manageExternalStorage.status.isGranted) {
      return true;
    }

    if (await Permission.storage.request().isGranted) {
      return true;
    }

    // If storage is denied or restricted (Android 11+), try requesting Manage External Storage
    if (await Permission.manageExternalStorage.request().isGranted) {
      return true;
    }

    // If we are here, permission is denied.
    // On Android 13+, photos/audio/video permissions are separate but for generic files logic is complex.
    // Let's try to request manageExternalStorage again if it's permanently denied or open settings.

    if (await Permission.manageExternalStorage.isPermanentlyDenied ||
        await Permission.storage.isPermanentlyDenied) {
      if (mounted) {
        _showPermissionDialog();
      }
      return false;
    }

    return false;
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Storage Permission Required'),
        content: const Text(
          'To download ROMs to your device, Romifleur needs access to your storage. Please grant the "All files access" or Storage permission in Settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              openAppSettings();
              Navigator.pop(context);
            },
            child: const Text('Open Settings'),
          ),
        ],
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
      backgroundColor: AppTheme.sidebarColor,
      body: SafeArea(
        left: true,
        right: true,
        top: false, // Keep status bar overlay
        bottom: false,
        child: Row(
          children: [
            SizedBox(
              width: 280,
              child: ConsoleSidebar(
                onConsoleSelected: null,
              ), // No auto-switch on desktop
            ),
            const Expanded(child: RomListPanel()),
            const VerticalDivider(thickness: 1, width: 1),
            const SizedBox(width: 350, child: DownloadPanel()),
          ],
        ),
      ),
    );
  }

  Widget _buildTabletLayout() {
    return Scaffold(
      backgroundColor: AppTheme.sidebarColor,
      body: SafeArea(
        left: true,
        right: true,
        top: false,
        bottom: false,
        child: Row(
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
              unselectedIconTheme: const IconThemeData(
                color: AppTheme.textMuted,
              ),
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
