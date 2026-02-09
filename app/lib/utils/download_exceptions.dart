/// Thrown when a download stream ends before all expected bytes are received.
/// Carries metadata for retry/resume logic.
class IncompleteDownloadException implements Exception {
  final int received;
  final int expected;
  final String? tempFilePath;

  IncompleteDownloadException({
    required this.received,
    required this.expected,
    this.tempFilePath,
  });

  @override
  String toString() =>
      'Download incomplete: received $received of $expected bytes '
      '(${(received / expected * 100).toStringAsFixed(1)}%)';
}

/// Thrown when the SAF URI permission has expired or been revoked.
/// The user needs to re-select the download folder.
class SafPermissionException implements Exception {
  final String uri;
  final String message;

  SafPermissionException({
    required this.uri,
    this.message =
        'Storage access permission has expired. Please re-select your download folder.',
  });

  @override
  String toString() => 'SafPermissionException: $message';
}

/// Thrown when ZIP extraction or SAF copy fails after download completed.
/// Should NOT be retried (the download itself succeeded).
class ExtractionException implements Exception {
  final String message;
  ExtractionException(this.message);

  @override
  String toString() => 'ExtractionException: $message';
}
