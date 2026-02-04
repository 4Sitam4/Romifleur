import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../config/theme.dart';
import '../providers/providers.dart';

class SettingsDialog extends ConsumerStatefulWidget {
  const SettingsDialog({super.key});

  @override
  ConsumerState<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends ConsumerState<SettingsDialog> {
  final _romsPathController = TextEditingController();
  final _raKeyController = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;
  bool? _keyValid;

  // Console folder state
  bool _showConsoleFolders = false;
  Map<String, String> _customPaths = {};
  List<String> _availableFolders = [];
  String _newFolderName = '';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final config = ref.read(configServiceProvider);
      _romsPathController.text = await config.getDownloadPath() ?? '';
      _raKeyController.text = config.raApiKey;
      _customPaths = config.getAllConsolePaths();

      // For web, load available folders
      if (kIsWeb) {
        _availableFolders = await config.listAvailableFolders();
      }
    } catch (e) {
      // Handle error
    }
    setState(() => _isLoading = false);
  }

  Future<void> _pickFolder() async {
    final result = await FilePicker.platform.getDirectoryPath();
    if (result != null) {
      _romsPathController.text = result;
    }
  }

  Future<void> _pickConsoleFolder(String consoleKey) async {
    final result = await FilePicker.platform.getDirectoryPath();
    if (result != null) {
      final config = ref.read(configServiceProvider);
      await config.setConsolePath(consoleKey, result);
      setState(() => _customPaths[consoleKey] = result);
    }
  }

  Future<void> _setWebConsoleFolder(String consoleKey, String folder) async {
    final config = ref.read(configServiceProvider);
    await config.setConsolePath(consoleKey, folder);
    setState(() => _customPaths[consoleKey] = folder);
  }

  Future<void> _createFolder(String name) async {
    if (name.isEmpty) return;
    final config = ref.read(configServiceProvider);
    final success = await config.createFolder(name);
    if (success) {
      setState(() {
        _availableFolders.add(name);
        _availableFolders.sort();
      });
    }
  }

  Future<void> _clearConsoleFolder(String consoleKey) async {
    final config = ref.read(configServiceProvider);
    await config.clearConsolePath(consoleKey);
    setState(() => _customPaths.remove(consoleKey));
  }

  Future<void> _validateKey() async {
    final key = _raKeyController.text.trim();
    if (key.isEmpty) {
      setState(() => _keyValid = null);
      return;
    }

    final ra = ref.read(raServiceProvider);
    final valid = await ra.validateKey(key);
    setState(() => _keyValid = valid);
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);

    final config = ref.read(configServiceProvider);
    await config.setDownloadPath(_romsPathController.text);
    await config.setRaApiKey(_raKeyController.text);

    setState(() => _isSaving = false);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        padding: const EdgeInsets.all(24),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        const Icon(
                          Icons.settings,
                          color: AppTheme.primaryColor,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Settings',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // ROMs Path
                    Text(
                      'Download Location',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _romsPathController,
                            decoration: const InputDecoration(
                              hintText: 'Path to save ROMs',
                              prefixIcon: Icon(Icons.folder),
                            ),
                          ),
                        ),
                        if (!kIsWeb) ...[
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: _pickFolder,
                            icon: const Icon(Icons.folder_open),
                            label: const Text('Browse'),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Console Folders Section
                    _buildConsoleFoldersSection(),
                    const SizedBox(height: 24),

                    // RetroAchievements API Key
                    Text(
                      'RetroAchievements API Key',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Get your key from retroachievements.org/controlpanel.php',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _raKeyController,
                            obscureText: true,
                            decoration: InputDecoration(
                              hintText: 'Your Web API Key',
                              prefixIcon: const Icon(Icons.key),
                              suffixIcon: _keyValid == null
                                  ? null
                                  : Icon(
                                      _keyValid!
                                          ? Icons.check_circle
                                          : Icons.error,
                                      color: _keyValid!
                                          ? AppTheme.accentColor
                                          : AppTheme.errorColor,
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: _validateKey,
                          child: const Text('Validate'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: _isSaving ? null : _saveSettings,
                          child: _isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Save'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildConsoleFoldersSection() {
    final config = ref.read(configServiceProvider);
    final consoles = config.consoles;

    // Flatten consoles list
    final allConsoles = <Map<String, dynamic>>[];
    consoles.forEach((category, consolesMap) {
      consolesMap.forEach((key, data) {
        allConsoles.add({
          'key': key,
          'name': data['name'] ?? key,
          'folder': data['folder'] ?? key,
        });
      });
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () =>
              setState(() => _showConsoleFolders = !_showConsoleFolders),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(
                  _showConsoleFolders
                      ? Icons.keyboard_arrow_down
                      : Icons.keyboard_arrow_right,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'Console Folders',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (_customPaths.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_customPaths.length} custom',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (_showConsoleFolders) ...[
          const SizedBox(height: 4),
          Text(
            'Override the default folder for each console',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),

          // Web: Create new folder option
          if (kIsWeb) ...[
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'New folder name',
                      isDense: true,
                    ),
                    onChanged: (v) => _newFolderName = v,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.create_new_folder),
                  onPressed: () => _createFolder(_newFolderName),
                  tooltip: 'Create folder',
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],

          // Console list
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.borderColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: allConsoles.length,
              itemBuilder: (context, index) {
                final console = allConsoles[index];
                final key = console['key'] as String;
                final name = console['name'] as String;
                final defaultFolder = console['folder'] as String;
                final customPath = _customPaths[key];

                return ListTile(
                  dense: true,
                  title: Text(name, style: const TextStyle(fontSize: 13)),
                  subtitle: Text(
                    customPath ?? 'Default: $defaultFolder',
                    style: TextStyle(
                      fontSize: 11,
                      color: customPath != null
                          ? AppTheme.primaryColor
                          : AppTheme.textMuted,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (kIsWeb)
                        SizedBox(
                          width: 120,
                          child: DropdownButton<String>(
                            value: customPath,
                            isExpanded: true,
                            hint: const Text(
                              'Default',
                              style: TextStyle(fontSize: 12),
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text(
                                  'Default',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                              ..._availableFolders.map(
                                (f) => DropdownMenuItem(
                                  value: f,
                                  child: Text(
                                    f,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              ),
                            ],
                            onChanged: (value) {
                              if (value == null) {
                                _clearConsoleFolder(key);
                              } else {
                                _setWebConsoleFolder(key, value);
                              }
                            },
                          ),
                        )
                      else ...[
                        IconButton(
                          icon: const Icon(Icons.folder_open, size: 20),
                          onPressed: () => _pickConsoleFolder(key),
                          tooltip: 'Browse',
                        ),
                      ],
                      if (customPath != null)
                        IconButton(
                          icon: const Icon(Icons.refresh, size: 18),
                          onPressed: () => _clearConsoleFolder(key),
                          tooltip: 'Reset to default',
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  @override
  void dispose() {
    _romsPathController.dispose();
    _raKeyController.dispose();
    super.dispose();
  }
}
