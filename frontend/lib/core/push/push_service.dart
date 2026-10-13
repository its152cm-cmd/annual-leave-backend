import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../routing and navigation/app_router.dart';
import 'firebase_config.dart';

/// Lets the app show a message from anywhere (used for notifications that arrive while the app is open).
final GlobalKey<ScaffoldMessengerState> rootMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Push notifications with Firebase Cloud Messaging.
/// Everything here is optional: without Firebase settings (see firebase_config.dart) it does nothing.
class PushService {
  static bool _listening = false;
  static String? _token;

  /// 'unavailable' (Firebase not set up), 'granted', 'denied' or 'default' (not asked yet).
  static Future<String> permissionState() async {
    if (!FirebaseConfig.isConfigured) return 'unavailable';
    try {
      await _ensureFirebase();
      final s = await FirebaseMessaging.instance.getNotificationSettings();
      return switch (s.authorizationStatus) {
        AuthorizationStatus.authorized || AuthorizationStatus.provisional => 'granted',
        AuthorizationStatus.denied => 'denied',
        _ => 'default',
      };
    } catch (_) {
      return 'unavailable';
    }
  }

  static Future<void> _ensureFirebase() async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: FirebaseConfig.options);
    }
  }

  /// Registers this device for the signed-in person. With [askPermission] the browser asks
  /// "Allow notifications?" if the person has not answered yet.
  static Future<bool> init({bool askPermission = false}) async {
    if (!FirebaseConfig.isConfigured || ApiClient.sessionToken == null) return false;
    try {
      await _ensureFirebase();
      final messaging = FirebaseMessaging.instance;
      var settings = await messaging.getNotificationSettings();
      if (settings.authorizationStatus == AuthorizationStatus.notDetermined && askPermission) {
        settings = await messaging.requestPermission();
      }
      final ok = settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
      if (!ok) return false;
      final token = await messaging.getToken(vapidKey: FirebaseConfig.vapidKey);
      if (token == null || token.isEmpty) return false;
      await _register(token);
      if (!_listening) {
        _listening = true;
        messaging.onTokenRefresh.listen(_register);
        FirebaseMessaging.onMessage.listen(_showInApp);
        FirebaseMessaging.onMessageOpenedApp.listen(_open);
      }
      return true;
    } catch (e) {
      debugPrint('[push] $e');
      return false;
    }
  }

  static Future<void> _register(String token) async {
    _token = token;
    if (ApiClient.sessionToken == null) return;
    try {
      await ApiClient().post('/api/push/token', {'token': token, 'platform': 'web'});
    } catch (e) {
      debugPrint('[push] could not save the device: $e');
    }
  }

  /// Call when signing out: this device stops getting this person's notifications.
  static Future<void> stop() async {
    final token = _token;
    _token = null;
    if (token == null || ApiClient.sessionToken == null) return;
    try {
      await ApiClient().delete('/api/push/token?token=${Uri.encodeQueryComponent(token)}');
    } catch (_) {}
  }

  /// Sends a test notification to this person's devices. Returns how many devices are saved.
  static Future<int> sendTest() async {
    await init(); // make sure this device is saved for the signed-in person
    final r = await ApiClient().post('/api/push/test', {});
    return ((r as Map)['devices'] as num?)?.toInt() ?? 0;
  }

  static void _showInApp(RemoteMessage message) {
    final n = message.notification;
    final title = n?.title ?? message.data['title'] ?? '';
    final body = n?.body ?? message.data['body'] ?? '';
    if (title.isEmpty && body.isEmpty) return;
    final messenger = rootMessengerKey.currentState;
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text([title, body].where((t) => t.isNotEmpty).join('\n')),
        duration: const Duration(seconds: 5),
        action: message.data['groupId'] == null
            ? null
            : SnackBarAction(label: 'Open', onPressed: () => _open(message)),
      ),
    );
  }

  static void _open(RemoteMessage message) {
    final groupId = message.data['groupId'];
    if (groupId is String && groupId.isNotEmpty && message.data['kind'] == 'chat') {
      appRouter.go('/chat/$groupId');
    }
  }
}
