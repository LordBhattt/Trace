import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static String? _fcmToken;

  /// Initialize Firebase Messaging
  static Future<void> initialize() async {
    try {
      // Request permission (iOS)
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('✅ Notification permission granted');

        // Get FCM token
        _fcmToken = await _messaging.getToken();
        print('📱 FCM Token: $_fcmToken');

        if (_fcmToken != null) {
          // Save token locally
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('fcm_token', _fcmToken!);

          // Send to backend
          await _sendTokenToBackend(_fcmToken!);
        }

        // Listen for token refresh
        _messaging.onTokenRefresh.listen((newToken) async {
          print('🔄 FCM Token refreshed: $newToken');
          _fcmToken = newToken;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('fcm_token', newToken);
          await _sendTokenToBackend(newToken);
        });

        // Setup message handlers
        _setupMessageHandlers();
      } else {
        print('⚠️ Notification permission denied');
      }
    } catch (e) {
      print('❌ Notification initialization error: $e');
    }
  }

  /// Send token to backend
  static Future<void> _sendTokenToBackend(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString('token');

      if (authToken == null || authToken.isEmpty) {
        print('⚠️ No auth token - skipping FCM token upload');
        return;
      }

      final response = await ApiService.updateFCMToken(token);
      if (response['success'] == true) {
        print('✅ FCM token sent to backend');
      }
    } catch (e) {
      print('❌ Error sending FCM token to backend: $e');
    }
  }

  /// Setup message handlers
  static void _setupMessageHandlers() {
    // Foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('📩 Foreground message received');
      print('Title: ${message.notification?.title}');
      print('Body: ${message.notification?.body}');
      print('Data: ${message.data}');

      // You can show in-app notification here
      _handleNotification(message);
    });

    // Background/Terminated - message tap
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('🔔 Notification tapped (background)');
      _handleNotificationTap(message);
    });

    // Check if app was opened from terminated state
    _messaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        print('🔔 Notification tapped (terminated)');
        _handleNotificationTap(message);
      }
    });
  }

  /// Handle notification received in foreground
  static void _handleNotification(RemoteMessage message) {
    // You can use flutter_local_notifications to show banner
    // For now, just log it
    print('Handling notification: ${message.notification?.title}');
  }

  /// Handle notification tap
  static void _handleNotificationTap(RemoteMessage message) {
    final data = message.data;
    final type = data['type'];
    final rideId = data['rideId'];

    print('Notification tap - Type: $type, RideId: $rideId');

    // Navigate based on type
    // You'll need to implement navigation here
    // Example: Navigate to ride detail screen
  }

  /// Get current FCM token
  static String? get fcmToken => _fcmToken;
}
