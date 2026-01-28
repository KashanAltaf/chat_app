import 'dart:async';
import 'dart:convert';

import 'package:chat_app/modules/chat/screen/chat_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  final _firestore = FirebaseFirestore.instance;

  final _androidChannel = const AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notification',
    description: 'This channel is used for important notifications.',
    importance: Importance.high,
  );

  final _localNotifications = FlutterLocalNotificationsPlugin();
  bool _localNotificationsInitialized = false;
  
  // Track current chat room to avoid showing notifications for active chat
  String? _currentChatRoomId;
  StreamSubscription<QuerySnapshot>? _messagesListener;
  final Map<String, String> _lastMessageId = {}; // Track last seen message per chat room
  
  /// Set the current chat room ID (call this when user opens a chat)
  void setCurrentChatRoom(String? chatRoomId) {
    _currentChatRoomId = chatRoomId;
    if (kDebugMode) {
      print('📱 Current chat room set to: $chatRoomId');
    }
  }
  
  /// Restart the Firestore message listener (call after login)
  void restartMessageListener() {
    if (kDebugMode) {
      print('🔄 Restarting Firestore message listener');
    }
    _startFirestoreMessageListener();
  }

  Future<void> handleMessage(RemoteMessage? message) async {
    if(message == null) return;

    // Extract senderId from notification data or payload
    String? senderId;
    
    // Check if data contains senderId (from FCM data payload)
    if (message.data.containsKey('senderId')) {
      senderId = message.data['senderId'] as String?;
    }
    
    // If not in data, try to parse from payload (for local notifications)
    if (senderId == null && message.data.containsKey('payload')) {
      try {
        final payloadData = jsonDecode(message.data['payload'] as String);
        if (payloadData is Map && payloadData.containsKey('senderId')) {
          senderId = payloadData['senderId'] as String?;
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error parsing payload: $e');
        }
      }
    }
    
    // If still no senderId, return early
    if (senderId == null || senderId.isEmpty) {
      if (kDebugMode) {
        print('⚠️ No senderId found in notification, cannot navigate to chat');
      }
      return;
    }
    
    // Fetch sender's user details from Firestore
    try {
      final senderDoc = await _firestore.collection('users').doc(senderId).get();
      
      if (!senderDoc.exists) {
        if (kDebugMode) {
          print('⚠️ Sender user not found in Firestore');
        }
        return;
      }
      
      final senderData = senderDoc.data();
      final senderEmail = senderData?['email'] ?? '';
      final senderName = senderData?['name'] ?? senderData?['displayName'] ?? 'Unknown';
      final senderPhoto = senderData?['photoUrl'] ?? senderData?['photoURL'] ?? '';
      
      // Navigate to ChatScreen with sender's information
      Get.toNamed(
        ChatScreen.id,
        arguments: {
          'receiverUserId': senderId,
          'receiverUserEmail': senderEmail,
          'receiverUserName': senderName,
          'receiverUserPhoto': senderPhoto,
        },
      );
      
      if (kDebugMode) {
        print('✅ Navigated to chat screen with sender: $senderName');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching sender details: $e');
      }
    }
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
        onDidReceiveNotificationResponse: (NotificationResponse response) async {
          final payload = response.payload;
          if (payload != null && payload.isNotEmpty) {
            try {
              // Parse the payload JSON
              final payloadData = jsonDecode(payload);
              
              // Create a RemoteMessage-like object with senderId in data
              final messageData = {
                'data': {
                  'senderId': payloadData['senderId'],
                  'chatRoomId': payloadData['chatRoomId'],
                },
              };
              
              final message = RemoteMessage.fromMap(messageData);
              await handleMessage(message);
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
      // Request permissions first
      final permissionStatus = await _firebaseMessaging.requestPermission();
      
      if (kDebugMode) {
        print('📱 Notification permission status: ${permissionStatus.authorizationStatus}');
      }

      // Get FCM token (even if permissions are already granted)
      final fCMToken = await _firebaseMessaging.getToken();

      if (kDebugMode) {
        if (fCMToken != null) {
          print('📱 FCM Token obtained (complete): $fCMToken');
          print('📱 Token length: ${fCMToken.length} characters');
        } else {
          print('📱 FCM Token obtained: null');
        }
      }

      // Save FCM token to Firestore immediately if we have it
      if (fCMToken != null) {
        await _saveFCMTokenToFirestore(fCMToken);
        
        // Retry saving after delays to ensure it's saved even if user document wasn't ready
        Future.delayed(const Duration(seconds: 1), () async {
          await ensureFCMTokenSaved();
        });
        Future.delayed(const Duration(seconds: 3), () async {
          await ensureFCMTokenSaved();
        });
        Future.delayed(const Duration(seconds: 5), () async {
          await ensureFCMTokenSaved();
        });
      } else {
        // If token is null, try again after a delay
        if (kDebugMode) {
          print('⚠️ FCM Token is null, will retry...');
        }
        Future.delayed(const Duration(seconds: 2), () async {
          await ensureFCMTokenSaved();
        });
      }

      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        if (kDebugMode) {
          print('🔄 FCM Token refreshed (complete): $newToken');
          print('🔄 Token length: ${newToken.length} characters');
        }
        _saveFCMTokenToFirestore(newToken);
      });

      initPushNotifications();
      initLocalNotifications();
      
      // Start listening to Firestore messages for notifications
      _startFirestoreMessageListener();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error initializing notifications: $e');
      }
      // Retry after error
      Future.delayed(const Duration(seconds: 3), () async {
        await ensureFCMTokenSaved();
      });
    }
  }
  
  /// Start listening to Firestore messages and show notifications
  void _startFirestoreMessageListener() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (kDebugMode) {
        print('⚠️ User not logged in, cannot start message listener');
      }
      return;
    }
    
    // Cancel existing listener if any
    _messagesListener?.cancel();
    
    if (kDebugMode) {
      print('🔔 Starting Firestore message listener for notifications');
    }
    
    // Listen to all chat rooms where user is a participant
    // We'll listen to chat_rooms collection and filter by chatRoomId containing user's ID
    final userId = user.uid;
    
    // Get all chat rooms - we'll need to query differently
    // Since chatRoomId is formatted as "userId1_userId2" (sorted), we need to find rooms containing current user
    // For now, let's listen to all messages and filter by receiverId
    _messagesListener = _firestore
        .collectionGroup('messages')
        .where('receiverId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .listen(
      (snapshot) {
        if (snapshot.docs.isEmpty) return;
        
        final latestMessage = snapshot.docs.first;
        final messageData = latestMessage.data();
        final messageId = latestMessage.id;
        final senderId = messageData['senderId'] as String?;
        final receiverId = messageData['receiverId'] as String?;
        final message = messageData['message'] as String?;
        final type = messageData['type'] as String? ?? 'text';
        final timestamp = messageData['timestamp'] as Timestamp?;
        
        // Don't notify if message is from current user
        if (senderId == userId) return;
        
        // Don't notify if already seen this message
        final chatRoomId = _getChatRoomId(userId, senderId ?? '');
        if (_lastMessageId[chatRoomId] == messageId) return;
        
        // Don't notify if user is currently viewing this chat
        if (_currentChatRoomId == chatRoomId) {
          _lastMessageId[chatRoomId] = messageId;
          return;
        }
        
        // Mark as seen
        _lastMessageId[chatRoomId] = messageId;
        
        // Get sender name
        _firestore.collection('users').doc(senderId).get().then((senderDoc) {
          final senderData = senderDoc.data();
          final senderName = senderData?['name'] ?? senderData?['displayName'] ?? 'Someone';
          
          // Prepare notification content
          String notificationTitle = 'New message from $senderName';
          String notificationBody = message ?? 'New message';
          
          if (type == 'voice') {
            notificationBody = '🎤 Voice message';
          } else if (type == 'image') {
            notificationBody = '📷 Image';
          } else if (message != null && message.length > 100) {
            notificationBody = message.substring(0, 100) + '...';
          }
          
          // Show local notification
          _showLocalNotification(
            title: notificationTitle,
            body: notificationBody,
            chatRoomId: chatRoomId,
            senderId: senderId ?? '',
          );
          
          if (kDebugMode) {
            print('🔔 Notification shown for message from $senderName');
          }
        }).catchError((error) {
          if (kDebugMode) {
            print('⚠️ Error getting sender info: $error');
          }
          // Show notification anyway with default name
          _showLocalNotification(
            title: 'New message',
            body: message ?? 'New message',
            chatRoomId: chatRoomId,
            senderId: senderId ?? '',
          );
        });
      },
      onError: (error) {
        if (kDebugMode) {
          print('❌ Error in Firestore message listener: $error');
        }
      },
    );
  }
  
  /// Get chat room ID from two user IDs
  String _getChatRoomId(String userId1, String userId2) {
    final ids = [userId1, userId2]..sort();
    return ids.join('_');
  }
  
  /// Show a local notification
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    required String chatRoomId,
    required String senderId,
  }) async {
    if (!_localNotificationsInitialized) {
      if (kDebugMode) {
        print('⚠️ Local notifications not initialized, cannot show notification');
      }
      return;
    }
    
    try {
      await _localNotifications.show(
        chatRoomId.hashCode, // Use chatRoomId hash as notification ID
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _androidChannel.id,
            _androidChannel.name,
            channelDescription: _androidChannel.description,
            icon: '@mipmap/ic_launcher',
            importance: Importance.high,
            priority: Priority.high,
            showWhen: true,
          ),
        ),
        payload: jsonEncode({
          'chatRoomId': chatRoomId,
          'senderId': senderId,
        }),
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error showing local notification: $e');
      }
    }
  }

  Future<void> _saveFCMTokenToFirestore(String? token) async {
    if (token == null || token.isEmpty || token.trim().isEmpty) {
      if (kDebugMode) {
        print('⚠️ FCM Token is null or empty, cannot save');
        print('   Token value: ${token ?? 'null'}');
      }
      return;
    }

    // Validate token format (FCM tokens are typically long strings)
    if (token.length < 10) {
      if (kDebugMode) {
        print('⚠️ FCM Token seems invalid (too short): ${token.length} characters');
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

      final tokenToSave = token.trim();
      
      // Use set with merge: true so it works whether document exists or not
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({'fcmToken': tokenToSave}, SetOptions(merge: true));

      if (kDebugMode) {
        print('✅ FCM Token saved to Firestore for user: ${user.uid}');
        print('📱 Token (complete): $tokenToSave');
        print('📱 Token length: ${tokenToSave.length} characters');
        
        // Verify it was saved
        try {
          final verifyDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
          final savedToken = verifyDoc.data()?['fcmToken'];
          if (savedToken == tokenToSave) {
            print('✅ Token verified in Firestore');
          } else {
            print('⚠️ Token verification failed');
            print('   Expected (complete): $tokenToSave');
            print('   Saved (complete): ${savedToken ?? 'null'}');
          }
        } catch (verifyError) {
          print('⚠️ Could not verify token save: $verifyError');
        }
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('❌ Error saving FCM token: $e');
        print('   Stack trace: $stackTrace');
      }
    }
  }

  /// Ensures FCM token is saved after login or when user comes online
  /// Call this after user logs in or when presence is set to online
  Future<void> ensureFCMTokenSaved() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (kDebugMode) {
          print('⚠️ User is null, cannot ensure FCM token');
        }
        return;
      }

      // Request permissions first (this is idempotent - won't re-prompt if already granted)
      try {
        await _firebaseMessaging.requestPermission();
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Error requesting permissions (may already be granted): $e');
        }
      }

      // Get current token
      final fCMToken = await _firebaseMessaging.getToken();
      
      if (fCMToken != null && fCMToken.isNotEmpty) {
        // Always save the token - don't check if it exists first
        // This ensures the token is saved even if there was a previous failure
        if (kDebugMode) {
          print('💾 Ensuring FCM token is saved for user: ${user.uid}');
          print('💾 FCM Token (complete): $fCMToken');
          print('💾 Token length: ${fCMToken.length} characters');
        }
        await _saveFCMTokenToFirestore(fCMToken);
        
        // Verify it was saved
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        
        final savedToken = doc.data()?['fcmToken'] as String?;
        
        if (savedToken == fCMToken) {
          if (kDebugMode) {
            print('✅ FCM Token verified and saved successfully');
          }
        } else {
          if (kDebugMode) {
            print('⚠️ FCM Token save verification failed, retrying...');
          }
          // Retry once more
          await _saveFCMTokenToFirestore(fCMToken);
        }
      } else {
        if (kDebugMode) {
          print('⚠️ FCM Token is null or empty');
          print('   This might mean:');
          print('   1. Notification permissions not granted');
          print('   2. Google Play Services not available');
          print('   3. Device/emulator issue');
        }
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('❌ Error ensuring FCM token: $e');
        print('   Stack trace: $stackTrace');
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

  /// Push notifications on Spark plan (no Cloud Functions - free tier only)
  /// 
  /// How notifications work:
  /// - Foreground: Firestore StreamBuilder shows messages in real-time (already implemented)
  /// - Background: Firestore listeners trigger local notifications (handled automatically)
  /// - Kill State: Not supported on Spark plan (requires Blaze plan for Cloud Functions)
  /// 
  /// Notifications are handled automatically by Firestore listeners.
  /// When a message is saved to Firestore, the receiver's device detects it and shows notifications.
  /// 
  /// Note: This method is kept for compatibility but does nothing.
  /// Notifications work automatically via Firestore StreamBuilder and listeners.
  @Deprecated('Notifications work automatically via Firestore. This method does nothing.')
  Future<void> sendPushNotification({
    required String receiverUserId,
    required String messageContent,
    required String chatId,
    String? messageType,
  }) async {
    // Notifications are handled automatically by Firestore listeners
    // No action needed - messages saved to Firestore trigger notifications automatically
    if (kDebugMode) {
      print('ℹ️ Notification system (Spark free plan):');
      print('   ✅ Foreground: Handled by Firestore StreamBuilder');
      print('   ✅ Background: Handled by Firestore listeners');
      print('   ⚠️ Kill State: Not supported on Spark plan');
      print('   📝 Message saved to Firestore - notifications work automatically');
    }
  }


}