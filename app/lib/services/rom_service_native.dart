import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';
import 'package:romifleur/services/config_service.dart';
import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:romifleur/models/rom.dart';

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

  Stream<double> downloadFile(
    String category,
    String consoleKey,
    String filename, {
    required String saveDir,
  }) async* {
    final config = _configService.getConsoleConfig(category, consoleKey);
    if (config == null) throw Exception('Config error');

    String baseUrl = config['url'];
    if (!baseUrl.endsWith('/')) baseUrl += '/';
    final encodedName = Uri.encodeComponent(filename).replaceAll('+', '%20');
    final downloadUrl = '$baseUrl$encodedName';
    final finalPath = p.join(saveDir, config['folder'] ?? consoleKey, filename);

    await Directory(p.dirname(finalPath)).create(recursive: true);

    if (await File(finalPath).exists()) {
      yield 1.0;
      return;
    }

    print('⬇️ Downloading: $downloadUrl to $finalPath');
    final request = http.Request('GET', Uri.parse(downloadUrl));
    request.headers.addAll({
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
      'Referer': baseUrl,
    });
    final response = await request.send();
    final totalLength = response.contentLength ?? 0;
    int received = 0;

    final file = File(finalPath + '.tmp');
    final sink = file.openWrite();

    await for (final chunk in response.stream) {
      sink.add(chunk);
      received += chunk.length;
      if (totalLength > 0) yield received / totalLength;
    }
    await sink.close();
    await file.rename(finalPath);

    if (filename.toLowerCase().endsWith('.zip')) {
      yield 1.01;
      try {
        await for (final progress in _extractZipStream(finalPath)) {
          yield 1.0 + progress;
        }
      } catch (e) {
        print('❌ Extraction stream error: $e');
        rethrow;
      }
    }
    yield 2.0;
  }

  Stream<double> _extractZipStream(String zipPath) async* {
    try {
      final dir = p.dirname(zipPath);
      final inputStream = InputFileStream(zipPath);
      final archive = ZipDecoder().decodeBuffer(inputStream);
      final totalFiles = archive.files.where((f) => f.isFile).length;
      int processed = 0;

      for (var file in archive.files) {
        if (file.isFile) {
          final filePath = p.join(dir, file.name);
          Directory(p.dirname(filePath)).createSync(recursive: true);
          final outputStream = OutputFileStream(filePath);
          file.writeContent(outputStream);
          outputStream.close();
          processed++;
          yield processed / totalFiles;
        }
      }
      inputStream.close();
      await File(zipPath).delete();
    } catch (e) {
      print('⚠️ Extraction failed: $e');
      throw e;
    }
  }
}
