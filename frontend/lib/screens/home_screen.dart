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
  @override
  void initState() {
    super.initState();
    // Load download queue on startup
    Future.microtask(() {
      ref.read(downloadQueueProvider.notifier).loadQueue();
    });
  }

  @override
  Widget build(BuildContext context) {
    final downloadState = ref.watch(downloadQueueProvider);
    final queueCount = downloadState.items.length;

    return Scaffold(
      body: Row(
        children: [
          // Left Sidebar - Console Selection
          const ConsoleSidebar(),

          // Center - ROM List
          const Expanded(flex: 3, child: RomListPanel()),

          // Right Panel - Download Queue
          const SizedBox(width: 350, child: DownloadPanel()),
        ],
      ),

      // Floating Action Button for settings
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openSettings(context),
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.settings),
      ),
    );
  }

  void _openSettings(BuildContext context) {
    showDialog(context: context, builder: (context) => const SettingsDialog());
  }
}
