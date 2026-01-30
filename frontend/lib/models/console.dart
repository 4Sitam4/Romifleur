/// Console model representing a gaming platform
class ConsoleModel {
  final String key;
  final String name;
  final String folder;
  final String url;
  final List<String> exts;
  final List<String> bestGames;

  const ConsoleModel({
    required this.key,
    required this.name,
    required this.folder,
    required this.url,
    required this.exts,
    this.bestGames = const [],
  });

  factory ConsoleModel.fromJson(Map<String, dynamic> json) {
    return ConsoleModel(
      key: json['key'] ?? '',
      name: json['name'] ?? '',
      folder: json['folder'] ?? '',
      url: json['url'] ?? '',
      exts: List<String>.from(json['exts'] ?? []),
      bestGames: List<String>.from(json['best_games'] ?? []),
    );
  }
}

/// Category grouping multiple consoles (e.g., Nintendo, Sega, Sony)
class CategoryModel {
  final String category;
  final List<ConsoleModel> consoles;

  const CategoryModel({required this.category, required this.consoles});

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      category: json['category'] ?? '',
      consoles:
          (json['consoles'] as List<dynamic>?)
              ?.map((c) => ConsoleModel.fromJson(c))
              .toList() ??
          [],
    );
  }
}
