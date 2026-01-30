/// Download queue item model
class DownloadItem {
  final String category;
  final String console;
  final String filename;
  final String size;

  const DownloadItem({
    required this.category,
    required this.console,
    required this.filename,
    this.size = 'N/A',
  });

  factory DownloadItem.fromJson(Map<String, dynamic> json) {
    return DownloadItem(
      category: json['category'] ?? '',
      console: json['console'] ?? '',
      filename: json['filename'] ?? '',
      size: json['size'] ?? 'N/A',
    );
  }

  Map<String, dynamic> toJson() => {
    'category': category,
    'console': console,
    'filename': filename,
    'size': size,
  };
}

/// Download progress state
class DownloadProgress {
  final int current;
  final int total;
  final double percentage;
  final String status;
  final String? currentFile;
  final bool isDownloading;

  const DownloadProgress({
    this.current = 0,
    this.total = 0,
    this.percentage = 0.0,
    this.status = '',
    this.currentFile,
    this.isDownloading = false,
  });

  factory DownloadProgress.fromJson(Map<String, dynamic> json) {
    return DownloadProgress(
      current: json['current'] ?? 0,
      total: json['total'] ?? 0,
      percentage: (json['percentage'] ?? 0.0).toDouble(),
      status: json['status'] ?? '',
      currentFile: json['current_file'],
      isDownloading: json['is_downloading'] ?? false,
    );
  }
}
