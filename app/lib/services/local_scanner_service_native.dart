import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:saf_util/saf_util.dart';
import '../models/ownership_status.dart';

/// Service for scanning local ROM files (Native implementation)
class LocalScannerService {
  /// Scans a directory for ROM files with the given extensions
  /// Returns a list of filenames (without paths)
  Future<List<String>> scanLocalRoms(
    String directoryPath,
    List<String> extensions, {
    String? subfolder,
  }) async {
    final List<String> foundFiles = [];

    try {
      if (directoryPath.startsWith('content://')) {
        // === SAF SCANNING ===
        final safUtil = SafUtil();

        String targetUri = directoryPath;

        // If subfolder is specified, navigate to it
        if (subfolder != null && subfolder.isNotEmpty) {
          try {
            final rootFiles = await safUtil.list(directoryPath);
            // Simple finding by name (assuming unique match)
            final folderMatch = rootFiles.firstWhere(
              (f) => f.name.toLowerCase() == subfolder.toLowerCase(),
            );
            targetUri = folderMatch.uri;
          } catch (e) {
            print(
              '⚠️ Subfolder "$subfolder" not found in root or scan failed: $e',
            );
            return [];
          }
        }

        final files = await safUtil.list(targetUri);

        for (final info in files) {
          final filename = info.name;
          final ext = p.extension(filename).toLowerCase();

          if (extensions.any(
            (e) => ext == e.toLowerCase() || ext == '.$e'.toLowerCase(),
          )) {
            foundFiles.add(filename);
            print('✅ Found local ROM (SAF): $filename');
          }
        }
      } else {
        // === FILE SYSTEM SCANNING ===
        var dirPath = directoryPath;
        if (subfolder != null && subfolder.isNotEmpty) {
          dirPath = p.join(directoryPath, subfolder);
        }

        final dir = Directory(dirPath);
        if (!await dir.exists()) {
          return [];
        }

        await for (final entity in dir.list(recursive: false)) {
          if (entity is File) {
            final filename = p.basename(entity.path);
            final ext = p.extension(filename).toLowerCase();

            if (extensions.any(
              (e) => ext == e.toLowerCase() || ext == '.$e'.toLowerCase(),
            )) {
              foundFiles.add(filename);
            }
          }
        }
      }
    } catch (e) {
      print('❌ Error scanning directory ($directoryPath): $e');
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

    bool hasPartialMatch = false;

    // First pass: Check for full match (prioritized)
    // We can do it in one loop if we track partial match but don't return immediately
    for (final localFile in localFiles) {
      final localWithoutExt = _removeExtension(localFile).toLowerCase();

      // Full match: exact filename (ignoring extension)
      if (remoteWithoutExt == localWithoutExt) {
        return OwnershipStatus.fullMatch;
      }

      // Check for partial match if we haven't found one yet (or just keep scanning)
      // We only care if we found AT LEAST one partial match
      if (!hasPartialMatch) {
        final localBaseTitle = extractBaseTitle(localFile);
        if (remoteBaseTitle == localBaseTitle) {
          hasPartialMatch = true;
        }
      }
    }

    // If we finished the loop, no full match was found.
    // Return partial match if found, otherwise not owned.
    if (hasPartialMatch) {
      return OwnershipStatus.partialMatch;
    }

    return OwnershipStatus.notOwned;
  }

  String _removeExtension(String filename) {
    final lastDot = filename.lastIndexOf('.');
    return lastDot > 0 ? filename.substring(0, lastDot) : filename;
  }
}
