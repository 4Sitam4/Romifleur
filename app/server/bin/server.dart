import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_static/shelf_static.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:archive/archive.dart';

// Configuration
const int _port = 8080;
// In Docker, we map volume to /app/data
final String _downloadPath = Platform.environment['DOWNLOAD_PATH'] ?? 'data';
final String _staticPath =
    Platform.environment['STATIC_PATH'] ?? '../build/web';

// Console path mappings storage (persisted to JSON file)
final String _configPath = p.join(_downloadPath, '.romifleur_config.json');
Map<String, String> _consolePaths = {};

void main(List<String> args) async {
  // Load console path mappings
  await _loadConsolePaths();

  final app = Router();

  // API Routes
  app.post('/api/download', _downloadHandler);

  // Folder Management APIs
  app.get('/api/folders', _listFoldersHandler);
  app.post('/api/folders', _createFolderHandler);

  // Console Path Mapping APIs
  app.get('/api/console-paths', _getConsolePathsHandler);
  app.post('/api/console-paths', _setConsolePathHandler);
  app.delete('/api/console-paths/<console>', _deleteConsolePathHandler);

  // ROM Scanning API
  app.get('/api/scan/<console>', _scanHandler);

  // Proxy Routes (for Metadata/RA/Myrient if needed, but we do Server-Side download now)
  app.get('/myrient/<path|.*>', _myrientProxy);
  app.get('/tgdb/<path|.*>', _tgdbProxy);
  app.get('/tgdb-cdn/<path|.*>', _tgdbCdnProxy);
  app.get('/ra/<path|.*>', _raProxy);

  // Static Content (Flutter Web)
  if (!Directory(_staticPath).existsSync()) {
    print('WARNING: Static path $_staticPath not found. Web app wont load.');
  }

  final staticHandler =
      createStaticHandler(_staticPath, defaultDocument: 'index.html');

  final handler = Pipeline()
      .addMiddleware(logRequests())
      .addHandler(Cascade().add(app).add(staticHandler).handler);

  final server = await io.serve(handler, InternetAddress.anyIPv4, _port);
  print('🚀 Server listening on port ${server.port}');
  print('📂 Downloads will be saved to: $_downloadPath');
}

// --- CONSOLE PATH CONFIG ---

Future<void> _loadConsolePaths() async {
  try {
    final file = File(_configPath);
    if (await file.exists()) {
      final content = await file.readAsString();
      final data = json.decode(content) as Map<String, dynamic>;
      _consolePaths = data.map((k, v) => MapEntry(k, v.toString()));
      print('📋 Loaded ${_consolePaths.length} console path mappings');
    }
  } catch (e) {
    print('⚠️ Error loading config: $e');
  }
}

Future<void> _saveConsolePaths() async {
  try {
    final file = File(_configPath);
    await file.writeAsString(json.encode(_consolePaths));
  } catch (e) {
    print('❌ Error saving config: $e');
  }
}

// --- FOLDER MANAGEMENT HANDLERS ---

/// List all folders in the download directory
Future<Response> _listFoldersHandler(Request request) async {
  try {
    final dir = Directory(_downloadPath);
    if (!await dir.exists()) {
      return Response.ok(json.encode([]),
          headers: {'content-type': 'application/json'});
    }

    final folders = <String>[];
    await for (final entity in dir.list()) {
      if (entity is Directory) {
        final name = p.basename(entity.path);
        if (!name.startsWith('.')) {
          folders.add(name);
        }
      }
    }
    folders.sort();

    return Response.ok(json.encode(folders),
        headers: {'content-type': 'application/json'});
  } catch (e) {
    print('❌ Error listing folders: $e');
    return Response.internalServerError(body: 'Error: $e');
  }
}

