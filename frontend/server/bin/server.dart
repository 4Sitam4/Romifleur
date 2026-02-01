import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_static/shelf_static.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:archive/archive.dart';
// import 'package:archive/zip_decoder.dart'; // Included in archive.dart

// Configuration
const int _port = 8080;
// In Docker, we map volume to /app/data
final String _downloadPath = Platform.environment['DOWNLOAD_PATH'] ?? 'data';
final String _staticPath =
    Platform.environment['STATIC_PATH'] ?? '../build/web';

void main(List<String> args) async {
  final app = Router();

  // API Routes
  app.post('/api/download', _downloadHandler);

  // Proxy Routes (for Metadata/RA/Myrient if needed, but we do Server-Side download now)
  // We might still need proxies for Browsing if the frontend fetches lists directly.
  // YES, frontend fetches lists. We need to proxy those too if we replace Nginx.
  app.get('/myrient/<path|.*>', _myrientProxy);
  app.get('/tgdb/<path|.*>', _tgdbProxy);
  app.get('/tgdb-cdn/<path|.*>', _tgdbCdnProxy);
  app.get('/ra/<path|.*>', _raProxy);

  // Static Content (Flutter Web)
  // Check if build directory exists
  if (!Directory(_staticPath).existsSync()) {
    print('WARNING: Static path $_staticPath not found. Web app wont load.');
  }

  // Fallback to index.html for SPA routing
  final staticHandler =
      createStaticHandler(_staticPath, defaultDocument: 'index.html');

  final handler = Pipeline()
      .addMiddleware(logRequests())
      .addHandler(Cascade().add(app).add(staticHandler).handler);

  final server = await io.serve(handler, InternetAddress.anyIPv4, _port);
  print('🚀 Server listening on port ${server.port}');
  print('📂 Downloads will be saved to: $_downloadPath');
}

// --- API IMPLEMENTATION ---

Future<Response> _downloadHandler(Request request) async {
  try {
    final payload = await request.readAsString();
    final data = jsonResize(json.decode(payload));

    final String url = data['url'];
    final String filename = data['filename'];
    final String? console = data['console']; // subfolder

    print('⬇️ Request Download: $filename from $url');

    // Create Directory
    var saveDir = Directory(_downloadPath);
    if (console != null && console.isNotEmpty) {
      saveDir = Directory(p.join(_downloadPath, console));
    }
    if (!await saveDir.exists()) {
      await saveDir.create(recursive: true);
    }

    final File file = File(p.join(saveDir.path, filename));

    // Check if already exists? (Optional, skipping for now to allow retry)
    // if (await file.exists()) return Response.ok('Skipped (Exists)');

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
        // Optional: Delete zip?
        // await file.delete();
      } catch (e) {
        print('❌ Extraction Failed: $e');
        // Don't fail the request, just log it. A corrupt zip is still a download.
      }
    }

    return Response.ok(json.encode({'status': 'success', 'path': file.path}),
        headers: {'content-type': 'application/json'});
  } catch (e, stack) {
    print('❌ Error: $e\n$stack');
    return Response.internalServerError(body: 'Error: $e');
  }
}

// --- PROXY IMPLEMENTATION (Replacing Nginx) ---

// Helper to pipe response
Future<Response> _proxyRequest(
    Request request, String targetBaseUrl, String prefix) async {
  try {
    final path = request.url.path.replaceFirst(RegExp('^$prefix/?'), '');
    final query = request.url.query;
    final uri =
        Uri.parse('$targetBaseUrl/$path${query.isNotEmpty ? '?$query' : ''}');

    print('🔗 Proxy: ${request.url.path} -> $uri');

    final headers = Map<String, String>.from(request.headers);
    headers.remove('host'); // Let http client set host
    headers.remove('accept-encoding'); // Let http client handle compression

    // Spoof Referer for Myrient
    if (targetBaseUrl.contains('myrient')) {
      headers['Referer'] = 'https://myrient.erista.me/';
    }

    final response = await http.get(uri, headers: headers);

    // Filter headers to prevent encoding issues based on client capabilities vs pure proxy
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
dynamic jsonResize(dynamic json) => json; // shim
