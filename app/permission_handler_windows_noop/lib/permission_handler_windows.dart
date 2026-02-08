import 'package:flutter/foundation.dart';
import 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart';

/// No-op implementation of [PermissionHandlerPlatform] for Windows.
///
/// Replaces the real permission_handler_windows plugin which registers a
/// WinRT Geolocator in its C++ constructor, causing Windows to permanently
/// show "your location is being used" even when the app never requests
/// location permission.
/// See: https://github.com/Baseflow/flutter-permission-handler/issues/1289
class PermissionHandlerWindows extends PermissionHandlerPlatform {
  static void registerWith() {
    PermissionHandlerPlatform.instance = PermissionHandlerWindows();
  }

  @override
  Future<PermissionStatus> checkPermissionStatus(Permission permission) async {
    // On Windows desktop, permissions are generally always granted.
    return PermissionStatus.granted;
  }

  @override
  Future<ServiceStatus> checkServiceStatus(Permission permission) async {
    return ServiceStatus.enabled;
  }

  @override
  Future<bool> openAppSettings() async {
    return false;
  }

  @override
  Future<Map<Permission, PermissionStatus>> requestPermissions(
    List<Permission> permissions,
  ) async {
    return {for (final p in permissions) p: PermissionStatus.granted};
  }

  @override
  Future<bool> shouldShowRequestPermissionRationale(
    Permission permission,
  ) async {
    return false;
  }
}
