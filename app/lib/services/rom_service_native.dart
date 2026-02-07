import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';
import 'package:romifleur/services/config_service.dart';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:romifleur/models/rom.dart';
import 'package:romifleur/utils/cancellation_token.dart';
import 'package:romifleur/utils/download_exceptions.dart';
import 'package:romifleur/utils/logger.dart';
import 'package:saf_stream/saf_stream.dart';
import 'package:saf_util/saf_util.dart';

const _log = AppLogger('RomService');

// Top-level isolated function for background extraction
// Uses extractFileToDisk for memory-efficient streaming extraction
// This processes file-by-file without loading entire archive into RAM
void _isolateExtraction(List<dynamic> args) {
  final String zipPath = args[0];
  final String destPath = args[1];
  final SendPort sendPort = args[2];

  try {
    extractFileToDisk(zipPath, destPath);
    sendPort.send(true); // Done
  } catch (e) {
    sendPort.send(e.toString()); // Error
  }
}

class DownloadProgressEvent {
  final double progress; // 0.0 to 1.0 (or > 1.0 for extraction)
  final int receivedBytes;
  final int totalBytes;

  const DownloadProgressEvent({
    required this.progress,
    required this.receivedBytes,
    required this.totalBytes,
  });
}

class _CacheEntry {
  final List<RomModel> data;
  final DateTime createdAt;
  _CacheEntry(this.data) : createdAt = DateTime.now();

  bool get isExpired => DateTime.now().difference(createdAt).inMinutes > 30;
}

class RomService {
  final ConfigService _configService = ConfigService();
  final Map<String, _CacheEntry> _cache = {};
  static const int _maxCacheEntries = 10;

