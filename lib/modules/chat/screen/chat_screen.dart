// chat_screen.dart
import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:chat_app/core/constants/app_colors.dart';
import 'package:chat_app/data/services/chat_service.dart';
import 'package:chat_app/modules/chat/controller/chat_controller.dart';
import 'package:chat_app/modules/chat/widgets/voice_recording_dialog.dart';
import 'package:chat_bubbles/bubbles/bubble_normal_audio.dart';
import 'package:chat_bubbles/date_chips/date_chip.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

class ChatScreen extends GetView<ChatController> {
  static const String id = '/chat';

  late final String receiverUserId;
  late final String receiverUserEmail;
  late final String receiverUserName;
  late final String receiverUserPhoto;

  ChatScreen({super.key}) {
    final args = Get.arguments as Map<String, dynamic>;
    receiverUserId = args['receiverUserId'];
    receiverUserEmail = args['receiverUserEmail'];
    receiverUserName = args['receiverUserName'];
    receiverUserPhoto = args['receiverUserPhoto'];
  }

  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final ChatService _chatService = ChatService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              GestureDetector(onTap: () => Get.back(), child: Icon(Icons.arrow_back, size: 20)),
              SizedBox(width: Get.width * 0.05),
              CircleAvatar(
                backgroundImage: receiverUserPhoto.isNotEmpty ? CachedNetworkImageProvider(receiverUserPhoto) : null,
                child: receiverUserPhoto.isEmpty ? const Icon(Icons.person) : null,
              ),
              SizedBox(width: Get.width * 0.04),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(receiverUserName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w400, color: AppColors.background)),
                  SizedBox(height: 2),
                  StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance.collection('users').doc(receiverUserId).snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return SizedBox.shrink();
                      final data = snapshot.data!.data() as Map<String, dynamic>?;
                      if (data == null) return SizedBox.shrink();
                      final isOnline = data['isOnline'] ?? false;
                      final lastSeen = (data['lastSeen'] as Timestamp?)?.toDate();
                      final typingTo = data['typingTo'] ?? '';
                      final isTyping = typingTo == _firebaseAuth.currentUser!.uid;
                      String statusText;
                      if (isTyping) statusText = 'Typing...';
                      else if (isOnline) statusText = 'Online';
                      else if (lastSeen != null) statusText = 'Last seen: ${DateFormat('hh:mm a').format(lastSeen)}';
                      else statusText = 'Offline';
                      return Text(statusText, style: TextStyle(fontSize: 14, color: Colors.black, fontStyle: isTyping ? FontStyle.italic : FontStyle.normal));
                    },
                  ),
                ],
              ),
            ],
          ),
          actions: [
            Icon(Icons.call, size: 30),
            SizedBox(width: 20),
            Icon(Icons.video_call, size: 30),
            SizedBox(width: 15),
          ],
        ),
        body: Column(children: [
          Expanded(child: _buildMessageList()),
          _buildMessageInput(),
        ]),
      ),
    );
  }

  Future<void> _openVoiceRecordingDialog() async {
    await Get.dialog(
      VoiceRecordingDialog(
        receiverUserId: receiverUserId,
        onSend: (String filePath) async {
          try {
            await _chatService.uploadVoice(receiverUserId, filePath);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              controller.updateAndMaybeScroll();
            });
          } catch (e) {
            debugPrint('Failed to upload voice: $e');
            Get.snackbar('Error', 'Failed to send voice message. Please try again.');
          }
        },
      ),
      barrierDismissible: false,
    );
  }

  // ---------- message UI ----------
  Widget _buildMessageList() {
    final currentUser = _firebaseAuth.currentUser!;
    final ids = [currentUser.uid, receiverUserId]..sort();
    final chatRoomId = ids.join('_');

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('chat_rooms').doc(chatRoomId).collection('messages').orderBy('timestamp', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) return Center(child: CircularProgressIndicator());

        final docs = snapshot.hasData ? snapshot.data!.docs : <QueryDocumentSnapshot>[];
        // already descending order; ListView with reverse true keeps bottom at index 0
        return ListView.builder(
          controller: controller.scrollController,
          reverse: true,
          padding: const EdgeInsets.only(bottom: 10, top: 10),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final isMe = data['senderId'] == currentUser.uid;

            // date chip logic
            Timestamp? prevTs;
            if (index + 1 < docs.length) prevTs = docs[index + 1]['timestamp'];
            final showDateChip = _isNewDay(data['timestamp'], prevTs);

            return Column(
              children: [
                if (showDateChip)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: DateChip(date: (data['timestamp'] as Timestamp).toDate(), color: const Color(0x558AD3D5)),
                  ),
                Container(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 10, right: 10, top: 0),
                        child: data['type'] == 'voice'
                            ? Obx(() {
                          final isCurrentAudio = controller.currentPlayingUrl.value == data['message'];
                          return BubbleNormalAudio(
                            color: isMe ? Colors.blue : Colors.grey,
                            duration: controller.audioDuration.value.toDouble(),
                            position: isCurrentAudio ? controller.audioPosition.value.toDouble() : 0.0,
                            isPlaying: isCurrentAudio && controller.isPlaying.value,
                            isLoading: isCurrentAudio && controller.isLoading.value,
                            isPause: isCurrentAudio && controller.isPause.value,
                            onSeekChanged: (value) => controller.changeSeek(value),
                            onPlayPauseButtonClick: () => controller.playPauseAudio(data['message']),
                            sent: isMe,
                          );
                        })
                            : ChatBubble(
                          message: data['message'],
                          color: isMe ? Colors.blue : Colors.grey,
                          radiusBottomLeft: isMe ? 8 : 0,
                          radiusBottomRight: isMe ? 0 : 8,
                          radiusTopLeft: 8,
                          radiusTopRight: 8,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 10.0, right: 10, bottom: 10),
                        child: Text(
                          formatTimestamp(data['timestamp']),
                          style: TextStyle(fontWeight: FontWeight.w300, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildMessageInput() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8),
      child: Row(
        children: [
          const SizedBox(width: 5),
          Obx(() {
            bool hasText = controller.hasText.value;
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                margin: EdgeInsets.only(right: hasText ? 0 : 8),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25), border: Border.all(color: AppColors.background, width: 1)),
                child: TextFormField(
                  controller: controller.messageController,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  decoration: const InputDecoration(counter: Offstage(), hintText: 'Enter message', border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 12)),
                ),
              ),
            );
          }),
          const SizedBox(width: 10),
          Obx(() {
            return controller.hasText.value
                ? GestureDetector(
              onTap: sendMessages,
              child: Container(height: 45, width: 45, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.blue), child: const Icon(Icons.arrow_right_alt, size: 30, color: Colors.white)),
            )
                : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () async {
                    await _chatService.getImage();
                    if (_chatService.imageFile == null) return;
                    await _chatService.uploadImage(receiverUserId);
                    WidgetsBinding.instance.addPostFrameCallback((_) => controller.updateAndMaybeScroll());
                  },
                  child: const Icon(Icons.photo, size: 30),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _openVoiceRecordingDialog,
                  child: const Icon(Icons.mic, size: 30),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  // ---------- helper functions ----------
  bool _isNewDay(Timestamp current, Timestamp? previous) {
    if (previous == null) return true;
    final curr = current.toDate(), prev = previous.toDate();
    return curr.year != prev.year || curr.month != prev.month || curr.day != prev.day;
  }

  DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  String _formatDateLabel(DateTime date) {
    final now = DateTime.now();
    if (_dateOnly(date) == _dateOnly(now)) return 'Today';
    if (_dateOnly(date) == _dateOnly(now.subtract(const Duration(days: 1)))) return 'Yesterday';
    return DateFormat('d MMM yyyy').format(date);
  }

  void sendMessages() async {
    if (controller.messageController.text.isNotEmpty) {
      final text = controller.messageController.text;
      controller.messageController.clear();
      controller.markLockedBeforeSend();
      await _chatService.sendMessage(receiverUserId, text);
      WidgetsBinding.instance.addPostFrameCallback((_) => controller.updateAndMaybeScroll());
    }
  }

  String formatTimestamp(Timestamp timestamp) => DateFormat('hh:mm a').format(timestamp.toDate());
}

// ------------------ ChatBubble & VoiceBubble ------------------
class ChatBubble extends StatelessWidget {
  final String message;
  final Color color;
  final double radiusTopLeft;
  final double radiusTopRight;
  final double radiusBottomLeft;
  final double radiusBottomRight;

  const ChatBubble({
    super.key,
    required this.message,
    required this.color,
    this.radiusTopLeft = 8,
    this.radiusTopRight = 8,
    this.radiusBottomLeft = 8,
    this.radiusBottomRight = 8,
  });

  bool get isImage => message.startsWith('https://res.cloudinary.com') && (message.contains('/image/upload') || message.contains('/image/upload/'));
  bool get isAudio {
    if (!message.startsWith('https://res.cloudinary.com')) return false;
    // Cloudinary raw uploads often contain '/raw/upload' — check that or known audio extensions
    return message.contains('/raw/upload') || message.endsWith('.aac') || message.endsWith('.m4a') || message.endsWith('.mp3') || message.endsWith('.wav');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      padding: isImage || isAudio ? EdgeInsets.zero : const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(radiusTopLeft),
          topRight: Radius.circular(radiusTopRight),
          bottomLeft: Radius.circular(radiusBottomLeft),
          bottomRight: Radius.circular(radiusBottomRight),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(5.0),
        child: isImage
            ? GestureDetector(
          onTap: () {/* open image preview if you have it */},
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(imageUrl: message, fit: BoxFit.cover, placeholder: (c, u) => Container(height: 180, width: 180, alignment: Alignment.center, child: const CircularProgressIndicator(strokeWidth: 2)), errorWidget: (c, u, e) => const Icon(Icons.broken_image)),
          ),
        )
            : isAudio
            ? Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.audiotrack, color: Colors.white),
            const SizedBox(width: 8),
            const Text('Voice message', style: TextStyle(fontSize: 16, color: Colors.white)),
          ],
        )
            : Text(message, style: const TextStyle(fontSize: 16, color: Colors.white), softWrap: true),
      ),
    );
  }
}

