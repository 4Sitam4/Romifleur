import 'dart:async';
import 'package:romifleur/models/game_metadata.dart';
import 'package:romifleur/services/metadata_providers/metadata_provider.dart';
import 'package:path/path.dart' as p;

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

    // We'll wrap each future to handle errors internally and not crash the stream
    final futures = _providers.map((provider) async {
      try {
        final result = await provider.search(cleanName, consoleKey);
        if (result != null) {
          print('✅ [$cleanName] Provider ${provider.name} responded');
        } else {
          print('⚠️ [$cleanName] Provider ${provider.name} returned null');
        }
        return result;
      } catch (e) {
        print('⚠️ Provider ${provider.name} failed: $e');
        return null;
      }
    });

    // Launch all in parallel and process as they finish
    for (final future in futures) {
      future.then((result) {
        completedProviders++;

        if (result != null) {
          if (currentBest == null) {
            // First valid result!
            currentBest = result;
            controller.add(currentBest!);
          } else {
            // Merge if useful
            final merged = currentBest!.mergeWith(result);
            // If the merged result is different (more complete), emit it
            // Simple check: we can just emit and let UI decide, or check fields.
            // Let's emit to be safe.
            currentBest = merged;
            controller.add(currentBest!);
          }
        }

        // If we have a perfectly complete metadata, we can close early?
        // Maybe, but "complete" is subjective (e.g. maybe one provider has better description).
        // For now, let's wait for all or until user validation.
        // Actually, if isComplete is true, we might stop asking others?
        // But requests are already in flight.

        if (currentBest?.isComplete == true &&
            completedProviders == _providers.length) {
          controller.close();
        } else if (completedProviders == _providers.length) {
          // All done
          controller.close();
        }
      });
    }

    // Handle case where all fail?
    // The counter check above handles closing.
    // If provider list is empty, close immediately.
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
      print('❌ Aggregator error: $e');
    }

    return result ?? GameMetadata.empty(filename);
  }

  String _cleanFilename(String filename) {
    String name = p.basenameWithoutExtension(filename);
    name = name.replaceAll(RegExp(r'\s*[\(\[].*?[\)\]]'), '');
    return name.trim();
  }
}
