/// ROM file model
class RomModel {
  final String filename;
  final String size;
  final bool hasAchievements;
  bool isSelected;

  RomModel({
    required this.filename,
    this.size = 'N/A',
    this.hasAchievements = false,
    this.isSelected = false,
  });

  factory RomModel.fromJson(Map<String, dynamic> json) {
    return RomModel(
      filename: json['filename'] ?? '',
      size: json['size'] ?? 'N/A',
      hasAchievements: json['has_achievements'] ?? false,
    );
  }

  /// Extract clean game title from filename
  String get title {
    String name = filename;
    // Remove extension
    final lastDot = name.lastIndexOf('.');
    if (lastDot > 0) {
      name = name.substring(0, lastDot);
    }
    return name;
  }

  /// Get region from filename (Europe, USA, Japan, etc.)
  String? get region {
    final match = RegExp(r'\(([^)]+)\)').firstMatch(filename);
    if (match != null) {
      final content = match.group(1)!;
      if (content.contains('Europe') || content.contains('France'))
        return '🇪🇺';
      if (content.contains('USA')) return '🇺🇸';
      if (content.contains('Japan')) return '🇯🇵';
      if (content.contains('World')) return '🌍';
    }
    return null;
  }

  RomModel copyWith({bool? isSelected}) {
    return RomModel(
      filename: filename,
      size: size,
      hasAchievements: hasAchievements,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}
