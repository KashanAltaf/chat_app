import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';

class PresenceHelper {
  static void setupUserPreference(String uid) {
    final db = FirebaseDatabase.instance;
    final userStatusRef = db.ref('status/$uid');
    final connectedRef = db.ref('.info/connected');

    // Listen to connection state
    connectedRef.onValue.listen((event) {
      final connected = event.snapshot.value as bool? ?? false;

      if (connected) {
        // When the user disconnects, set them offline
        userStatusRef.onDisconnect().set({
          'state': 'offline',
          'lastSeen': ServerValue.timestamp,
          'typingTo': '',
        });

        // Immediately set them online
        userStatusRef.set({
          'state': 'online',
          'lastSeen': ServerValue.timestamp,
          'typingTo': '',
        });
      }
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
    final db = FirebaseDatabase.instance;
    final userStatusRef = db.ref('status/$uid');

    userStatusRef.update({'typingTo': typingToUid});
  }

  /// Call this to stop typing
  static void stopTyping(String uid) {
    final db = FirebaseDatabase.instance;
    final userStatusRef = db.ref('status/$uid');

    userStatusRef.update({'typingTo': ''});
  }
}
