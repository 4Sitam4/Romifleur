import 'package:dio/dio.dart';
import '../config/api_config.dart';
import '../models/console.dart';
import '../models/rom.dart';
import '../models/download.dart';

/// API Service for communicating with the Romifleur backend
class ApiService {
  late final Dio _dio;

  ApiService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 60),
      ),
    );
  }

  // ===== CONSOLES =====

  /// Fetch all console categories
  Future<List<CategoryModel>> getConsoles() async {
    try {
      final response = await _dio.get(ApiConfig.consoles);
      final categories = (response.data['categories'] as List)
          .map((c) => CategoryModel.fromJson(c))
          .toList();
      return categories;
    } catch (e) {
      throw Exception('Failed to fetch consoles: $e');
    }
  }

  // ===== ROMS =====

  /// Fetch ROM list for a console
  Future<List<RomModel>> getRoms({
    required String category,
    required String consoleKey,
    String query = '',
    List<String>? regions,
    bool hideDemos = true,
    bool hideBetas = true,
    bool deduplicate = true,
    bool onlyRa = false,
  }) async {
    try {
      final params = <String, dynamic>{
        'q': query,
        'hide_demos': hideDemos,
        'hide_betas': hideBetas,
        'deduplicate': deduplicate,
        'only_ra': onlyRa,
      };
      if (regions != null && regions.isNotEmpty) {
        params['regions'] = regions.join(',');
      }

      final response = await _dio.get(
        ApiConfig.roms(category, consoleKey),
        queryParameters: params,
      );

      final files = (response.data['files'] as List)
          .map((r) => RomModel.fromJson(r))
          .toList();
      return files;
    } catch (e) {
      throw Exception('Failed to fetch ROMs: $e');
    }
  }

  // ===== DOWNLOADS =====

  /// Get download queue
  Future<List<DownloadItem>> getQueue() async {
    try {
      final response = await _dio.get(ApiConfig.downloadQueue);
      final items = (response.data['items'] as List)
          .map((i) => DownloadItem.fromJson(i))
          .toList();
      return items;
    } catch (e) {
      throw Exception('Failed to fetch queue: $e');
    }
  }

  /// Add item to download queue
  Future<bool> addToQueue(DownloadItem item) async {
    try {
      final response = await _dio.post(
        ApiConfig.downloadQueue,
        data: item.toJson(),
      );
      return response.data['success'] ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Add multiple items to queue
  Future<int> addBatchToQueue(List<DownloadItem> items) async {
    try {
      final response = await _dio.post(
        '${ApiConfig.downloadQueue}/batch',
        data: {'items': items.map((i) => i.toJson()).toList()},
      );
      return response.data['added'] ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// Remove item from queue
  Future<bool> removeFromQueue(int index) async {
    try {
      final response = await _dio.delete('${ApiConfig.downloadQueue}/$index');
      return response.data['success'] ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Clear entire queue
  Future<bool> clearQueue() async {
    try {
      await _dio.delete(ApiConfig.downloadQueue);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Start downloading queue
  Future<bool> startDownloads() async {
    try {
      final response = await _dio.post(ApiConfig.downloadStart);
      return response.data['success'] ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Get download progress
  Future<DownloadProgress> getProgress() async {
    try {
      final response = await _dio.get(ApiConfig.downloadProgress);
      return DownloadProgress.fromJson(response.data);
    } catch (e) {
      return const DownloadProgress();
    }
  }

  // ===== SETTINGS =====

  /// Get current settings
  Future<Map<String, dynamic>> getSettings() async {
    try {
      final response = await _dio.get(ApiConfig.settings);
      return response.data;
    } catch (e) {
      throw Exception('Failed to fetch settings: $e');
    }
  }

  /// Update settings
  Future<bool> updateSettings({String? romsPath, String? raApiKey}) async {
    try {
      final data = <String, dynamic>{};
      if (romsPath != null) data['roms_path'] = romsPath;
      if (raApiKey != null) data['ra_api_key'] = raApiKey;

      final response = await _dio.put(ApiConfig.settings, data: data);
      return response.data['success'] ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Validate RA API key
  Future<bool> validateRaKey(String key) async {
    try {
      final response = await _dio.get(ApiConfig.raValidate(key));
      return response.data['valid'] ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>> getMetadata(
    String consoleKey,
    String filename,
  ) async {
    try {
      final response = await _dio.get(ApiConfig.metadata(consoleKey, filename));
      return response.data;
    } catch (e) {
      throw Exception('Failed to load metadata: $e');
    }
  }
}
