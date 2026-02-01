// Export the platform-specific implementation
// The conditional export will choose the correct file at compile time.

export 'config_service_native.dart'
    if (dart.library.html) 'config_service_web.dart';
