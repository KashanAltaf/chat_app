import 'dart:convert';

import 'package:chat_app/modules/chat/screen/chat_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';

// Top-level function for background message handler
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kDebugMode) {
    print('Background message received!');
    print('Title: ${message.notification?.title}');
    print('Body: ${message.notification?.body}');
    print('Data: ${message.data}');
  }
}

class FirebaseApi{
  final _firebaseMessaging = FirebaseMessaging.instance;
  final navigatorKey = GlobalKey<NavigatorState>();

  final _androidChannel = const AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notification',
    description: 'This channel is used for important notifications.',
    importance: Importance.high,
  );

  final _localNotifications = FlutterLocalNotificationsPlugin();
  bool _localNotificationsInitialized = false;

  void handleMessage(RemoteMessage? message){
    if(message == null) return;

    navigatorKey.currentState?.pushNamed(
      ChatScreen.id,
      arguments: message,
    );
  }

  Future initLocalNotifications() async {
    // Prevent multiple initializations
    if (_localNotificationsInitialized) {
      if (kDebugMode) {
        print('Local notifications already initialized');
      }
      return;
    }

    try {
      // Use mipmap icon instead of drawable (ic_launcher is in mipmap folders)
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initializationSettings = InitializationSettings(android: androidSettings);

      final initialized = await _localNotifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          final payload = response.payload;
          if (payload != null && payload.isNotEmpty) {
            try {
              final message = RemoteMessage.fromMap(jsonDecode(payload));
              handleMessage(message);
            } catch (e) {
              if (kDebugMode) {
                print('Error parsing notification payload: $e');
              }
            }
          }
        },
      );

      if (initialized == true) {
        _localNotificationsInitialized = true;
        
        // Create notification channel for Android
        final androidPlatform = _localNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        if (androidPlatform != null) {
          try {
            await androidPlatform.createNotificationChannel(_androidChannel);
            if (kDebugMode) {
              print('Notification channel created successfully');
            }
          } catch (e) {
            if (kDebugMode) {
              print('Error creating notification channel: $e');
            }
          }
        }
      } else {
        if (kDebugMode) {
          print('Failed to initialize local notifications');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing local notifications: $e');
      }
      _localNotificationsInitialized = false;
    }
  }


  Future initPushNotifications() async {
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.instance.getInitialMessage().then(handleMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(handleMessage);

    // Register the top-level background message handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification == null) return;
      _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _androidChannel.id,
            _androidChannel.name,
            channelDescription: _androidChannel.description,
            icon: '@mipmap/ic_launcher',
          ),
        ),
        payload: jsonEncode(message.toMap()),
      );
    });
  }


  Future<void> initNotifications() async {
    try {
      await _firebaseMessaging.requestPermission();
      final fCMToken = await _firebaseMessaging.getToken();

      if (kDebugMode) {
        print('📱 FCM Token obtained: ${fCMToken?.substring(0, 20) ?? 'null'}...');
      }

      // Save FCM token to Firestore (with retry if user just logged in)
      if (fCMToken != null) {
        await _saveFCMTokenToFirestore(fCMToken);
        
        // Retry saving after a short delay in case user document wasn't ready
        Future.delayed(const Duration(seconds: 2), () async {
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            // Verify token was saved, retry if needed
            final doc = await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get();
            
            if (!doc.exists || doc.data()?['fcmToken'] == null) {
              if (kDebugMode) {
                print('🔄 Retrying FCM token save...');
              }
              await _saveFCMTokenToFirestore(fCMToken);
            }
          }
        });
      }

      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        if (kDebugMode) {
          print('🔄 FCM Token refreshed: ${newToken.substring(0, 20)}...');
        }
        _saveFCMTokenToFirestore(newToken);
      });

      initPushNotifications();
      initLocalNotifications();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error initializing notifications: $e');
      }
    }
  }

  Future<void> _saveFCMTokenToFirestore(String? token) async {
    if (token == null) {
      if (kDebugMode) {
        print('⚠️ FCM Token is null, cannot save');
      }
      return;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (kDebugMode) {
          print('⚠️ User is null, cannot save FCM token');
        }
        return;
      }

      // Use set with merge: true so it works whether document exists or not
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({'fcmToken': token}, SetOptions(merge: true));

      if (kDebugMode) {
        print('✅ FCM Token saved to Firestore for user: ${user.uid}');
        print('📱 Token: ${token.substring(0, 20)}...');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error saving FCM token: $e');
        print('   Stack trace: ${StackTrace.current}');
      }
    }
  }

  /// Removes the FCM token from Firestore when user logs out
  /// This should only be called on logout
  Future<void> removeFCMTokenFromFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'fcmToken': FieldValue.delete()});

      if (kDebugMode) {
        print('FCM Token removed from Firestore');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error removing FCM token: $e');
      }
    }
  }

  /// Sends a push notification to the receiver using Cloud Functions
  /// This method calls the HTTP callable Cloud Function 'sendPushNotification'
  Future<void> sendPushNotification({
    required String receiverUserId,
    required String messageContent,
    required String chatId,
    String? messageType,
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        if (kDebugMode) {
          print('❌ User not authenticated, cannot send push notification');
        }
        return;
      }

      if (kDebugMode) {
        print('📤 Attempting to send push notification...');
        print('   Receiver: $receiverUserId');
        print('   Message: ${messageContent.substring(0, messageContent.length > 50 ? 50 : messageContent.length)}...');
        print('   ChatId: $chatId');
        
        // Check if receiver has FCM token before attempting to send
        try {
          final receiverDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(receiverUserId)
              .get();
          
          if (!receiverDoc.exists) {
            print('⚠️ Receiver user document does not exist in Firestore');
            return;
          }
          
          final receiverData = receiverDoc.data();
          final receiverToken = receiverData?['fcmToken'];
          
          if (receiverToken == null || receiverToken.isEmpty) {
            print('⚠️ Receiver does not have FCM token saved');
            print('   Receiver data keys: ${receiverData?.keys.toList()}');
            print('   💡 Receiver needs to login and grant notification permissions');
            return;
          } else {
            print('✅ Receiver has FCM token: ${receiverToken.substring(0, 20)}...');
          }
        } catch (e) {
          print('⚠️ Error checking receiver FCM token: $e');
        }
      }

      // Call the Cloud Function HTTP callable
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('sendPushNotification');

      final result = await callable.call({
        'receiverUserId': receiverUserId,
        'messageContent': messageContent,
        'chatId': chatId,
        'messageType': messageType ?? 'chat',
      });

      if (kDebugMode) {
        if (result.data['success'] == true) {
          print('✅ Push notification sent successfully via Cloud Function');
          print('   Response: ${result.data}');
        } else {
          print('⚠️ Push notification response: ${result.data}');
        }
      }
    } on FirebaseFunctionsException catch (e) {
      if (kDebugMode) {
        print('❌ Push notification error: ${e.code} - ${e.message}');
        if (e.details != null) {
          print('   Details: ${e.details}');
        }
        if (e.code == 'not-found') {
          print('   💡 Receiver FCM token not found in Firestore');
          print('   💡 Make sure receiver has logged in and granted notification permissions');
          print('   💡 Check Firestore → users → {receiverId} → fcmToken field exists');
        }
        if (e.code == 'unauthenticated') {
          print('   💡 Make sure you are logged in');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Unexpected error sending push notification: $e');
      }
    }
  }


}