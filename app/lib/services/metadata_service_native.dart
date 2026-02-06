import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:romifleur/models/game_metadata.dart';
import 'package:romifleur/services/config_service.dart';
import 'package:romifleur/services/metadata_aggregator.dart';
import 'package:romifleur/services/metadata_providers/igdb_provider.dart';
import 'package:romifleur/services/metadata_providers/tgdb_provider.dart';
import 'package:romifleur/utils/logger.dart';

const _log = AppLogger('MetadataService');

class MetadataService {
  final ConfigService _config = ConfigService();
  Map<String, dynamic> _cache = {};
  final MetadataAggregator _aggregator;
  Timer? _saveTimer;

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
        _log.warning('Error loading metadata cache: $e');
      }
    }
  }

  void _scheduleSaveCache() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), () {
      _doSaveCache();
    });
  }

  Future<void> _doSaveCache() async {
    try {
      final dir = await _config.getDataDir();
      final file = File(p.join(dir, 'metadata_cache.json'));
      await file.writeAsString(json.encode(_cache));
    } catch (e) {
      _log.warning('Error saving metadata cache: $e');
    }
  }

  /// Get metadata stream for progressive enrichment
  Stream<GameMetadata> getMetadataStream(String consoleKey, String filename) {
    final cacheKey = '$consoleKey|$filename';
    final cleanName = p.basenameWithoutExtension(filename);

    // Create a controller to manage the stream
    final controller = StreamController<GameMetadata>();

    // If we have cached data, emit it first
    if (_cache.containsKey(cacheKey)) {
      _log.debug('[$cleanName] Cache hit');
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
        _log.warning('Error parsing cached metadata: $e');
      }
    }

    // Pipe the aggregator stream
    late StreamSubscription<GameMetadata> sub;
    sub = _aggregator
        .getMetadataStream(consoleKey, filename)
        .listen(
          (data) {
            // Update cache with latest data
            _cache[cacheKey] = data.toJson();
            _scheduleSaveCache();
            if (!controller.isClosed) {
              controller.add(data);
            }
          },
          onError: (e) {
            if (!controller.isClosed) controller.addError(e);
          },
          onDone: () {
            if (!controller.isClosed) controller.close();
          },
        );

    controller.onCancel = () {
      sub.cancel();
    };

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
    _scheduleSaveCache();
    return output;
  }
}
