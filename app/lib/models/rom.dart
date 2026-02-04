import 'ownership_status.dart';

/// ROM file model
class RomModel {
  final String filename;
  final String size;
  final bool hasAchievements;
  final OwnershipStatus ownershipStatus;
  bool isSelected;

  RomModel({
    required this.filename,
    this.size = 'N/A',
    this.hasAchievements = false,
    this.ownershipStatus = OwnershipStatus.notOwned,
    this.isSelected = false,
  });

  factory RomModel.fromJson(Map<String, dynamic> json) {
    return RomModel(
      filename: json['filename'] ?? '',
      size: json['size'] ?? 'N/A',
      hasAchievements: json['has_achievements'] ?? false,
    );
  }

  /// Extract clean game title from filename (full name without extension)
  String get title {
    String name = filename;
    // Remove extension
    final lastDot = name.lastIndexOf('.');
    if (lastDot > 0) {
      name = name.substring(0, lastDot);
    }
    return name;
  }

  /// Extract base title (text before first parenthesis) for partial matching
  /// Example: "Super Mario 64 (USA) (Rev 1).n64" -> "Super Mario 64"
  String get baseTitle {
    final parenIndex = filename.indexOf('(');
    if (parenIndex > 0) {
      return filename.substring(0, parenIndex).trim();
    }
    // No parenthesis, use title without extension
    return title;
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

  RomModel copyWith({
    bool? isSelected,
    OwnershipStatus? ownershipStatus,
    bool? hasAchievements,
  }) {
    return RomModel(
      filename: filename,
      size: size,
      hasAchievements: hasAchievements ?? this.hasAchievements,
      ownershipStatus: ownershipStatus ?? this.ownershipStatus,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}
