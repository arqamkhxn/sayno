import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/application/partner_controller.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Handling background message: ${message.messageId}');
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(ref);
});

class NotificationService {
  final Ref _ref;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  StreamSubscription? _authSubscription;
  StreamSubscription? _notificationsSubscription;
  StreamSubscription? _tokenRefreshSubscription;
  bool _isInitialized = false;

  NotificationService(this._ref);

  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    // 1. Initialize Flutter Local Notifications
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings = InitializationSettings(android: androidSettings);
    await _localNotifications.initialize(initSettings);

    // Create high importance channel
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'sayno_alerts_channel',
      'SayNO Alerts',
      description: 'High priority alerts for SayNO partner and bypass protection',
      importance: Importance.max,
      playSound: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // 2. Initialize Firebase Messaging if initialized
    final isFirebase = _ref.read(firebaseInitializedProvider);
    if (!isFirebase) {
      debugPrint('NotificationService: Firebase not initialized. Skipping FCM setup.');
      return;
    }

    try {
      // Request permission
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      // Register background message handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // Listen to foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final notification = message.notification;
        if (notification != null) {
          showLocalNotification(notification.title ?? 'SayNO Alert', notification.body ?? '');
        }
      });

      // Listen to token refresh
      _tokenRefreshSubscription = FirebaseMessaging.instance.onTokenRefresh.listen((token) {
        _registerToken(token);
      });

      // Register initial token on auth state change
      _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
        if (user != null) {
          _registerInitialToken();
          _startNotificationsListener(user.uid);
        } else {
          _stopNotificationsListener();
        }
      });

      // If user is already logged in, run initial token registration and notifications listener
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        _registerInitialToken();
        _startNotificationsListener(currentUser.uid);
      }
    } catch (e) {
      debugPrint('Error setting up Firebase Messaging: $e');
    }
  }

  Future<void> _registerInitialToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _registerToken(token);
      }
    } catch (e) {
      debugPrint('Error getting initial FCM token: $e');
    }
  }

  Future<void> _registerToken(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('tokens')
          .doc(token)
          .set({
        'fcmToken': token,
        'deviceModel': defaultTargetPlatform.name,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      });
      debugPrint('Registered FCM token for user: ${user.uid}');
    } catch (e) {
      debugPrint('Error registering FCM token: $e');
    }
  }

  void _startNotificationsListener(String userId) {
    _notificationsSubscription?.cancel();
    
    // Listen to the `/notifications` collection for messages sent to this user
    _notificationsSubscription = FirebaseFirestore.instance
        .collection('notifications')
        .where('toUserId', isEqualTo: userId)
        .snapshots()
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          if (data != null) {
            final title = data['title'] as String? ?? 'SayNO Alert';
            final body = data['body'] as String? ?? '';
            final createdAtStr = data['createdAt'] as String?;
            if (createdAtStr != null) {
              final createdAt = DateTime.parse(createdAtStr).toUtc();
              final difference = DateTime.now().toUtc().difference(createdAt);
              // Only display if the notification was sent in the last 2 minutes
              if (difference.inSeconds.abs() < 120) {
                showLocalNotification(title, body);
              }
            }
          }
        }
      }
    }, onError: (e) {
      debugPrint('Error listening to notifications: $e');
    });
  }

  void _stopNotificationsListener() {
    _notificationsSubscription?.cancel();
    _notificationsSubscription = null;
  }

  Future<void> showLocalNotification(String title, String body) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'sayno_alerts_channel',
      'SayNO Alerts',
      channelDescription: 'High priority alerts for SayNO partner and bypass protection',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(android: androidDetails);
    await _localNotifications.show(
      DateTime.now().millisecond + (title.hashCode % 100000),
      title,
      body,
      notificationDetails,
    );
  }

  Future<void> sendNotificationToPartner({
    required String title,
    required String body,
  }) async {
    final isFirebase = _ref.read(firebaseInitializedProvider);
    if (!isFirebase) {
      debugPrint('NotificationService: Firebase not initialized. Skipping send.');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('NotificationService: User not authenticated. Skipping send.');
      return;
    }

    // Refresh partnership to ensure we have the latest partner UID
    await _ref.read(partnerControllerProvider.notifier).loadPartnership();

    final partner = _ref.read(partnerControllerProvider).partnership;
    if (partner == null || partner.partnerUid == null) {
      debugPrint('NotificationService: No active partner UID linked. Skipping send.');
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('notifications').add({
        'toUserId': partner.partnerUid,
        'fromUserId': user.uid,
        'title': title,
        'body': body,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
        'read': false,
      });
      debugPrint('Notification sent to partner: ${partner.partnerUid}');
    } catch (e) {
      debugPrint('Error sending notification to partner: $e');
    }
  }

  void dispose() {
    _authSubscription?.cancel();
    _notificationsSubscription?.cancel();
    _tokenRefreshSubscription?.cancel();
  }
}