/// Create a new folder
Future<Response> _createFolderHandler(Request request) async {
  try {
    final payload = await request.readAsString();
    final data = json.decode(payload) as Map<String, dynamic>;
    final name = data['name'] as String?;

    if (name == null || name.isEmpty) {
      return Response(400, body: 'Missing folder name');
    }

    // Sanitize folder name
    final safeName = name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
    final newDir = Directory(p.join(_downloadPath, safeName));

    if (await newDir.exists()) {
      return Response.ok(json.encode({'status': 'exists', 'name': safeName}),
          headers: {'content-type': 'application/json'});
    }

    await newDir.create(recursive: true);
    print('📁 Created folder: $safeName');

    return Response.ok(json.encode({'status': 'created', 'name': safeName}),
        headers: {'content-type': 'application/json'});
  } catch (e) {
    print('❌ Error creating folder: $e');
    return Response.internalServerError(body: 'Error: $e');
  }
}

// --- CONSOLE PATH MAPPING HANDLERS ---

/// Get all console-folder mappings
Future<Response> _getConsolePathsHandler(Request request) async {
  return Response.ok(json.encode(_consolePaths),
      headers: {'content-type': 'application/json'});
}

/// Set a console-folder mapping
Future<Response> _setConsolePathHandler(Request request) async {
  try {
    final payload = await request.readAsString();
    final data = json.decode(payload) as Map<String, dynamic>;
    final console = data['console'] as String?;
    final folder = data['folder'] as String?;

    if (console == null || folder == null) {
      return Response(400, body: 'Missing console or folder');
    }

    _consolePaths[console] = folder;
    await _saveConsolePaths();
    print('🔗 Mapped console "$console" -> folder "$folder"');

    return Response.ok(json.encode({'status': 'ok'}),
        headers: {'content-type': 'application/json'});
  } catch (e) {
    print('❌ Error setting console path: $e');
    return Response.internalServerError(body: 'Error: $e');
  }
}

/// Delete a console-folder mapping
Future<Response> _deleteConsolePathHandler(
    Request request, String console) async {
  _consolePaths.remove(console);
  await _saveConsolePaths();
  print('🗑️ Removed mapping for console "$console"');

  return Response.ok(json.encode({'status': 'ok'}),
      headers: {'content-type': 'application/json'});
}

// --- ROM SCANNING HANDLER ---

/// Scan a console folder for ROMs
Future<Response> _scanHandler(Request request, String console) async {
  try {
    // Use custom mapping if exists, otherwise use console key as folder name
    final folderName = _consolePaths[console] ?? console;
    final scanDir = Directory(p.join(_downloadPath, folderName));

    if (!await scanDir.exists()) {
      return Response.ok(json.encode([]),
          headers: {'content-type': 'application/json'});
    }

    // Common ROM extensions
    final romExtensions = [
      '.zip',
      '.7z',
      '.rar',
      '.nes',
      '.sfc',
      '.smc',
      '.gba',
      '.gbc',
      '.gb',
      '.nds',
      '.3ds',
      '.cia',
      '.n64',
      '.z64',
      '.v64',
      '.iso',
      '.bin',
      '.cue',
      '.chd',
      '.cso',
      '.pbp',
      '.gen',
      '.md',
      '.smd',
      '.gg',
      '.sms',
      '.pce',
      '.sgx',
      '.ngp',
      '.ngc',
      '.a26',
      '.a52',
      '.a78',
      '.lnx',
      '.j64',
      '.jag',
      '.wad',
      '.wbfs',
      '.gcm',
      '.nkit',
      '.xci',
      '.nsp',
    ];

    final files = <String>[];
    await for (final entity in scanDir.list()) {
      if (entity is File) {
        final filename = p.basename(entity.path);
        final ext = p.extension(filename).toLowerCase();
        if (romExtensions.contains(ext)) {
          files.add(filename);
        }
      }
    }

    print('🔍 Scanned "$folderName": found ${files.length} ROMs');

    return Response.ok(json.encode(files),
        headers: {'content-type': 'application/json'});
  } catch (e) {
    print('❌ Error scanning: $e');
    return Response.internalServerError(body: 'Error: $e');
  }
}

// --- DOWNLOAD HANDLER ---

