import 'dart:async';
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


  // Upload queue to handle multiple images sequentially
  final List<_PendingUpload> _uploadQueue = [];
  bool _isUploading = false;

  Future<File?> getImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? xFile = await picker.pickImage(
      source: ImageSource.gallery,
    );

    if (xFile != null) {
      return File(xFile.path);
    }
    return null;
  }

  Future<File?> getImageFromCamera() async {
    final ImagePicker picker = ImagePicker();
    final XFile? xFile = await picker.pickImage(
      source: ImageSource.camera,
    );

    if (xFile != null) {
      return File(xFile.path);
    }
    return null;
  }

  // Add image to upload queue and process sequentially
  Future<void> uploadImage(String receiverId, File imageFile, {Function(double)? onProgress}) async {
    // Check if file exists
    if (!await imageFile.exists()) {
      throw Exception('Image file does not exist: ${imageFile.path}');
    }
    
    _uploadQueue.add(_PendingUpload(
      imageFile: imageFile, 
      receiverId: receiverId,
      onProgress: onProgress,
    ));
    await _processUploadQueue();
  }

  // Process upload queue sequentially to prevent race conditions
  Future<void> _processUploadQueue() async {
    if (_isUploading || _uploadQueue.isEmpty) return;
    
    _isUploading = true;
    
    try {
      while (_uploadQueue.isNotEmpty) {
        final pending = _uploadQueue.removeAt(0);
        try {
          await _uploadImageFile(
            pending.imageFile, 
            pending.receiverId,
            onProgress: pending.onProgress,
          );
        } catch (e) {
          debugPrint('Error uploading image from queue: $e');
          // Continue with next image even if one fails
        }
      }
    } finally {
      _isUploading = false;
    }
  }

  // Internal method to upload a single image file
  Future<void> _uploadImageFile(
    File imageFile, 
    String receiverId, {
    Function(double)? onProgress,
  }) async {
    final currentUser = _firebaseAuth.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    // Verify file exists and is readable
    if (!await imageFile.exists()) {
      throw Exception('Image file does not exist: ${imageFile.path}');
    }

    final fileSize = await imageFile.length();
    if (fileSize == 0) {
      throw Exception('Image file is empty');
    }

    debugPrint('Starting image upload: ${imageFile.path}, size: $fileSize bytes');

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
            imageFile.path,
          ),
        );

      debugPrint('Sending request to Cloudinary...');
      onProgress?.call(0.1); // 10% - Starting upload
      
      // Simulate progress during upload (since MultipartRequest doesn't expose upload stream)
      Timer? progressTimer;
      if (onProgress != null) {
        double currentProgress = 0.1;
        progressTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
          currentProgress += 0.02; // Increase by 2% every 200ms
          if (currentProgress < 0.8) {
            onProgress!(currentProgress);
          } else {
            timer.cancel();
          }
        });
      }
      
      // Send request
      final response = await request.send();
      progressTimer?.cancel();
      onProgress?.call(0.8); // 80% - Upload sent, waiting for response
      
      // Read response
      final responseBody = await response.stream.bytesToString();
      onProgress?.call(0.9); // 90% - Response received, processing
      
      debugPrint('Cloudinary response status: ${response.statusCode}');

      if (response.statusCode != 200 && response.statusCode != 201) {
        debugPrint('Cloudinary upload failed. Status: ${response.statusCode}, Body: $responseBody');
        throw Exception('Cloudinary upload failed: ${response.statusCode}');
      }

      final resBody = jsonDecode(responseBody);
      final String imageUrl = resBody['secure_url'] as String? ?? '';
      
      if (imageUrl.isEmpty) {
        throw Exception('Cloudinary returned empty image URL');
      }

      debugPrint('Image uploaded successfully to Cloudinary: $imageUrl');

      /// 💬 Save message in Firestore
      final imageMessage = Message(
        senderEmail: currentUser.email!,
        senderId: currentUser.uid,
        receiverId: receiverId,
        message: imageUrl,
        timestamp: timestamp,
        type: 'image',
      );

      await _firestore
          .collection('chat_rooms')
          .doc(chatRoomId)
          .collection('messages')
          .add(imageMessage.toMap());

      onProgress?.call(1.0); // 100% - Complete
      debugPrint('Image message saved to Firestore successfully');
    } catch (e, stackTrace) {
      debugPrint('Cloudinary upload error: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow; // Re-throw to allow error handling in UI
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

  //Get messages - for chat screen (all messages, limited for performance)
  Stream<QuerySnapshot> getMessages(String userId, String otherUserId){
    List<String> ids = [userId, otherUserId];
    ids.sort();
    String chatRoomId = ids.join("_");
    return _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }
  
  // Get last message for preview (optimized query - only fetches 1 document)
  Stream<QuerySnapshot> getLastMessage(String userId, String otherUserId) {
    List<String> ids = [userId, otherUserId];
    ids.sort();
    String chatRoomId = ids.join("_");
    return _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots();
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

  // Get all user IDs with whom the current user has chatted
  Future<Set<String>> getChattedUserIds(String userId) async {
    try {
      final chatRoomsSnapshot = await _firestore
          .collection('chat_rooms')
          .get();

      final Set<String> chattedUserIds = {};

      for (var roomDoc in chatRoomsSnapshot.docs) {
        final chatRoomId = roomDoc.id;
        final parts = chatRoomId.split('_');
        
        if (parts.length == 2) {
          final user1Id = parts[0];
          final user2Id = parts[1];
          
          // Check if this chat room contains messages
          final messagesSnapshot = await _firestore
              .collection('chat_rooms')
              .doc(chatRoomId)
              .collection('messages')
              .limit(1)
              .get();
          
          if (messagesSnapshot.docs.isNotEmpty) {
            if (user1Id == userId) {
              chattedUserIds.add(user2Id);
            } else if (user2Id == userId) {
              chattedUserIds.add(user1Id);
            }
          }
        }
      }

      return chattedUserIds;
    } catch (e) {
      debugPrint('Error getting chatted user IDs: $e');
      return {};
    }
  }

  // Check if user has chatted with another user
  Future<bool> hasChattedWith(String userId, String otherUserId) async {
    try {
      final ids = [userId, otherUserId]..sort();
      final chatRoomId = ids.join("_");
      
      final messagesSnapshot = await _firestore
          .collection('chat_rooms')
          .doc(chatRoomId)
          .collection('messages')
          .limit(1)
          .get();
      
      return messagesSnapshot.docs.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking chat status: $e');
      return false;
    }
  }

  // Stream to get all chat rooms for a user (for real-time updates)
  Stream<QuerySnapshot> getChatRoomsForUser(String userId) {
    return _firestore
        .collection('chat_rooms')
        .snapshots();
  }
}

// Helper class to track pending uploads
class _PendingUpload {
  final File imageFile;
  final String receiverId;
  final Function(double)? onProgress;

  _PendingUpload({
    required this.imageFile, 
    required this.receiverId,
    this.onProgress,
  });
}