import 'package:chat_app/utils/firebase_api.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

class PresenceHelper {
  static void setupUserPreference(String uid) {
    final db = FirebaseDatabase.instance;
    final userStatusRef = db.ref('status/$uid');
    final connectedRef = db.ref('.info/connected');

    // Listen to connection state
    connectedRef.onValue.listen((event) {
      final connected = event.snapshot.value as bool? ?? false;

      if (connected) {
        try {
          // When the user disconnects, set them offline
          userStatusRef.onDisconnect().set({
            'state': 'offline',
            'lastSeen': ServerValue.timestamp,
            'typingTo': '',
          }).catchError((error) {
            // Log error but don't crash - onDisconnect might fail if rules aren't deployed yet
            debugPrint('⚠️ Failed to set onDisconnect handler: $error');
          });

          // Immediately set them online
          userStatusRef.set({
            'state': 'online',
            'lastSeen': ServerValue.timestamp,
            'typingTo': '',
          }).catchError((error) {
            debugPrint('⚠️ Failed to set online status: $error');
          });
          
          // Ensure FCM token is saved when user comes online
          FirebaseApi().ensureFCMTokenSaved();
        } catch (e) {
          debugPrint('⚠️ Error setting up presence: $e');
        }
      }
    }, onError: (error) {
      debugPrint('⚠️ Error listening to connection state: $error');
    });

    // Listen to presence changes and update Firestore
    userStatusRef.onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;

      if (data != null) {
        FirebaseFirestore.instance.collection('users').doc(uid).update({
          'isOnline': data['state'] == 'online',
          'lastSeen': Timestamp.fromMillisecondsSinceEpoch(
            data['lastSeen'] ?? DateTime.now().millisecondsSinceEpoch,
          ),
          'typingTo': data['typingTo'] ?? '',
        });
      }
    });
  }

  /// Call this to set typing status
  static void setTyping(String uid, String typingToUid) {
    try {
      final db = FirebaseDatabase.instance;
      final userStatusRef = db.ref('status/$uid');

      userStatusRef.update({'typingTo': typingToUid}).catchError((error) {
        debugPrint('⚠️ Failed to set typing status: $error');
      });
    } catch (e) {
      debugPrint('⚠️ Error setting typing status: $e');
    }
  }

  /// Call this to stop typing
  static void stopTyping(String uid) {
    try {
      final db = FirebaseDatabase.instance;
      final userStatusRef = db.ref('status/$uid');

      userStatusRef.update({'typingTo': ''}).catchError((error) {
        debugPrint('⚠️ Failed to stop typing: $error');
      });
    } catch (e) {
      debugPrint('⚠️ Error stopping typing: $e');
    }
  }
}
