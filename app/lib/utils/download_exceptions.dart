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
