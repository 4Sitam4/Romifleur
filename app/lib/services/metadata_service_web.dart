import 'dart:async';
import 'package:romifleur/models/game_metadata.dart';
import 'package:romifleur/services/metadata_aggregator.dart';
import 'package:romifleur/services/metadata_providers/igdb_provider.dart';
import 'package:romifleur/services/metadata_providers/tgdb_provider.dart';

class MetadataService {
  Map<String, dynamic> _cache = {};
  final MetadataAggregator _aggregator;

  static final MetadataService _instance = MetadataService._internal();
  factory MetadataService() => _instance;

  MetadataService._internal()
    : _aggregator = MetadataAggregator([
        TgdbProvider(baseUrl: '/tgdb'),
        IgdbProvider(authUrl: '/twitch-auth/token', baseUrl: '/igdb'),
      ]);

  /// Initialize (In-memory only for web)
  Future<void> init() async {
    _cache = {};
  }

  Stream<GameMetadata> getMetadataStream(String consoleKey, String filename) {
    final cacheKey = '$consoleKey|$filename';
    final controller = StreamController<GameMetadata>();

    if (_cache.containsKey(cacheKey)) {
      try {
        final cachedMeta = GameMetadata.fromJson(_cache[cacheKey]);
        controller.add(cachedMeta);
      } catch (e) {
        print('⚠️ Error parsing cached metadata: $e');
      }
    }

    _aggregator
        .getMetadataStream(consoleKey, filename)
        .listen(
          (data) {
            _cache[cacheKey] = data.toJson();
            controller.add(data);
          },
          onError: (e) => controller.addError(e),
          onDone: () => controller.close(),
        );

    return controller.stream;
  }

  /// Get metadata for a game
  Future<Map<String, dynamic>> getMetadata(
    String consoleKey,
    String filename,
  ) async {
    final cacheKey = '$consoleKey|$filename';
    if (_cache.containsKey(cacheKey)) {
      return Map<String, dynamic>.from(_cache[cacheKey]);
    }

    final meta = await _aggregator.getMetadata(consoleKey, filename);
    final output = meta.toJson();
    _cache[cacheKey] = output;
    return output;
  }
}
