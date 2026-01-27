import 'dart:convert';
import 'dart:io';

import 'package:chat_app/modules/chat/model/message.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';


class ChatService extends GetxService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _cloudName = 'dcutscliq';
  static const String _uploadPreset = 'chat_images_unsigned';


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

  Future<void> getImageFromCamera() async {
    final ImagePicker picker = ImagePicker();
    final XFile? xFile = await picker.pickImage(
      source: ImageSource.camera,
    );

    if (xFile != null) {
      imageFile = File(xFile.path);
    }
  }

  Future<void> uploadImage(String receiverId) async {
    if (imageFile == null) return;

    final currentUser = _firebaseAuth.currentUser!;
    final Timestamp timestamp = Timestamp.now();

    List<String> ids = [currentUser.uid, receiverId]..sort();
    final chatRoomId = ids.join('_');

    try {
      /// 🔼 Upload to Cloudinary
      final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$_cloudName/image/upload',
      );

      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = _uploadPreset
        ..fields['folder'] = 'chat_images/$chatRoomId'
        ..files.add(
          await http.MultipartFile.fromPath(
            'file',
            imageFile!.path,
          ),
        );

      final response = await request.send();

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Cloudinary upload failed');
      }

      final resBody =
      jsonDecode(await response.stream.bytesToString());

      final String imageUrl = resBody['secure_url'];

      /// 💬 Save message in Firestore
      final imageMessage = Message(
        senderEmail: currentUser.email!,
        senderId: currentUser.uid,
        receiverId: receiverId,
        message: imageUrl,
        timestamp: timestamp,
      );

      await _firestore
          .collection('chat_rooms')
          .doc(chatRoomId)
          .collection('messages')
          .add(imageMessage.toMap());

      imageFile = null;
    } catch (e) {
      debugPrint('Cloudinary upload error: $e');
    }
  }

  //Send message
  Future<void> sendMessage(String receiverId, String message) async {
    final currentUser = _firebaseAuth.currentUser!;
    final timestamp = Timestamp.now();

    // Create new message
    final newMessage = Message(
      senderEmail: currentUser.email!,
      senderId: currentUser.uid,
      receiverId: receiverId,
      message: message,
      timestamp: timestamp,
    );

    // Construct deterministic chatRoomId
    final ids = [currentUser.uid, receiverId]..sort();
    final chatRoomId = ids.join("_");

    // Add message to Firestore
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

  Future<void> uploadVoice(String receiverId, String filePath, List<double> waveform,) async {
    final currentUser = _firebaseAuth.currentUser!;
    final Timestamp timestamp = Timestamp.now();

    List<String> ids = [currentUser.uid, receiverId]..sort();
    final chatRoomId = ids.join('_');

    try {
      final uri = Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/raw/upload');

      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = _uploadPreset
        ..fields['folder'] = 'chat_audio/$chatRoomId'
        ..files.add(await http.MultipartFile.fromPath(
          'file',
          filePath,
          contentType: http.MediaType.parse(lookupMimeType(filePath) ?? 'audio/aac'),
        ));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Cloudinary upload failed: ${response.statusCode} ${response.body}');
      }

      final resBody = jsonDecode(response.body);
      final String audioUrl = resBody['secure_url'];

      final message = {
        'senderEmail': currentUser.email,
        'senderId': currentUser.uid,
        'receiverId': receiverId,
        'message': audioUrl,
        'timestamp': timestamp,
        'type': 'voice',
        'waveform': waveform,
      };

      await _firestore.collection('chat_rooms').doc(chatRoomId).collection('messages').add(message);
    } catch (e) {
      debugPrint('Cloudinary voice upload error: $e');
      rethrow;
    }
  }

  Future<void> sendMessageWithReply({
    required String receiverId,
    required String message,
    String? replyMessage,
    String? replySenderId,
    String? replyMessageId,
    String? replyType, // 'text' | 'image' | 'voice'
  }) async {
    final currentUser = _firebaseAuth.currentUser!;
    final timestamp = Timestamp.now();

    final ids = [currentUser.uid, receiverId]..sort();
    final chatRoomId = ids.join("_");

    final msgMap = {
      'senderEmail': currentUser.email,
      'senderId': currentUser.uid,
      'receiverId': receiverId,
      'message': message,
      'timestamp': timestamp,
      'type': 'text',
    };

    if (replyMessage != null && replyMessage.isNotEmpty) {
      msgMap['replyTo'] = {
        'message': replyMessage,
        'senderId': replySenderId ?? '',
        'messageId': replyMessageId ?? '',
        'type': replyType ?? 'text',
      };
    }

    await _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .add(msgMap);
  }


}