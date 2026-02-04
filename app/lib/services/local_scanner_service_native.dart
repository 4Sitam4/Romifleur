import 'dart:io';
import 'package:path/path.dart' as p;
import '../models/ownership_status.dart';

/// Service for scanning local ROM files (Native implementation)
class LocalScannerService {
  /// Scans a directory for ROM files with the given extensions
  /// Returns a list of filenames (without paths)
  Future<List<String>> scanLocalRoms(
    String directoryPath,
    List<String> extensions,
  ) async {
    final List<String> foundFiles = [];

    try {
      final dir = Directory(directoryPath);
      if (!await dir.exists()) {
        return [];
      }

      await for (final entity in dir.list(recursive: false)) {
        if (entity is File) {
          final filename = p.basename(entity.path);
          final ext = p.extension(filename).toLowerCase();

          // Check if extension matches (extensions should include the dot)
          if (extensions.any(
            (e) => ext == e.toLowerCase() || ext == '.$e'.toLowerCase(),
          )) {
            foundFiles.add(filename);
          }
        }
      }
    } catch (e) {
      print('❌ Error scanning directory: $e');
    }

    return foundFiles;
  }

  /// Extracts the base title from a filename (text before first parenthesis)
  /// Example: "Super Mario 64 (USA) (Rev 1).n64" -> "super mario 64"
  String extractBaseTitle(String filename) {
    // Remove extension first
    final lastDot = filename.lastIndexOf('.');
    String name = lastDot > 0 ? filename.substring(0, lastDot) : filename;

    // Get text before first parenthesis
    final parenIndex = name.indexOf('(');
    if (parenIndex > 0) {
      name = name.substring(0, parenIndex);
    }

    return name.trim().toLowerCase();
  }

  /// Checks if a remote ROM is owned locally
  /// Returns OwnershipStatus based on match type
  OwnershipStatus checkOwnership(
    String remoteFilename,
    List<String> localFiles,
  ) {
    // Remove extension for comparison
    final remoteWithoutExt = _removeExtension(remoteFilename).toLowerCase();
    final remoteBaseTitle = extractBaseTitle(remoteFilename);

    for (final localFile in localFiles) {
      final localWithoutExt = _removeExtension(localFile).toLowerCase();
      final localBaseTitle = extractBaseTitle(localFile);

      // Full match: exact filename (ignoring extension)
      if (remoteWithoutExt == localWithoutExt) {
        return OwnershipStatus.fullMatch;
      }

      // Partial match: same base title
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
