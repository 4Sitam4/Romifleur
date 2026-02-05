import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';
import 'package:romifleur/services/config_service.dart';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:romifleur/models/rom.dart';
import 'package:romifleur/utils/cancellation_token.dart';
import 'package:saf_stream/saf_stream.dart';
import 'package:saf_util/saf_util.dart';

// Top-level isolated function for background extraction
// Top-level isolated function for background extraction with progress
// Top-level isolated function for background extraction with byte-level progress
void _isolateExtraction(List<dynamic> args) {
  final String zipPath = args[0];
  final String destPath = args[1];
  final SendPort sendPort = args[2];

  try {
    final inputStream = InputFileStream(zipPath);
    final archive = ZipDecoder().decodeBuffer(inputStream);
    
    // Calculate total size
    int totalBytes = 0;
    for (var file in archive.files) {
      if (file.isFile) totalBytes += file.size;
    }

    int processedBytes = 0;
    int lastUpdateTicks = 0;

    for (var file in archive.files) {
      if (file.isFile) {
        final outputStream = OutputFileStream(p.join(destPath, file.name));
        
        dynamic content = file.content;

        if (content is InputStreamBase) { // Use InputStreamBase to be safe
           const chunkSize = 1024 * 1024; // 1MB chunk
           
           while (!content.isEOS) {
             final int remaining = content.length - content.position;
             final int len = remaining < chunkSize ? remaining : chunkSize;
             if (len <= 0) break;
             
             final bytes = content.readBytes(len).toUint8List();
             outputStream.writeBytes(bytes);
             
             processedBytes += len;
             
             final now = DateTime.now().millisecondsSinceEpoch;
             
             // Throttle events (100ms)
             if (now - lastUpdateTicks > 100) {
               sendPort.send(processedBytes / totalBytes);
               lastUpdateTicks = now;
             }
           }
        } else if (content is List<int>) {
           // Write RAM buffer in chunks to avoid blocking I/O and allow progress
           const chunkSize = 1024 * 1024; // 1MB
           int position = 0;
           
           while (position < content.length) {
             final int remaining = content.length - position;
             final int len = remaining < chunkSize ? remaining : chunkSize;
             
             final chunk = content is Uint8List 
                 ? content.sublist(position, position + len)
                 : content.sublist(position, position + len) as List<int>;
                 
             outputStream.writeBytes(chunk);
             
             position += len;
             
             final now = DateTime.now().millisecondsSinceEpoch;
             if (now - lastUpdateTicks > 100) {
               sendPort.send(processedBytes / totalBytes);
               lastUpdateTicks = now;
             }
           }
        } else {
           file.writeContent(outputStream);
           processedBytes += file.size;
        }
        outputStream.close();
      } else {
        Directory(p.join(destPath, file.name)).createSync(recursive: true);
      }
    }
    
    inputStream.close();
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

class RomService {
  final ConfigService _configService = ConfigService();
  final Map<String, List<RomModel>> _cache = {};

  Future<List<RomModel>> fetchFileList(
    String category,
    String consoleKey, {
    bool forceReload = false,
  }) async {
    final cacheKey = '${category}_$consoleKey';
    if (!forceReload && _cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    final config = _configService.getConsoleConfig(category, consoleKey);
    if (config == null) throw Exception('Console config not found');

    final String url = config['url'];
    final List<dynamic> exts = config['exts'];
    final validExts = exts.map((e) => e.toString().toLowerCase()).toList();

    try {
      print('🌐 Fetching ROM list from: $url');
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

      _cache[cacheKey] = roms;
      return roms;
    } catch (e) {
      print('❌ Error fetching file list: $e');
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
  }) async* {
    final config = _configService.getConsoleConfig(category, consoleKey);
    if (config == null) throw Exception('Config error');

    String baseUrl = config['url'];
    if (!baseUrl.endsWith('/')) baseUrl += '/';
    final encodedName = Uri.encodeComponent(filename).replaceAll('+', '%20');
    final downloadUrl = '$baseUrl$encodedName';

    // Check if we're using SAF (content:// URI)
    final bool useSaf = _configService.isSafUri(saveDir);

    print('⬇️ Downloading: $downloadUrl');
    print('📂 Save dir: $saveDir (SAF: $useSaf)');

    final client = http.Client();

    // Register cancellation
    cancelToken?.onCancel(() {
      print('🚫 Download cancelled: $filename');
      client.close();
    });

    try {
      final request = http.Request('GET', Uri.parse(downloadUrl));
      request.headers.addAll({
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
        'Referer': baseUrl,
      });

      final response = await client.send(request);
      final totalLength = response.contentLength ?? 0;
      int received = 0;

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
          sink = file.openWrite();

          await for (final chunk in response.stream) {
            if (cancelToken?.isCancelled ?? false) {
              throw Exception('Download cancelled');
            }
            sink.add(chunk);
            received += chunk.length;
            if (totalLength > 0)
              yield DownloadProgressEvent(
                progress: received / totalLength,
                receivedBytes: received,
                totalBytes: totalLength,
              );
          }
          await sink.close();
          sink = null;

          await file.rename(finalPath);
        } catch (e) {
          await sink?.close();
          if (await file.exists()) {
            try {
              await file.delete();
              print('🗑️ Deleted incomplete file: ${file.path}');
            } catch (delError) {
              print('⚠️ Failed to delete incomplete file: $delError');
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
            print('⚠️ Extraction failed: $e');
          }
        }
      }
    } catch (e) {
      if (cancelToken?.isCancelled ?? false) {
        print('✅ Clean cancellation handled');
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
          orElse:
              () => throw Exception('Segment not found'), // Trigger outer catch
        );
      } catch (_) {
        // Not found in list, and mkdirp failed? Real error.
        print(
          '❌ mkdirp failed and segment "$currentSegment" not found in $baseUri',
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
        print('📦 ZIP detected - using temp cache extraction method');

        // Get temp directory for extraction
        final tempDir = await Directory.systemTemp.createTemp('romifleur_zip_');
        final tempZipPath = p.join(tempDir.path, filename);

        try {
          // Download to temp file
          final tempFile = File(tempZipPath);
          final sink = tempFile.openWrite();

          await for (final chunk in responseStream) {
            if (cancelToken?.isCancelled ?? false) {
              await sink.close();
              throw Exception('Download cancelled');
            }
            sink.add(chunk);
            received += chunk.length;
            if (totalLength > 0)
              yield DownloadProgressEvent(
                progress: received / totalLength * 0.8,
                receivedBytes: received,
                totalBytes: totalLength,
              ); // 0-80%
          }
          await sink.close();

          print('✅ ZIP downloaded to temp: $tempZipPath');
          yield DownloadProgressEvent(
              progress: 0.8,
              receivedBytes: totalLength,
              totalBytes: totalLength); // 80% - download complete

          // Extract ZIP locally (Background Isolate with Granular Progress)
          final receivePort = ReceivePort();
          final isolate = await Isolate.spawn(
            _isolateExtraction,
            [tempZipPath, tempDir.path, receivePort.sendPort],
          );

          try {
            await for (final message in receivePort) {
               if (message is double) {
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

          print('✅ ZIP extracted locally');
          yield DownloadProgressEvent(
              progress: 0.9,
              receivedBytes: totalLength,
              totalBytes: totalLength); // 90% - extraction complete

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
                await for (final chunk in localFileStream) {
                  await safStream.writeChunk(
                    copySessionId,
                    Uint8List.fromList(chunk),
                  );
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
          print('✅ SAF extraction complete, temp cleaned up');
          yield DownloadProgressEvent(
              progress: 1.0,
              receivedBytes: totalLength,
              totalBytes: totalLength);
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

          print('📝 SAF write session started: $sessionId');

          // Stream download chunks directly to SAF
          await for (final chunk in responseStream) {
            if (cancelToken?.isCancelled ?? false) {
              throw Exception('Download cancelled');
            }
            await safStream.writeChunk(sessionId, Uint8List.fromList(chunk));
            received += chunk.length;
            if (totalLength > 0)
              yield DownloadProgressEvent(
                progress: received / totalLength,
                receivedBytes: received,
                totalBytes: totalLength,
              );
          }

          // End write stream
          await safStream.endWriteStream(sessionId);
          sessionId = null;

          print('✅ SAF download complete: $filename');
          yield DownloadProgressEvent(
              progress: 1.0,
              receivedBytes: totalLength,
              totalBytes: totalLength);
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
      isolate = await Isolate.spawn(
        _isolateExtraction,
        [zipPath, dir, receivePort.sendPort],
      );

      // Listen for progress messages
      await for (final message in receivePort) {
        if (message is double) {
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
      print('⚠️ Extraction failed: $e');
      rethrow;
    } finally {
      isolate?.kill(priority: Isolate.immediate);
      receivePort.close();
    }
  }
}
