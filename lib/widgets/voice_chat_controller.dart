import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';

class VoiceChatController extends GetxController {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final FlutterSoundRecorder recorder = FlutterSoundRecorder();
  final RxBool isRecording = false.obs;
  final Rxn<File> audioFile = Rxn<File>();

  final AudioPlayer player = AudioPlayer();

  // Cloudinary config
  final String _cloudName = 'YOUR_CLOUD_NAME';
  final String _uploadPreset = 'YOUR_UPLOAD_PRESET';

  @override
  void onInit() {
    super.onInit();
    initRecorder();
  }

  Future<void> initRecorder() async {
    await recorder.openRecorder();
    await recorder.setSubscriptionDuration(const Duration(milliseconds: 500));
  }

  Future<bool> requestPermission() async {
    try {
      var status = await Permission.microphone.request();
      return status.isGranted;
    } catch (e) {
      debugPrint('Permission error: $e');
      try {
        var status = await Permission.microphone.status;
        return status.isGranted;
      } catch (_) {
        return false;
      }
    }
  }

  Future<void> startRecording() async {
    if (!await requestPermission()) return;
    await recorder.startRecorder(toFile: 'voice_message.aac');
    isRecording.value = true;
  }

  Future<String?> stopRecording() async {
    String? path = await recorder.stopRecorder();
    isRecording.value = false;
    return path;
  }

  @override
  void onClose() {
    recorder.closeRecorder();
    player.dispose();
    super.onClose();
  }

  // ---------------- Cloudinary Upload ----------------
  Future<String?> uploadVoiceToCloudinary(String filePath, String receiverId) async {
    try {
      List<String> ids = [_firebaseAuth.currentUser!.uid, receiverId]..sort();
      final chatRoomId = ids.join('_');

      final uri = Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/voice/upload');
      final file = File(filePath);
      final mimeType = lookupMimeType(filePath) ?? 'audio/aac';

      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = _uploadPreset
        ..fields['folder'] = 'chat_audio/$chatRoomId'
        ..files.add(await http.MultipartFile.fromPath(
          'file',
          file.path,
          contentType: MediaType.parse(mimeType),
        ));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Cloudinary upload failed');
      }

      final resBody = jsonDecode(response.body);
      final String audioUrl = resBody['secure_url'];
      return audioUrl;
    } catch (e) {
      debugPrint('Cloudinary voice upload error: $e');
      return null;
    }
  }

  // ---------------- Send voice message ----------------
  Future<void> sendVoiceMessage(String filePath, String receiverId) async {
    final currentUser = _firebaseAuth.currentUser!;
    final timestamp = Timestamp.now();

    final audioUrl = await uploadVoiceToCloudinary(filePath, receiverId);
    if (audioUrl != null) {
      final message = {
        'senderEmail': currentUser.email,
        'senderId': currentUser.uid,
        'receiverId': receiverId,
        'message': audioUrl,
        'timestamp': timestamp,
        'type': 'voice',
      };

      List<String> ids = [currentUser.uid, receiverId]..sort();
      final chatRoomId = ids.join('_');

      await _firestore
          .collection('chat_rooms')
          .doc(chatRoomId)
          .collection('messages')
          .add(message);
    }
  }

  // ---------------- Play audio ----------------
  void playAudio(String url) async {
    try {
      await player.setUrl(url);
      player.play();
    } catch (e) {
      debugPrint('Error playing audio: $e');
    }
  }
}

