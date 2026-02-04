import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';
import 'package:romifleur/services/config_service.dart';
import 'package:romifleur/utils/cancellation_token.dart';
import 'package:romifleur/models/rom.dart';

// NOTE: Creating specific Logic for Web
// - No dart:io
// - No direct File System access
// - Downloads are triggered via Browser

class RomService {
  final ConfigService _configService = ConfigService();
  final Map<String, List<RomModel>> _cache = {};

  // Same logic as Native, just uses http package which works on Web too
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

    // CORS PROXY MIGHT BE NEEDED HERE FOR WEB
    String url = config['url'];

    // Rewriting URL to use local Nginx proxy for Myrient
    if (url.contains('myrient.erista.me')) {
      url = url.replaceFirst('https://myrient.erista.me', '/myrient');
    }

    final List<dynamic> exts = config['exts'];
    final validExts = exts.map((e) => e.toString().toLowerCase()).toList();

    try {
      print('🌐 WEB Fetching ROM list from: $url');
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
      if (activeRegions.isNotEmpty) {
        bool regionMatch = activeRegions.any((r) => filename.contains('($r)'));
        if (!regionMatch) continue;
      }

      // 3. Language filter (if any languages are selected)
      if (activeLanguages.isNotEmpty) {
        bool languageMatch = false;
        for (var lang in activeLanguages) {
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

  Stream<double> downloadFile(
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

    // Generate simple ID for cancellation
    final downloadId =
        '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}';

    // Register cancellation
    cancelToken?.onCancel(() async {
      print('🚫 WEB Cancelling download: $downloadId');
      try {
        await http.post(
          Uri.parse('/api/cancel'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'id': downloadId}),
        );
      } catch (e) {
        print('⚠️ Failed to send cancel request: $e');
      }
    });

    final encodedName = Uri.encodeComponent(filename).replaceAll('+', '%20');
    final finalUrl = '$baseUrl$encodedName';

    print(
      '⬇️ WEB Triggering Server-Side Download: $finalUrl (ID: $downloadId)',
    );

    // Call Backend API
    try {
      final response = await http.post(
        Uri.parse('/api/download'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'id': downloadId,
          'url': finalUrl,
          'filename': filename,
          'console': consoleKey, // Use key as subfolder
        }),
      );

      if (cancelToken?.isCancelled ?? false) {
        throw Exception('Download cancelled');
      }

      if (response.statusCode == 200) {
        print('✅ Server accepted download');
        yield 1.0;
        yield 2.0; // Done
      } else {
        throw Exception(
          'Server failed: ${response.statusCode} ${response.body}',
        );
      }
    } catch (e) {
      if (cancelToken?.isCancelled ?? false) {
        throw Exception('Download cancelled');
      }
      print('❌ Download failed: $e');
      throw Exception('Network Error: $e');
    }
  }
}
