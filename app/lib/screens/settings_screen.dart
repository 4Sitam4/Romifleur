import 'package:flutter/material.dart';
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
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _pickFolder,
                          icon: const Icon(Icons.folder_open),
                          label: const Text('Browse'),
                        ),
                      ],
                    ),
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

  @override
  void dispose() {
    _romsPathController.dispose();
    _raKeyController.dispose();
    super.dispose();
  }
}
