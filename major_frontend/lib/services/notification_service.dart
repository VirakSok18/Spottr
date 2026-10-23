import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:major_frontend/services/config.dart' as app_config;
import '../screens/social/post_detail_screen.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import '../main.dart'; // To access navigatorKey

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);

  Future<void> initialize() async {
    // Request permissions
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Initialize timezones for local scheduling
    tz.initializeTimeZones();
    final String timeZoneName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timeZoneName));

    // Initialize local notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('ic_notification');
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );
    await _localNotifications.initialize(initializationSettings);

    // Request permissions for Android 13+ (Push + Local)
    if (defaultTargetPlatform == TargetPlatform.android) {
      await _localNotifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
      
      // Specifically for exact alarms in Android 14+
      await _localNotifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()?.requestExactAlarmsPermission();

      // Explicitly create the channel for Gym Bot reminders
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'workout_reminders_v2', 
        'Workout Reminders',
        description: 'Reminders for your workout sessions',
        importance: Importance.max,
        showBadge: true,
      );
      await _localNotifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(channel);
    }

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      showLocalNotification(message);
      getNotifications(); // Refresh count
    });

    // Handle background/terminated clicks
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationClick(message);
    });

    // Check for initial message (if app was terminated)
    RemoteMessage? initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationClick(initialMessage);
    }
  }

  void _handleNotificationClick(RemoteMessage message) {
    print("Notification clicked: ${message.data}");
    final type = message.data['type'];
    final referenceId = message.data['postId'] ?? message.data['referenceId'];

    if ((type == 'like' || type == 'comment') && referenceId != null) {
      try {
        final int postId = int.parse(referenceId.toString());
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (context) => PostDetailScreen(postId: postId),
          ),
        );
      } catch (e) {
        print("Error parsing post ID from FCM: $e");
      }
    }
  }

  Future<void> ensureInitialized() async {
    // Basic initialization for background isolates
  }

  Future<void> showLocalNotification(RemoteMessage message) async {
    final prefs = await SharedPreferences.getInstance();
    final bool pushEnabled = prefs.getBool('notif_push_enabled') ?? true;
    final bool messagesEnabled = prefs.getBool('notif_messages_enabled') ?? true;

    if (!pushEnabled || !messagesEnabled) {
      print("Notification suppressed by user settings");
      return;
    }

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'high_importance_channel',
      'High Importance Notifications',
      importance: Importance.max,
      priority: Priority.high,
      icon: 'ic_notification',
      color: const Color(0xFFB794F6),
    );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    
    await _localNotifications.show(
      message.hashCode,
      message.notification?.title ?? 'New Notification',
      message.notification?.body ?? '',
      platformChannelSpecifics,
    );
  }

  Future<void> updateTokenOnServer(String uid) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      String? fcmToken = await _fcm.getToken();
      if (fcmToken == null) return;

      final token = await user.getIdToken();

      final response = await http.post(
        Uri.parse('${app_config.Config.baseUrl}/api/users/fcm-token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'fcmToken': fcmToken,
        }),
      );

      if (response.statusCode == 200) {
        print('FCM Token updated on server');
      } else {
        print('Failed to update FCM token: ${response.statusCode}');
      }
    } catch (e) {
      print('Error updating FCM token: $e');
    }
  }

  Future<List<dynamic>> getNotifications() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];
      final token = await user.getIdToken();

      final response = await http.get(
        Uri.parse('${app_config.Config.baseUrl}/api/notifications'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        List<dynamic> notifications = jsonDecode(response.body);
        unreadCount.value = notifications.where((n) => n['isRead'] == 0 || n['isRead'] == false).length;
        return notifications;
      }
    } catch (e) {
      print('Error fetching notifications: $e');
    }
    return [];
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final token = await user.getIdToken();

      await http.put(
        Uri.parse('${app_config.Config.baseUrl}/api/notifications/$notificationId/read'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );
      getNotifications(); // Refresh
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  Future<void> markAllAsRead() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final token = await user.getIdToken();

      await http.put(
        Uri.parse('${app_config.Config.baseUrl}/api/notifications/read-all'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );
      unreadCount.value = 0;
    } catch (e) {
      print('Error marking all as read: $e');
    }
  }

  Future<bool> deleteNotification(String id) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;
      final token = await user.getIdToken();

      final response = await http.delete(
        Uri.parse('${app_config.Config.baseUrl}/api/notifications/$id'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error deleting notification: $e');
      return false;
    }
  }

  Future<bool> deleteMultipleNotifications(List<String> ids) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;
      final token = await user.getIdToken();

      final response = await http.post(
        Uri.parse('${app_config.Config.baseUrl}/api/notifications/delete-multiple'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'ids': ids.map((id) => int.parse(id)).toList(),
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error deleting multiple notifications: $e');
      return false;
    }
  }

  Future<bool> clearNotifications() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;
      final token = await user.getIdToken();

      final response = await http.delete(
        Uri.parse('${app_config.Config.baseUrl}/api/notifications'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );
      
      if (response.statusCode == 200) {
        unreadCount.value = 0;
        return true;
      }
      return false;
    } catch (e) {
      print('Error clearing notifications: $e');
      return false;
    }
  }

  Future<void> scheduleReminderOnBackend({int delaySeconds = 15}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bool pushEnabled = prefs.getBool('notif_push_enabled') ?? true;
      final bool workoutEnabled = prefs.getBool('notif_workout_enabled') ?? true;

      if (!pushEnabled || !workoutEnabled) return;

      // 1. Schedule LOCALLY (Instant and reliable for Release Mode)
      await _localNotifications.zonedSchedule(
        999, // Unique ID for gym bot reminder
        'Gym Bot 🤖',
        'Hey! Time to crush your workout today! 💪',
        tz.TZDateTime.now(tz.local).add(Duration(seconds: delaySeconds)),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'workout_reminders_v2',
            'Workout Reminders',
            channelDescription: 'Reminders for your workout sessions',
            importance: Importance.max,
            priority: Priority.high,
            icon: 'ic_notification',
            color: Color(0xFFB794F6),
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );

      // 2. Schedule ON BACKEND (Fire and forget, fallback for remote syncing)
      final user = FirebaseAuth.instance.currentUser;
      final token = user != null ? await user.getIdToken() : null;

      final headers = {'Content-Type': 'application/json'};
      if (token != null) headers['Authorization'] = 'Bearer $token';

      // We DON'T await this to prevent blocking the app suspension in release mode
      http.post(
        Uri.parse('${app_config.Config.baseUrl}/api/notifications/schedule-test'),
        headers: headers,
        body: jsonEncode({
          'delaySeconds': delaySeconds,
        }),
      ).timeout(const Duration(seconds: 2)).catchError((_) {});

    } catch (e) {
      print('Error scheduling reminder: $e');
    }
  }

  Future<void> cancelLocalReminder(int id) async {
    await _localNotifications.cancel(id);
  }
}
