import 'dart:async';
import 'package:romifleur/models/game_metadata.dart';
import 'package:romifleur/services/metadata_providers/metadata_provider.dart';
import 'package:romifleur/utils/logger.dart';
import 'package:path/path.dart' as p;

const _log = AppLogger('MetadataAggregator');

class MetadataAggregator {
  final List<MetadataProvider> _providers;

  MetadataAggregator(this._providers);

  /// Returns a Stream that emits increasingly complete metadata.
  /// First result is emitted immediately. Subsequent results are emitted
  /// if they add missing information.
  Stream<GameMetadata> getMetadataStream(String consoleKey, String filename) {
    final cleanName = _cleanFilename(filename);
    final controller = StreamController<GameMetadata>();

    // Track current state
    GameMetadata? currentBest;
    int completedProviders = 0;
    bool cancelled = false;

    controller.onCancel = () {
      cancelled = true;
    };

    // We'll wrap each future to handle errors internally and not crash the stream
    final futures = _providers.map((provider) async {
      try {
        final result = await provider.search(cleanName, consoleKey);
        if (result != null) {
          _log.info('[$cleanName] Provider ${provider.name} responded');
        } else {
          _log.debug('[$cleanName] Provider ${provider.name} returned null');
        }
        return result;
      } catch (e) {
        _log.warning('Provider ${provider.name} failed: $e');
        return null;
      }
    });

    // Launch all in parallel and process as they finish
    for (final future in futures) {
      future.then((result) {
        if (cancelled || controller.isClosed) return;

        completedProviders++;

        if (result != null) {
          if (currentBest == null) {
            currentBest = result;
            controller.add(currentBest!);
          } else {
            final merged = currentBest!.mergeWith(result);
            currentBest = merged;
            controller.add(currentBest!);
          }
        }

        if (completedProviders == _providers.length) {
          controller.close();
        }
      });
    }

    if (_providers.isEmpty) controller.close();

    return controller.stream;
  }

  /// Convenience method to get the "final" metadata after a timeout or completion
  Future<GameMetadata> getMetadata(String consoleKey, String filename) async {
    GameMetadata? result;
    try {
      // Listen to the stream and update result
      await for (final meta in getMetadataStream(consoleKey, filename)) {
        result = meta;
        if (result.isComplete) break; // Optional optimization
      }
    } catch (e) {
      _log.error('Aggregator error: $e');
    }

    return result ?? GameMetadata.empty(filename);
  }

  String _cleanFilename(String filename) {
    String name = p.basenameWithoutExtension(filename);
    name = name.replaceAll(RegExp(r'\s*[\(\[].*?[\)\]]'), '');
    return name.trim();
  }
}
