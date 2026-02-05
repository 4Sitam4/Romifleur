import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/ownership_status.dart';

/// Service for scanning local ROM files (Web implementation)
/// Calls server API to scan the mounted volume
class LocalScannerService {
  /// Scans the console folder on the server
  /// [consoleFolder] is the folder name (e.g., "3ds", "n3ds")
  /// Returns a list of filenames
  Future<List<String>> scanLocalRoms(
    String directoryPath,
    List<String> extensions, {
    String? subfolder,
  }) async {
    // Use subfolder if provided, otherwise directoryPath is assumed to be the folder name
    final targetFolder = (subfolder != null && subfolder.isNotEmpty)
        ? subfolder
        : directoryPath;

    try {
      final response = await http.get(Uri.parse('/api/scan/$targetFolder'));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((e) => e.toString()).toList();
      }
    } catch (e) {
      print('❌ Error scanning via API: $e');
    }

    return [];
  }

  /// Extracts the base title from a filename (text before first parenthesis)
  String extractBaseTitle(String filename) {
    final lastDot = filename.lastIndexOf('.');
    String name = lastDot > 0 ? filename.substring(0, lastDot) : filename;

    final parenIndex = name.indexOf('(');
    if (parenIndex > 0) {
      name = name.substring(0, parenIndex);
    }

    return name.trim().toLowerCase();
  }

  /// Checks if a remote ROM is owned locally
  OwnershipStatus checkOwnership(
    String remoteFilename,
    List<String> localFiles,
  ) {
    final remoteWithoutExt = _removeExtension(remoteFilename).toLowerCase();
    final remoteBaseTitle = extractBaseTitle(remoteFilename);

    for (final localFile in localFiles) {
      final localWithoutExt = _removeExtension(localFile).toLowerCase();
      final localBaseTitle = extractBaseTitle(localFile);

      if (remoteWithoutExt == localWithoutExt) {
        return OwnershipStatus.fullMatch;
      }

      if (remoteBaseTitle == localBaseTitle) {
        return OwnershipStatus.partialMatch;
      }
    }

    return OwnershipStatus.notOwned;
  }

  String _removeExtension(String filename) {
    final lastDot = filename.lastIndexOf('.');
    return lastDot > 0 ? filename.substring(0, lastDot) : filename;
  }
}
