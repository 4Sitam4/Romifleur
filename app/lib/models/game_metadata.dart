class GameMetadata {
  final String title;
  final String? description;
  final String? releaseDate;
  final String? imageUrl;
  final String provider;
  final String? developer;
  final String? publisher;
  final String? genre;
  final String? rating;
  final String? players;

  const GameMetadata({
    required this.title,
    this.description,
    this.releaseDate,
    this.imageUrl,
    required this.provider,
    this.developer,
    this.publisher,
    this.genre,
    this.rating,
    this.players,
  });

  /// Check if the metadata has all essential fields
  bool get isComplete =>
      description != null &&
      description!.isNotEmpty &&
      description != "No description available." &&
      releaseDate != null &&
      releaseDate != "Unknown" &&
      imageUrl != null &&
      imageUrl!.isNotEmpty &&
      developer != null &&
      publisher != null &&
      genre != null &&
      players != null;

  /// Merge this metadata with another, giving preference to non-null fields
  /// from the other metadata if this one is missing them.
  GameMetadata mergeWith(GameMetadata other) {
    return GameMetadata(
      title: title, // Title usually stays the same or we keep the first one
      description:
          (description == null ||
              description == "No description available." ||
              description!.isEmpty)
          ? other.description
          : description,
      releaseDate: (releaseDate == null || releaseDate == "Unknown")
          ? other.releaseDate
          : releaseDate,
      imageUrl: (imageUrl == null || imageUrl!.isEmpty)
          ? other.imageUrl
          : imageUrl,
      provider: '$provider + ${other.provider}',
      developer: (developer == null || developer == "Unknown")
          ? other.developer
          : developer,
      publisher: (publisher == null || publisher == "Unknown")
          ? other.publisher
          : publisher,
      genre: (genre == null || genre == "Unknown") ? other.genre : genre,
      rating: (rating == null || rating == "Unknown") ? other.rating : rating,
      players: (players == null || players == "Unknown")
          ? other.players
          : players,
    );
  }

  factory GameMetadata.empty(String filename) {
    return GameMetadata(
      title: filename,
      description: "No description available.",
      releaseDate: "Unknown",
      imageUrl: null,
      provider: "None",
      developer: "Unknown",
      publisher: "Unknown",
      genre: "Unknown",
      rating: "Unknown",
      players: "Unknown",
    );
  }

  factory GameMetadata.loading(String filename) {
    return GameMetadata(
      title: filename,
      description: "Loading...",
      releaseDate: "...",
      imageUrl: null,
      provider: "Loading",
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'date': releaseDate,
      'image_url': imageUrl,
      'provider': provider,
      'developer': developer,
      'publisher': publisher,
      'genre': genre,
      'rating': rating,
      'players': players,
      'has_achievements': false, // Kept for compatibility
    };
  }

  factory GameMetadata.fromJson(Map<String, dynamic> json) {
    return GameMetadata(
      title: json['title'] ?? 'Unknown',
      description: json['description'],
      releaseDate: json['date'],
      imageUrl: json['image_url'],
      provider: json['provider'] ?? 'Cached',
      developer: json['developer'],
      publisher: json['publisher'],
      genre: json['genre'],
      rating: json['rating'],
      players: json['players'],
    );
  }
}
