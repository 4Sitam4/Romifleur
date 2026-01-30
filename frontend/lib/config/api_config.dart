/// API configuration for connecting to the backend
class ApiConfig {
  /// Base URL for the Romifleur backend API
  /// Change this when deploying to production or testing on different devices
  static const String baseUrl = 'http://127.0.0.1:8000';
  
  /// API endpoints
  static const String apiPrefix = '/api';
  
  // Endpoints
  static String get consoles => '$baseUrl$apiPrefix/consoles';
  static String get settings => '$baseUrl$apiPrefix/settings';
  static String get downloads => '$baseUrl$apiPrefix/downloads';
  static String get downloadQueue => '$baseUrl$apiPrefix/downloads/queue';
  static String get downloadProgress => '$baseUrl$apiPrefix/downloads/progress';
  static String get downloadStart => '$baseUrl$apiPrefix/downloads/start';
  static String get downloadWs => 'ws://127.0.0.1:8000$apiPrefix/downloads/ws/progress';
  
  static String roms(String category, String consoleKey) =>
      '$baseUrl$apiPrefix/roms/$category/$consoleKey';
  
  static String metadata(String consoleKey, String filename) =>
      '$baseUrl$apiPrefix/metadata/$consoleKey/$filename';
  
  static String raGames(String consoleKey) =>
      '$baseUrl$apiPrefix/ra/games/$consoleKey';
  
  static String raCheck(String consoleKey, String filename) =>
      '$baseUrl$apiPrefix/ra/check/$consoleKey/$filename';
  
  static String raValidate(String key) =>
      '$baseUrl$apiPrefix/ra/validate?key=$key';
}
