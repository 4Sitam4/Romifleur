import 'package:flutter_background/flutter_background.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io' show Platform;

class BackgroundService {
  bool _initialized = false;
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static const int _progressNotificationId = 888;
  static const String _channelId = 'romifleur_downloads';

  Future<void> init() async {
    if (_initialized) return;

    // Windows/Linux/macOS do not need this specific background service logic
    // and might crash if we try to invoke Android plugins.
    if (!Platform.isAndroid) {
      _initialized = true;
      return;
    }

    // 1. Config for the sticky foreground service notification (flutter_background)
    final androidConfig = FlutterBackgroundAndroidConfig(
      notificationTitle: 'Romifleur',
      notificationText: 'Background service active',
      notificationIcon: AndroidResource(name: 'ic_launcher', defType: 'mipmap'),
      enableWifiLock: true,
    );

    // 2. Config for local notifications (progress bar)
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _notificationsPlugin.initialize(settings: initializationSettings);

    // Create channel for progress
    final AndroidNotificationChannel channel = const AndroidNotificationChannel(
      _channelId,
      'Downloads',
      description: 'Show download progress',
      importance: Importance.low, // Low = no sound/vibration, good for progress
      showBadge: false,
      playSound: false,
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    try {
      _initialized = await FlutterBackground.initialize(
        androidConfig: androidConfig,
      );
    } catch (e) {
      print('⚠️ Failed to initialize background service: $e');
    }
  }

  Future<void> enableBackgroundExecution() async {
    if (!Platform.isAndroid) return;
    if (!_initialized) await init();
    if (FlutterBackground.isBackgroundExecutionEnabled) return;

    try {
      await FlutterBackground.enableBackgroundExecution();
    } catch (e) {
      print('⚠️ Failed to enable background execution: $e');
    }
  }

  Future<void> disableBackgroundExecution() async {
    if (!Platform.isAndroid) return;

    // Also cancel progress notification when stopping background
    await cancelProgress();

    if (!FlutterBackground.isBackgroundExecutionEnabled) return;

    try {
      await FlutterBackground.disableBackgroundExecution();
    } catch (e) {
      print('⚠️ Failed to disable background execution: $e');
    }
  }

  Future<void> showProgress(
    String title,
    int progress,
    int max, {
    String? subtext,
  }) async {
    if (!Platform.isAndroid || !_initialized) return;

    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          _channelId,
          'Downloads',
          channelDescription: 'Show download progress',
          importance: Importance.low,
          priority: Priority.low,
          onlyAlertOnce: true,
          showProgress: true,
          maxProgress: max,
          progress: progress,
          ongoing: true,
          autoCancel: false,
          subText: subtext,
        );

    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    try {
      await _notificationsPlugin.show(
        id: _progressNotificationId,
        title: 'Downloading...',
        body: '$title (${(progress / max * 100).toInt()}%)',
        notificationDetails: platformChannelSpecifics,
      );
    } catch (e) {
      print('Error showing notification: $e');
    }
  }

  Future<void> cancelProgress() async {
    if (!Platform.isAndroid) return;
    try {
      await _notificationsPlugin.cancel(id: _progressNotificationId);
    } catch (e) {
      print('Error cancelling notification: $e');
    }
  }
}
