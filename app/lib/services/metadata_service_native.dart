import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:romifleur/models/game_metadata.dart';
import 'package:romifleur/services/config_service.dart';
import 'package:romifleur/services/metadata_aggregator.dart';
import 'package:romifleur/services/metadata_providers/igdb_provider.dart';
import 'package:romifleur/services/metadata_providers/tgdb_provider.dart';

class MetadataService {
  final ConfigService _config = ConfigService();
  Map<String, dynamic> _cache = {};
  final MetadataAggregator _aggregator;

  static final MetadataService _instance = MetadataService._internal();
  factory MetadataService() => _instance;

  MetadataService._internal()
    : _aggregator = MetadataAggregator([TgdbProvider(), IgdbProvider()]);

  /// Initialize and load cache
  Future<void> init() async {
    await _loadCache();
  }

  Future<void> _loadCache() async {
    final dir = await _config.getDataDir();
    final file = File(p.join(dir, 'metadata_cache.json'));
    if (await file.exists()) {
      try {
        final content = await file.readAsString();
        _cache = json.decode(content);
      } catch (e) {
        print('⚠️ Error loading metadata cache: $e');
      }
    }
  }

  Future<void> _saveCache() async {
    final dir = await _config.getDataDir();
    final file = File(p.join(dir, 'metadata_cache.json'));
    await file.writeAsString(json.encode(_cache));
  }

  /// Get metadata stream for progressive enrichment
  Stream<GameMetadata> getMetadataStream(String consoleKey, String filename) {
    final cacheKey = '$consoleKey|$filename';
    final cleanName = p.basenameWithoutExtension(filename);

    // Create a controller to manage the stream
    final controller = StreamController<GameMetadata>();

    // If we have cached data, emit it first
    if (_cache.containsKey(cacheKey)) {
      print('📦 [$cleanName] CACHE HIT');
      final cachedMap = _cache[cacheKey];
      // Check if it's the old format or new
      // We can convert Map to GameMetadata
      try {
        final cachedMeta = GameMetadata.fromJson(cachedMap);
        controller.add(cachedMeta);

        // If cached meta is complete, maybe we don't need to fetch?
        // But user might want refresh. For now, let's fetch only if missing info?
        // Or always fetch to be sure? The aggregator handles fetching.
        // Let's invoke aggregator but merge with cache?
        // The aggregator logic is: fetch all.
        // We can just pipe the aggregator stream into this controller.
      } catch (e) {
        print('⚠️ Error parsing cached metadata: $e');
      }
    }

    // Pipe the aggregator stream
    _aggregator
        .getMetadataStream(consoleKey, filename)
        .listen(
          (data) {
            // Update cache with latest data
            _cache[cacheKey] = data.toJson();
            _saveCache();
            controller.add(data);
          },
          onError: (e) => controller.addError(e),
          onDone: () => controller.close(),
        );

    return controller.stream;
  }

  /// Get metadata for a game (Future-based compatibility)
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
    _saveCache(); // Fire and forget save
    return output;
  }
}
