import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/theme.dart';
import '../providers/providers.dart';

class DownloadPanel extends ConsumerWidget {
  const DownloadPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(downloadQueueProvider);

    return Container(
      decoration: BoxDecoration(color: AppTheme.sidebarColor),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade800)),
            ),
            child: Row(
              children: [
                const Icon(Icons.download, color: AppTheme.accentColor),
                const SizedBox(width: 12),
                const Text(
                  'Download Queue',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.accentColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${state.items.length}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.accentColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Progress indicator (when downloading)
          if (state.progress.isDownloading) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                border: Border(bottom: BorderSide(color: Colors.grey.shade800)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          state.progress.status,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: state.progress.percentage / 100.0,
                      minHeight: 8,
                      backgroundColor: AppTheme.textMuted.withOpacity(0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        state.progress.status.startsWith('Extracting')
                            ? Colors.purpleAccent
                            : AppTheme.primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (state.progress.currentFile != null)
                    Text(
                      state.progress.currentFile!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textMuted,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],

          // Queue list
          Expanded(
            child: state.items.isEmpty
                ? _buildEmptyQueue()
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: state.items.length,
                    itemBuilder: (context, index) {
                      final item = state.items[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 6),
                        child: ListTile(
                          dense: true,
                          leading: const Icon(Icons.videogame_asset, size: 20),
                          title: Text(
                            item.filename,
                            style: const TextStyle(fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${item.console} • ${item.size}',
                            style: const TextStyle(fontSize: 11),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () {
                              ref
                                  .read(downloadQueueProvider.notifier)
                                  .removeFromQueue(index);
                            },
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Bottom actions
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              border: Border(top: BorderSide(color: Colors.grey.shade800)),
            ),
            child: Column(
              children: [
                // Start Download Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed:
                        state.items.isEmpty || state.progress.isDownloading
                        ? null
                        : () {
                            ref
                                .read(downloadQueueProvider.notifier)
                                .startDownloads();
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: state.progress.isDownloading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.rocket_launch),
                    label: Text(
                      state.progress.isDownloading
                          ? 'Downloading...'
                          : '${state.totalSize} - Start Downloads',
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Clear Queue Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed:
                        state.items.isEmpty || state.progress.isDownloading
                        ? null
                        : () {
                            ref
                                .read(downloadQueueProvider.notifier)
                                .clearQueue();
                          },
                    icon: const Icon(Icons.delete_sweep, size: 18),
                    label: const Text('Clear Queue'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyQueue() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.inbox,
            size: 48,
            color: AppTheme.textMuted.withOpacity(0.5),
          ),
          const SizedBox(height: 12),
          const Text(
            'Queue is empty',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 4),
          const Text(
            'Select games and add them here',
            style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }
}
