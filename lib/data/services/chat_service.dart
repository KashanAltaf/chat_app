import 'dart:io';

import 'package:chat_app/modules/chat/model/message.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';


class ChatService extends ChangeNotifier{
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  File? imageFile;

  Future<void> getImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? xFile = await picker.pickImage(
      source: ImageSource.gallery,
    );

    if (xFile != null) {
      imageFile = File(xFile.path);
    }
  }

  Future<void> uploadImage(String receiverId) async {
    if (imageFile == null) return;

    final String currentUserId = _firebaseAuth.currentUser!.uid;
    final String currentUserEmail = _firebaseAuth.currentUser!.email.toString();
    final Timestamp timestamp = Timestamp.now();

    List<String> ids = [currentUserId, receiverId];
    ids.sort();
    String chatRoomId = ids.join("_");

    try {
      final String fileName =
          '${currentUserId}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final Reference storageRef = FirebaseStorage.instance
          .ref()
          .child('chat_images')
          .child(chatRoomId)
          .child(fileName);

      // ✅ IMPORTANT: wait for upload to finish
      final TaskSnapshot snapshot =
      await storageRef.putFile(imageFile!);

      // ✅ Now the object definitely exists
      final String downloadUrl =
      await snapshot.ref.getDownloadURL();

      Message imageMessage = Message(
        senderEmail: currentUserEmail,
        senderId: currentUserId,
        receiverId: receiverId,
        message: downloadUrl,
        timestamp: timestamp,
      );

      await _firestore
          .collection('chat_rooms')
          .doc(chatRoomId)
          .collection('messages')
          .add(imageMessage.toMap());

      imageFile = null;
      notifyListeners();
    } catch (e) {
      debugPrint('Image upload failed: $e');
    }
  }

  //Send message
  Future<void> sendMessage(String receiverId, String message) async {
    //get current user info
    final String currentUserId = _firebaseAuth.currentUser!.uid;
    final String currentUserEmail = _firebaseAuth.currentUser!.email.toString();
    final Timestamp timestamp = Timestamp.now();

    //create a new message
    Message newMessage = Message(
        senderEmail: currentUserEmail,
        senderId: currentUserId,
        receiverId: receiverId,
        message: message,
        timestamp: timestamp
    );
    //construct chat room id from current user id and receiver id (sorted)
    List<String> ids = [currentUserId, receiverId];
    ids.sort();
    String chatRoomId = ids.join("_");

    //add new message to database
    await _firestore
    .collection('chat_rooms')
    .doc(chatRoomId)
    .collection('messages')
    .add(newMessage.toMap());

  }

  //Get messages
  Stream<QuerySnapshot> getMessages(String userId, String otherUserId){
    List<String> ids = [userId, otherUserId];
    ids.sort();
    String chatRoomId = ids.join("_");
    return _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: false).snapshots();
  }


}