  Future<List<RomModel>> fetchFileList(
    String category,
    String consoleKey, {
    bool forceReload = false,
  }) async {
    final cacheKey = '${category}_$consoleKey';
    final entry = _cache[cacheKey];
    if (!forceReload && entry != null && !entry.isExpired) {
      return entry.data;
    }

    final config = _configService.getConsoleConfig(category, consoleKey);
    if (config == null) throw Exception('Console config not found');

    final String url = config['url'];
    final List<dynamic> exts = config['exts'];
    final validExts = exts.map((e) => e.toString().toLowerCase()).toList();

    try {
      _log.info('Fetching ROM list from: $url');
      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) {
        throw Exception('HTTP Error ${response.statusCode}');
      }

      final document = html_parser.parse(response.body);
      final List<RomModel> roms = [];

      final links = document.querySelectorAll('a');
      for (final link in links) {
        final href = link.attributes['href'];
        if (href == null) continue;

        final lowerHref = href.toLowerCase();
        if (validExts.any((ext) => lowerHref.endsWith(ext))) {
          final filename = Uri.decodeComponent(href);
          if (filename == '.' || filename == '..') continue;

          final size = _extractSize(link);
          roms.add(RomModel(filename: filename, size: size));
        }
      }

      // Evict oldest entry if at capacity
      if (_cache.length >= _maxCacheEntries) {
        final oldest = _cache.entries.reduce(
          (a, b) => a.value.createdAt.isBefore(b.value.createdAt) ? a : b,
        );
        _cache.remove(oldest.key);
      }
      _cache[cacheKey] = _CacheEntry(roms);
      return roms;
    } catch (e) {
      _log.error('Error fetching file list: $e');
      return [];
    }
  }

  String _extractSize(Element link) {
    // Strategy 1: Table based
    final parentTd = link.parent;
    if (parentTd?.localName == 'td') {
      var nextParams = parentTd?.parent?.children;
      if (nextParams != null) {
        for (var td in nextParams) {
          final text = td.text.trim();
          if (RegExp(
                r'\d+(\.\d+)?\s*[BKMG]i?B?',
                caseSensitive: false,
              ).hasMatch(text) &&
              !text.contains('-')) {
            return text;
          }
        }
      }
    }

    // Strategy 2: Text based
    if (link.parentNode != null) {
      final siblings = link.parentNode!.nodes;
      final index = siblings.indexOf(link);
      if (index != -1) {
        for (var i = index + 1; i < siblings.length; i++) {
          final node = siblings[i];
          if (node.nodeType == Node.TEXT_NODE &&
              node.text?.trim().isNotEmpty == true) {
            final parts = node.text!.trim().split(RegExp(r'\s+'));
            if (parts.isNotEmpty) {
              final candidate = parts.last;
              if (RegExp(r'^[\d\.]+[BKMG]$').hasMatch(candidate)) {
                return candidate;
              }
            }
            break;
          }
        }
      }
    }
    return 'N/A';
  }

  Future<List<RomModel>> search(
    String category,
    String consoleKey,
    String query, {
    List<String>? regions,
    List<String>? languages,
    bool hideDemos = true,
    bool hideBetas = true,
    bool hideUnlicensed = true,
  }) async {
    var roms = await fetchFileList(category, consoleKey);
    final activeRegions = regions ?? [];
    final activeLanguages = languages ?? [];
    final queryLower = query.toLowerCase();
    List<RomModel> filtered = [];

    for (var rom in roms) {
      final filename = rom.filename;

      // 1. Search query filter
      if (query.isNotEmpty && !filename.toLowerCase().contains(queryLower)) {
        continue;
      }

      // 2. Region filter (if any regions are selected)
      // Matches: (USA), (Europe), (Japan), (World), etc.
      if (activeRegions.isNotEmpty) {
        bool regionMatch = activeRegions.any((r) => filename.contains('($r)'));
        if (!regionMatch) continue;
      }

      // 3. Language filter (if any languages are selected)
      // Matches: (En), (Fr), (En,Fr,De), (Fr,De,Es,It), etc.
      if (activeLanguages.isNotEmpty) {
        bool languageMatch = false;
        for (var lang in activeLanguages) {
          // Match standalone: (Fr) or at start: (Fr, or in middle: ,Fr, or at end: ,Fr)
          if (filename.contains('($lang)') ||
              filename.contains('($lang,') ||
              filename.contains(',$lang,') ||
              filename.contains(',$lang)')) {
            languageMatch = true;
            break;
          }
        }
        if (!languageMatch) continue;
      }

      // 4. Hide Demos/Samples
      if (hideDemos &&
          (filename.contains('(Demo') || filename.contains('(Sample'))) {
        continue;
      }

      // 5. Hide Betas/Protos
      if (hideBetas &&
          (filename.contains('(Beta') || filename.contains('(Proto'))) {
        continue;
      }

      // 6. Hide Unlicensed
      if (hideUnlicensed && filename.contains('(Unl)')) {
        continue;
      }

      filtered.add(rom);
    }

    // Sort alphabetically
    filtered.sort((a, b) => a.filename.compareTo(b.filename));
    return filtered;
  }

  Stream<DownloadProgressEvent> downloadFile(
    String category,
    String consoleKey,
    String filename, {
    required String saveDir,
    String? customPath,
    DownloadCancellationToken? cancelToken,
    int resumeFrom = 0,
  }) async* {
    final config = _configService.getConsoleConfig(category, consoleKey);
    if (config == null) throw Exception('Config error');

    String baseUrl = config['url'];
    if (!baseUrl.endsWith('/')) baseUrl += '/';
    final encodedName = Uri.encodeComponent(filename).replaceAll('+', '%20');
    final downloadUrl = '$baseUrl$encodedName';

    // Check if we're using SAF (content:// URI)
    final bool useSaf = _configService.isSafUri(saveDir);

    _log.info('Downloading: $downloadUrl${resumeFrom > 0 ? ' (resuming from $resumeFrom bytes)' : ''}');
    _log.info('Save dir: $saveDir (SAF: $useSaf)');

    // HTTP client with timeouts to detect dead connections
    final rawHttpClient = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30)
      ..idleTimeout = const Duration(seconds: 60);
    final client = IOClient(rawHttpClient);

    // Register cancellation
    cancelToken?.onCancel(() {
      _log.info('Download cancelled: $filename');
      client.close();
    });

    try {
      final request = http.Request('GET', Uri.parse(downloadUrl));
      request.headers.addAll({
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
        'Referer': baseUrl,
      });
      if (resumeFrom > 0 && !useSaf) {
        request.headers['Range'] = 'bytes=$resumeFrom-';
      }

      final response = await client.send(request);

      // Handle resume: server returns 206 for Range requests, 200 for full
      int totalLength;
      int received;
      if (resumeFrom > 0 && response.statusCode == 206) {
        totalLength = (response.contentLength ?? 0) + resumeFrom;
        received = resumeFrom;
        _log.info('Resume accepted: continuing from $resumeFrom bytes');
      } else {
        totalLength = response.contentLength ?? 0;
        received = 0;
        if (resumeFrom > 0) {
          _log.warning('Server ignored Range header (status ${response.statusCode}), restarting from 0');
        }
      }

      if (useSaf) {
        // === SAF PATH (Android SD Card) ===
        await for (final progress in _downloadWithSaf(
          response.stream,
          saveDir,
          config['folder'] ?? consoleKey,
          filename,
          totalLength,
          cancelToken,
        )) {
          yield progress;
        }
      } else {
        // === REGULAR PATH (Internal storage / Desktop) ===
        final String finalPath;
        if (customPath != null && customPath.isNotEmpty) {
          finalPath = p.join(customPath, filename);
        } else {
          finalPath = p.join(saveDir, config['folder'] ?? consoleKey, filename);
        }

        await Directory(p.dirname(finalPath)).create(recursive: true);

        if (await File(finalPath).exists()) {
          yield DownloadProgressEvent(
            progress: 1.0,
            receivedBytes: totalLength,
            totalBytes: totalLength,
          );
          return;
        }

        final file = File('$finalPath.tmp');
        IOSink? sink;

        try {
          // Append mode if resuming, write mode otherwise
          if (resumeFrom > 0 && await file.exists()) {
            sink = file.openWrite(mode: FileMode.append);
          } else {
            sink = file.openWrite();
          }
          int lastReportedBytes = received;

          await for (final chunk in response.stream) {
            if (cancelToken?.isCancelled ?? false) {
              throw Exception('Download cancelled');
            }
            sink.add(chunk);
            received += chunk.length;

            // Throttle: Update only every 100KB
            if (totalLength > 0 &&
                (received - lastReportedBytes > 1024 * 100 ||
                    received == totalLength)) {
              yield DownloadProgressEvent(
                progress: received / totalLength,
                receivedBytes: received,
                totalBytes: totalLength,
              );
              lastReportedBytes = received;
            }
          }
          await sink.close();
          sink = null;

          // Verify download completeness
          if (totalLength > 0 && received != totalLength) {
            throw IncompleteDownloadException(
              received: received,
              expected: totalLength,
              tempFilePath: file.path,
            );
          }

          await file.rename(finalPath);
        } catch (e) {
          await sink?.close();
          // Preserve .tmp for resume on incomplete downloads
          if (e is! IncompleteDownloadException && await file.exists()) {
            try {
              await file.delete();
              _log.info('Deleted incomplete file: ${file.path}');
            } catch (delError) {
              _log.warning('Failed to delete incomplete file: $delError');
            }
          }
          rethrow;
        }

        // Handle zip extraction for regular paths
        if (filename.toLowerCase().endsWith('.zip')) {
          yield DownloadProgressEvent(
            progress: 1.01,
            receivedBytes: totalLength,
            totalBytes: totalLength,
          );
          try {
            await for (final progress in _extractZipStream(finalPath)) {
              if (cancelToken?.isCancelled ?? false)
                throw Exception('Cancelled during extraction');
              yield DownloadProgressEvent(
                progress: 1.0 + progress,
                receivedBytes: totalLength,
                totalBytes: totalLength,
              );
            }
          } catch (e) {
            _log.warning('Extraction failed: $e');
            rethrow;
          }
        }
      }
    } catch (e) {
      if (cancelToken?.isCancelled ?? false) {
        _log.info('Clean cancellation handled');
        throw Exception('Download cancelled');
      }
      rethrow;
    } finally {
      client.close();
    }
  }

  /// Safe mkdirp that handles pre-existing directories gracefully
  Future<dynamic> _safeMkdirp(
    SafUtil safUtil,
    String baseUri,
    List<String> segments,
  ) async {
    try {
      // Try direct creation first (fast path)
      return await safUtil.mkdirp(baseUri, segments);
    } catch (e) {
      // If it fails, fallback to checking existence segment by segment
      if (segments.isEmpty) {
        rethrow;
      }

      final currentSegment = segments.first;
      dynamic match;

      try {
        final children = await safUtil.list(baseUri);
        match = children.firstWhere(
          (element) =>
              element.name.toLowerCase() == currentSegment.toLowerCase(),
          orElse: () =>
              throw Exception('Segment not found'), // Trigger outer catch
        );
      } catch (_) {
        // Not found in list, and mkdirp failed? Real error.
        _log.error(
          'mkdirp failed and segment "$currentSegment" not found in $baseUri',
        );
        rethrow;
      }

      // Found the segment!
      if (segments.length == 1) {
        // It was the last one, success!
        return match;
      } else {
        // Recurse for remaining segments
        return _safeMkdirp(safUtil, match.uri, segments.sublist(1));
      }
    }
  }

  /// Download using SAF for Android SD card access
  /// For ZIPs: download to temp, extract, paste to SAF
  Stream<DownloadProgressEvent> _downloadWithSaf(
    Stream<List<int>> responseStream,
    String safDirUri,
    String subFolder,
    String filename,
    int totalLength,
    DownloadCancellationToken? cancelToken,
  ) async* {
    final safStream = SafStream();
    final safUtil = SafUtil();
    int received = 0;
    final bool isZip = filename.toLowerCase().endsWith('.zip');

    try {
      // Create subfolder if it doesn't exist
      final subDirResult = await _safeMkdirp(safUtil, safDirUri, [subFolder]);
      final targetDirUri = subDirResult.uri;

      if (isZip) {
        // === ZIP HANDLING: Download to temp cache, extract, paste to SAF ===
        _log.info('ZIP detected - using temp cache extraction method');

        // Get temp directory for extraction
        final tempDir = await Directory.systemTemp.createTemp('romifleur_zip_');
        final tempZipPath = p.join(tempDir.path, filename);

        try {
          // Download to temp file
          final tempFile = File(tempZipPath);
          final sink = tempFile.openWrite();
          int lastReportedBytes = 0;

          await for (final chunk in responseStream) {
            if (cancelToken?.isCancelled ?? false) {
              await sink.close();
              throw Exception('Download cancelled');
            }
            sink.add(chunk);
            received += chunk.length;

            // Throttle: Update only every 100KB
            if (totalLength > 0 &&
                (received - lastReportedBytes > 1024 * 100 ||
                    received == totalLength)) {
              yield DownloadProgressEvent(
                progress: received / totalLength * 0.8,
                receivedBytes: received,
                totalBytes: totalLength,
              ); // 0-80%
              lastReportedBytes = received;
            }
          }
          await sink.close();

          // Verify download completeness
          if (totalLength > 0 && received != totalLength) {
            throw IncompleteDownloadException(
              received: received,
              expected: totalLength,
            );
          }

          _log.info('ZIP downloaded to temp: $tempZipPath');
          yield DownloadProgressEvent(
            progress: 0.8,
            receivedBytes: totalLength,
            totalBytes: totalLength,
          ); // 80% - download complete

          // Extract ZIP locally (Background Isolate with Granular Progress)
          final receivePort = ReceivePort();
          final isolate = await Isolate.spawn(_isolateExtraction, [
            tempZipPath,
            tempDir.path,
            receivePort.sendPort,
          ]);

          // Detect unexpected isolate exit (e.g. OOM on large PS2 ZIPs)
          isolate.addOnExitListener(
            receivePort.sendPort,
            response: '__isolate_exit__',
          );

          try {
            await for (final message in receivePort) {
              if (message == '__isolate_exit__') {
                throw Exception(
                  'Extraction failed: isolate exited unexpectedly (possible out-of-memory)',
                );
              } else if (message is double) {
                // Map extraction progress (0.0-1.0) to overall progress (0.8-0.9)
                yield DownloadProgressEvent(
                  progress: 0.8 + (0.1 * message),
                  receivedBytes: totalLength,
                  totalBytes: totalLength,
                );
              } else if (message == true) {
                break; // Done
              } else if (message is String) {
                throw Exception(message);
              }
            }
          } finally {
            isolate.kill(priority: Isolate.immediate);
            receivePort.close();
          }

          _log.info('ZIP extracted locally');
          yield DownloadProgressEvent(
            progress: 0.9,
            receivedBytes: totalLength,
            totalBytes: totalLength,
          ); // 90% - extraction complete

          // Delete the ZIP file from temp
          await tempFile.delete();

          // Paste all extracted files to SAF
          final extractedFiles = tempDir.listSync(recursive: true);
          int fileIndex = 0;
          final totalFiles = extractedFiles.whereType<File>().length;

          for (final entity in extractedFiles) {
            if (entity is File) {
              final relativePath = p.relative(entity.path, from: tempDir.path);
              // Skip the original zip if it somehow exists
              if (relativePath == filename) continue;

              // Create parent dirs in SAF if needed
              final parentDir = p.dirname(relativePath);
              String destDirUri = targetDirUri;
              if (parentDir != '.' && parentDir.isNotEmpty) {
                final subDirs = parentDir.split(p.separator);
                final parentResult = await _safeMkdirp(
                  safUtil,
                  targetDirUri,
                  subDirs,
                );
                destDirUri = parentResult.uri;
              }

              // Paste file to SAF manually (stream copy) to avoid API issues
              final localFileStream = entity.openRead();
              final copyWriteInfo = await safStream.startWriteStream(
                destDirUri,
                p.basename(entity.path),
                'application/octet-stream',
              );
              final copySessionId = copyWriteInfo.session;

              try {
                final buffer = BytesBuilder(copy: false);
                const int bufferSize = 1024 * 1024; // 1MB buffer

                await for (final chunk in localFileStream) {
                  buffer.add(chunk);
                  if (buffer.length >= bufferSize) {
                    await safStream.writeChunk(
                      copySessionId,
                      buffer.takeBytes(),
                    );
                  }
                }
                if (buffer.isNotEmpty) {
                  await safStream.writeChunk(copySessionId, buffer.takeBytes());
                }
                await safStream.endWriteStream(copySessionId);
              } catch (e) {
                try {
                  await safStream.endWriteStream(copySessionId);
                } catch (_) {}
                rethrow;
              }

              fileIndex++;
              yield DownloadProgressEvent(
                progress: 0.9 + (0.1 * fileIndex / totalFiles),
                receivedBytes: totalLength,
                totalBytes: totalLength,
              ); // 90-100%
            }
          }

          // Cleanup temp directory
          await tempDir.delete(recursive: true);
          _log.info('SAF extraction complete, temp cleaned up');
          yield DownloadProgressEvent(
            progress: 1.0,
            receivedBytes: totalLength,
            totalBytes: totalLength,
          );
        } catch (e) {
          // Cleanup temp on error
          try {
            await tempDir.delete(recursive: true);
          } catch (_) {}
          rethrow;
        }
      } else {
        // === NON-ZIP: Direct streaming to SAF ===
        String? sessionId;

        try {
          // Start write stream
          final writeInfo = await safStream.startWriteStream(
            targetDirUri,
            filename,
            'application/octet-stream',
          );
          sessionId = writeInfo.session;

          _log.debug('SAF write session started: $sessionId');

          // Stream download chunks directly to SAF
          final buffer = BytesBuilder(copy: false);
          const int bufferSize = 1024 * 1024; // 1MB buffer
          int lastReportedBytes = 0;

          // Producer-Consumer Logic to decouple Network (Fast) from Disk (Slow-ish)
          final writeController = StreamController<Uint8List>();
          final writeFuture = (() async {
            try {
              await for (final chunk in writeController.stream) {
                await safStream.writeChunk(sessionId!, chunk);
              }
            } catch (e) {
              // If write fails, we should probably propagate?
              // For now, caller will handle main error, this just stops writing.
              _log.error('SAF Async Write Error: $e');
              rethrow;
            }
          })();

          try {
            await for (final chunk in responseStream) {
              if (cancelToken?.isCancelled ?? false) {
                throw Exception('Download cancelled');
              }

              buffer.add(chunk);
              received += chunk.length;

              if (buffer.length >= bufferSize) {
                writeController.add(buffer.takeBytes());
              }

              // Throttle: Update only every 100KB
              if (totalLength > 0 &&
                  (received - lastReportedBytes > 1024 * 100 ||
                      received == totalLength)) {
                yield DownloadProgressEvent(
                  progress: received / totalLength,
                  receivedBytes: received,
                  totalBytes: totalLength,
                );
                lastReportedBytes = received;
              }
            }

            // Verify download completeness
            if (totalLength > 0 && received != totalLength) {
              throw IncompleteDownloadException(
                received: received,
                expected: totalLength,
              );
            }

            if (buffer.isNotEmpty) {
              writeController.add(buffer.takeBytes());
            }
          } catch (e) {
            await writeController.close();
            try {
              await writeFuture;
            } catch (_) {} // Drain pending writes before cleanup
            rethrow;
          }

          // End write stream
          await writeController.close();
          await writeFuture; // Wait for pending writes to finish

          await safStream.endWriteStream(sessionId);
          sessionId = null;

          _log.info('SAF download complete: $filename');
          yield DownloadProgressEvent(
            progress: 1.0,
            receivedBytes: totalLength,
            totalBytes: totalLength,
          );
        } catch (e) {
          // Try to clean up session if it was started
          if (sessionId != null) {
            try {
              await safStream.endWriteStream(sessionId);
            } catch (_) {}
          }
          rethrow;
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  Stream<double> _extractZipStream(String zipPath) async* {
    final receivePort = ReceivePort();
    Isolate? isolate;

    try {
      final dir = p.dirname(zipPath);

      // Spawn the isolation
      isolate = await Isolate.spawn(_isolateExtraction, [
        zipPath,
        dir,
        receivePort.sendPort,
      ]);

      // Detect unexpected isolate exit (e.g. OOM on large ZIPs)
      isolate.addOnExitListener(
        receivePort.sendPort,
        response: '__isolate_exit__',
      );

      // Listen for progress messages
      await for (final message in receivePort) {
        if (message == '__isolate_exit__') {
          throw Exception(
            'Extraction failed: isolate exited unexpectedly (possible out-of-memory)',
          );
        } else if (message is double) {
          yield message; // 0.0 to 1.0
        } else if (message == true) {
          break; // Done
        } else if (message is String) {
          throw Exception(message); // Error from isolate
        }
      }

      // Kill isolate to release file locks on Windows
      isolate.kill(priority: Isolate.immediate);
      isolate = null;

      // Delete zip after successful extraction
      await File(zipPath).delete();
    } catch (e) {
      _log.error('Extraction failed: $e');
      rethrow;
    } finally {
      isolate?.kill(priority: Isolate.immediate);
      receivePort.close();
    }
  }
}