Future<Response> _downloadHandler(Request request) async {
  try {
    final payload = await request.readAsString();
    final data = jsonResize(json.decode(payload));

    final String url = data['url'];
    final String filename = data['filename'];
    final String? console = data['console']; // subfolder

    print('⬇️ Request Download: $filename from $url');

    // Use custom mapping if exists
    String? folderName = console;
    if (console != null && _consolePaths.containsKey(console)) {
      folderName = _consolePaths[console];
    }

    // Create Directory
    var saveDir = Directory(_downloadPath);
    if (folderName != null && folderName.isNotEmpty) {
      saveDir = Directory(p.join(_downloadPath, folderName));
    }
    if (!await saveDir.exists()) {
      await saveDir.create(recursive: true);
    }

    final File file = File(p.join(saveDir.path, filename));

    // Prepare Request
    final headers = <String, String>{};
    if (url.contains('myrient.erista.me')) {
      headers['Referer'] = 'https://myrient.erista.me/';
    }

    // Start Download (Streamed)
    final client = http.Client();
    final requestHttp = http.Request('GET', Uri.parse(url));
    requestHttp.headers.addAll(headers);

    final response = await client.send(requestHttp);

    if (response.statusCode >= 300) {
      return Response.internalServerError(
          body: 'Upstream Error: ${response.statusCode}');
    }

    final sink = file.openWrite();
    await response.stream.pipe(sink);
    await sink.close();
    client.close();

    print('✅ Download Complete: ${file.path}');

    // EXTRACTION LOGIC
    if (filename.toLowerCase().endsWith('.zip')) {
      print('📦 Extracting ${file.path}...');
      try {
        final bytes = await file.readAsBytes();
        final archive = ZipDecoder().decodeBytes(bytes);

        for (final entity in archive) {
          final extractFilename = entity.name;
          if (entity.isFile) {
            final data = entity.content as List<int>;
            final outFile = File(p.join(saveDir.path, extractFilename));
            await outFile.create(recursive: true);
            await outFile.writeAsBytes(data);
            print('  - Extracted: $extractFilename');
          }
        }
        print('✅ Extraction Complete');
        try {
          await file.delete();
          print('🗑️ Archive deleted: ${file.path}');
        } catch (delError) {
          print('⚠️ Failed to delete archive: $delError');
        }
      } catch (e) {
        print('❌ Extraction Failed: $e');
      }
    }

    return Response.ok(json.encode({'status': 'success', 'path': file.path}),
        headers: {'content-type': 'application/json'});
  } catch (e, stack) {
    print('❌ Error: $e\n$stack');
    return Response.internalServerError(body: 'Error: $e');
  }
}

// --- PROXY IMPLEMENTATION ---

Future<Response> _proxyRequest(
    Request request, String targetBaseUrl, String prefix) async {
  try {
    final path = request.url.path.replaceFirst(RegExp('^$prefix/?'), '');
    final query = request.url.query;
    final uri =
        Uri.parse('$targetBaseUrl/$path${query.isNotEmpty ? '?$query' : ''}');

    final headers = Map<String, String>.from(request.headers);
    headers.remove('host');
    headers.remove('accept-encoding');

    if (targetBaseUrl.contains('myrient')) {
      headers['Referer'] = 'https://myrient.erista.me/';
    }

    final response = await http.get(uri, headers: headers);

    final responseHeaders = Map<String, String>.from(response.headers);
    responseHeaders.remove('transfer-encoding');
    responseHeaders.remove('content-encoding');
    responseHeaders.remove('content-length');

    return Response(
      response.statusCode,
      body: response.bodyBytes,
      headers: responseHeaders,
    );
  } catch (e) {
    print('❌ Proxy Error: $e');
    return Response.internalServerError(body: 'Proxy Error: $e');
  }
}

Future<Response> _myrientProxy(Request request) =>
    _proxyRequest(request, 'https://myrient.erista.me', 'myrient');
Future<Response> _tgdbProxy(Request request) =>
    _proxyRequest(request, 'https://api.thegamesdb.net', 'tgdb');
Future<Response> _tgdbCdnProxy(Request request) =>
    _proxyRequest(request, 'https://cdn.thegamesdb.net', 'tgdb-cdn');
Future<Response> _raProxy(Request request) =>
    _proxyRequest(request, 'https://retroachievements.org', 'ra');

// Utils
dynamic jsonResize(dynamic json) => json;
