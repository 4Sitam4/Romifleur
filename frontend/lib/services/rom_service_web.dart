import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';
import 'package:romifleur/services/config_service.dart';
import 'package:romifleur/models/rom.dart';

// NOTE: Creating specific Logic for Web
// - No dart:io
// - No direct File System access
// - Downloads are triggered via Browser

class RomService {
  final ConfigService _configService = ConfigService();
  final Map<String, List<RomModel>> _cache = {};
  List<String> _regions = ["Europe", "France", "Fr", "USA", "Japan"];

  void updateFilters({
    List<String>? regions,
    List<String>? exclude,
    bool? deduplicate,
  }) {
    if (regions != null) _regions = regions;
    // if (exclude != null) _exclude = exclude; // Removed unused
    // if (deduplicate != null) _defaultDeduplicate = deduplicate; // Removed unused
  }

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
    bool hideDemos = true,
    bool hideBetas = true,
    bool deduplicate = true,
  }) async {
    var roms = await fetchFileList(category, consoleKey);
    final activeRegions = regions ?? _regions;
    final queryLower = query.toLowerCase();
    List<RomModel> filtered = [];

    for (var rom in roms) {
      if (query.isNotEmpty &&
          !rom.filename.toLowerCase().contains(queryLower)) {
        continue;
      }
      if (activeRegions.isNotEmpty) {
        bool regionMatch = false;
        for (var r in activeRegions) {
          if (rom.filename.contains('($r)') ||
              (r == 'Fr' && rom.filename.contains('(Fr)'))) {
            regionMatch = true;
            break;
          }
        }
        if (!regionMatch && rom.filename.contains('(World)'))
          regionMatch = true;

        if (!regionMatch) continue;
      }
      if (hideDemos &&
          (rom.filename.contains('Demo') || rom.filename.contains('Sample')))
        continue;
      if (hideBetas &&
          (rom.filename.contains('Beta') || rom.filename.contains('Proto')))
        continue;

      filtered.add(rom);
    }
    if (deduplicate) {
      filtered = _performDeduplication(filtered);
    }
    return filtered;
  }

  List<RomModel> _performDeduplication(List<RomModel> list) {
    Map<String, RomModel> bestCandidates = {};
    Map<String, int> bestScores = {};
    for (var rom in list) {
      final base = _getBaseTitle(rom.filename);
      final score = _getScore(rom.filename);
      if (!bestCandidates.containsKey(base) || score > bestScores[base]!) {
        bestCandidates[base] = rom;
        bestScores[base] = score;
      }
    }
    final sorted = bestCandidates.values.toList();
    sorted.sort((a, b) => a.filename.compareTo(b.filename));
    return sorted;
  }

  String _getBaseTitle(String filename) {
    var name = filename;
    final dotIndex = name.lastIndexOf('.');
    if (dotIndex != -1) name = name.substring(0, dotIndex);
    name = name.replaceAll(RegExp(r'\s*\([^)]+\)'), '');
    name = name.replaceAll(RegExp(r'\s*\[[^\]]+\]'), '');
    return name.trim();
  }

  int _getScore(String filename) {
    int score = 0;
    if (filename.contains('(France)') || filename.contains('(Fr)'))
      score += 2;
    else if (filename.contains('(Europe)'))
      score += 1;
    if (filename.contains('Virtual Console')) score -= 50;
    return score;
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

    // REVERT Proxy Rewrite for Myrient Download URL
    // The Backend expects the REAL URL to fetch from, it will handle Referer/Spoofing.
    // However, our fetchFileList used the proxy URL.
    // If we reconstructed it from 'config['url']', it might be the real one.
    // But let's be safe. We need the upstream URL.

    // Actually, `config['url']` is the raw upstream URL.
    // IN `fetchFileList`, we modified the URL *before* fetching the list, but we didn't modify `config['url']` itself.
    // Wait, in `fetchFileList` we did: `String url = config['url']; ... if ... replace`.
    // So the `config` object is untouched.

    // So `baseUrl` calculated here from `config['url']` is the REAL upstream URL (e.g. myrient.erista.me...).
    // So we don't need to rewrite it to `/myrient/` for the *backend*.
    // The backend wants the real "https://..." URL to download from.

    final encodedName = Uri.encodeComponent(filename).replaceAll('+', '%20');
    final finalUrl = '$baseUrl$encodedName';

    print('⬇️ WEB Triggering Server-Side Download: $finalUrl');

    // Call Backend API
    try {
      final response = await http.post(
        Uri.parse('/api/download'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'url': finalUrl,
          'filename': filename,
          'console': consoleKey, // Use key as subfolder
        }),
      );

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
      print('❌ Download failed: $e');
      throw Exception('Network Error: $e');
    }
  }
}
