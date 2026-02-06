import 'package:flutter/foundation.dart';
import 'package:romifleur/utils/logger.dart';

const _log = AppLogger('CancellationToken');

/// A simple token that can be passed to async operations to signal cancellation.
class DownloadCancellationToken {
  bool _isCancelled = false;
  final List<VoidCallback> _listeners = [];

  bool get isCancelled => _isCancelled;

  /// Registers a callback to be called when cancellation is requested.
  /// If already cancelled, the callback is executed immediately.
  void onCancel(VoidCallback callback) {
    if (_isCancelled) {
      callback();
    } else {
      _listeners.add(callback);
    }
  }

  /// Signals that the operation should be cancelled.
  void cancel() {
    if (_isCancelled) return;
    _isCancelled = true;
    for (final listener in _listeners) {
      try {
        listener();
      } catch (e) {
        _log.error('Error in cancellation listener: $e');
      }
    }
    _listeners.clear();
  }
}
