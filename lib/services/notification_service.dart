import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../ui/rides/ride_tracking_screen.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  Future<void> init() async {
    if (_isInitialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        _handleNotificationResponse(response);
      },
    );

    _isInitialized = true;
  }

  void _handleNotificationResponse(NotificationResponse response) {
    if (response.payload == 'quick_start' || response.actionId == 'quick_start_action') {
      _navigateToRideTracking();
    }
  }

  void _navigateToRideTracking() {
    final context = navigatorKey.currentContext;
    if (context != null) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const RideTrackingScreen()),
      );
    }
  }

  Future<void> showQuickStartNotification() async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'ridemate_quick_start_channel',
        'Quick Start Ride Tracking',
        channelDescription: 'Persistent notification on device notification bar to launch live ride tracking',
        importance: Importance.high,
        priority: Priority.high,
        ongoing: true,
        autoCancel: false,
        actions: <AndroidNotificationAction>[
          AndroidNotificationAction(
            'quick_start_action',
            'Quick Start Ride',
            showsUserInterface: true,
          ),
        ],
      );

      const iosDetails = DarwinNotificationDetails();

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notificationsPlugin.show(
        888,
        'RideMate Quick Tracker',
        'Tap to start tracking your ride immediately',
        details,
        payload: 'quick_start',
      );
    } catch (_) {}
  }
}
