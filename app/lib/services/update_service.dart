import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:romifleur/utils/logger.dart';

const _log = AppLogger('UpdateService');

class UpdateInfo {
  final String currentVersion;
  final String latestVersion;
  final String changelogDiff;
  final bool hasUpdate;

  UpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.changelogDiff,
    required this.hasUpdate,
  });
}

class UpdateService {
  static const String _changelogUrl =
      "https://raw.githubusercontent.com/4Sitam4/Romifleur/main/CHANGELOG.md";

  /// Checks for updates by comparing local version with remote CHANGELOG.md
  Future<UpdateInfo?> checkForUpdates() async {
    try {
      // 1. Get current version
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      String currentVersion = packageInfo.version;

      // 2. Fetch remote CHANGELOG.md
      final response = await http.get(Uri.parse(_changelogUrl));
      if (response.statusCode != 200) {
        _log.error('Failed to fetch changelog: ${response.statusCode}');
        return null;
      }

      String fullChangelog = response.body;

      // 3. Parse latest version from changelog
      // Looking for the first line like: ## [3.2.2] - 2026-02-03
      final versionRegExp = RegExp(r'## \[(\d+\.\d+\.\d+)\]');
      final match = versionRegExp.firstMatch(fullChangelog);

      if (match == null) return null;
      String latestVersion = match.group(1)!;

      // 4. Compare versions
      if (_isNewer(latestVersion, currentVersion)) {
        // 5. Extract diff
        String diff = _extractChangelogDiff(fullChangelog, currentVersion);
        return UpdateInfo(
          currentVersion: currentVersion,
          latestVersion: latestVersion,
          changelogDiff: diff,
          hasUpdate: true,
        );
      } else {
        return UpdateInfo(
          currentVersion: currentVersion,
          latestVersion: latestVersion,
          changelogDiff: "",
          hasUpdate: false,
        );
      }
    } catch (e) {
      _log.error('Update check failed: $e');
      return null;
    }
  }

  bool _isNewer(String latest, String current) {
    List<int> latestParts = latest.split('.').map(int.parse).toList();
    List<int> currentParts = current.split('.').map(int.parse).toList();

    for (int i = 0; i < latestParts.length; i++) {
      if (i >= currentParts.length) return true;
      if (latestParts[i] > currentParts[i]) return true;
      if (latestParts[i] < currentParts[i]) return false;
    }
    return false;
  }

  String _extractChangelogDiff(String fullChangelog, String currentVersion) {
    final lines = fullChangelog.split('\n');
    final buffer = StringBuffer();
    bool recording = false;

    // Regex to detect version headers: ## [x.y.z]
    final versionHeaderRegex = RegExp(r'^## \[(\d+\.\d+\.\d+)\]');

    for (var line in lines) {
      final match = versionHeaderRegex.firstMatch(line);
      if (match != null) {
        String versionFound = match.group(1)!;

        // If we hit the current version, stop recording
        if (versionFound == currentVersion) {
          break;
        }

        // Must be a newer version, start recording if not already
        recording = true;
      }

      if (recording) {
        buffer.writeln(line);
      }
    }

    return buffer.toString().trim();
  }
}
