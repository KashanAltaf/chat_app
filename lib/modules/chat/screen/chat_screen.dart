// chat_screen.dart
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:chat_app/core/constants/app_colors.dart';
import 'package:chat_app/data/services/chat_service.dart';
import 'package:chat_app/modules/chat/controller/chat_controller.dart';
import 'package:chat_app/modules/chat/widgets/voice_recording_dialog.dart';
import 'package:chat_app/widgets/image_preview_screen.dart';
import 'package:chat_bubbles/bubbles/bubble_normal_audio.dart';
import 'package:chat_bubbles/date_chips/date_chip.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:swipe_to/swipe_to.dart';

import '../../../utils/firebase_api.dart';
import '../../../widgets/chat_bubble.dart';
import '../model/message.dart';
import '../widgets/audio_chat_bubble.dart';

class ChatScreen extends GetView<ChatController> {
  static const String id = '/chat';

  final String receiverUserId;
  final String receiverUserEmail;
  final String receiverUserName;
  final String receiverUserPhoto;

  ChatScreen({super.key})
      : receiverUserId = _extractArg('receiverUserId', Get.arguments),
        receiverUserEmail = _extractArg('receiverUserEmail', Get.arguments, ''),
        receiverUserName = _extractArg('receiverUserName', Get.arguments, 'Unknown'),
        receiverUserPhoto = _extractArg('receiverUserPhoto', Get.arguments, '');

  static String _extractArg(String key, dynamic args, [String defaultValue = '']) {
    if (args is Map<String, dynamic>) {
      return args[key]?.toString() ?? defaultValue;
    }
    return defaultValue;
  }

  // Cache instances to avoid repeated lookups
  static final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final ChatService _chatService = ChatService();
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Cache current user to avoid repeated null checks
  User? get _currentUser => _firebaseAuth.currentUser;

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
              GestureDetector(
                onTap: () => Get.back(),
                child: Icon(Icons.arrow_back, size: 20),
              ),
              const SizedBox(width: 20),
              CircleAvatar(
                backgroundImage: receiverUserPhoto.isNotEmpty
                    ? CachedNetworkImageProvider(receiverUserPhoto)
                    : null,
                child: receiverUserPhoto.isEmpty
                    ? const Icon(Icons.person)
                    : null,
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    receiverUserName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w400,
                      color: AppColors.background,
                    ),
                  ),
                  SizedBox(height: 2),
                  StreamBuilder<DocumentSnapshot>(
                    stream: _firestore
                        .collection('users')
                        .doc(receiverUserId)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData || !snapshot.data!.exists) {
                        return const SizedBox.shrink();
                      }
                      final data = snapshot.data!.data() as Map<String, dynamic>?;
                      if (data == null) return const SizedBox.shrink();
                      
                      final isOnline = data['isOnline'] ?? false;
                      final lastSeen = (data['lastSeen'] as Timestamp?)?.toDate();
                      final typingTo = data['typingTo'] ?? '';
                      final currentUserId = _currentUser?.uid ?? '';
                      final isTyping = typingTo == currentUserId;
                      
                      final statusText = _getStatusText(isTyping, isOnline, lastSeen);
                      
                      return Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black,
                          fontStyle: isTyping ? FontStyle.italic : FontStyle.normal,
                        ),
                      );
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
        body: Column(
          children: [
            Expanded(child: _buildMessageList()),
            _buildMessageInput(),
          ],
        ),
      ),
    );
  }

  Future<void> _openVoiceRecordingDialog() async {
    await Get.dialog(
      VoiceRecordingDialog(
        receiverUserId: receiverUserId,
        onSend: (String filePath) async {
          try {
            await _chatService.uploadVoice(
              receiverUserId,
              filePath,
              controller.recordedWaveform.toList(),
            );
            controller.recordedWaveform.clear();
            controller.resetRecording();
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => controller.updateAndMaybeScroll(),
            );
          } catch (e) {
            debugPrint('Failed to upload voice: $e');
            Get.snackbar(
              'Error',
              'Failed to send voice message. Please try again.',
            );
          }
        },
      ),
      barrierDismissible: false,
    );
  }
  // ---------- helper functions ----------
  String _getStatusText(bool isTyping, bool isOnline, DateTime? lastSeen) {
    if (isTyping) return 'Typing...';
    if (isOnline) return 'Online';
    if (lastSeen != null) {
      return 'Last seen: ${DateFormat('hh:mm a').format(lastSeen)}';
    }
    return 'Offline';
  }

  // ---------- message UI ----------
  Widget _buildMessageList() {
    final currentUserId = _currentUser?.uid;
    if (currentUserId == null) {
      return const Center(child: Text('Please log in to view messages'));
    }
    
    final ids = [currentUserId, receiverUserId]..sort();
    final chatRoomId = ids.join('_');

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('chat_rooms')
          .doc(chatRoomId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return Center(child: Text('Error: ${snapshot.error}'));
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData)
          return Center(child: CircularProgressIndicator());

        final docs = snapshot.data?.docs ?? <QueryDocumentSnapshot>[];
        if (docs.isEmpty) {
          return const Center(
            child: Text('No messages yet. Start the conversation!'),
          );
        }
        
        // already descending order; ListView with reverse true keeps bottom at index 0
        return ListView.builder(
          controller: controller.scrollController,
          reverse: true,
          padding: const EdgeInsets.only(bottom: 10, top: 10),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final isMe = data['senderId'] == currentUserId;
            final rowKey = controller.messageKeys[doc.id] ?? GlobalKey();
            controller.messageKeys[doc.id] = rowKey;
            // Store the index for this messageId to help with scrolling
            controller.messageIndices[doc.id] = index;

            // date chip logic
            Timestamp? prevTs;
            if (index + 1 < docs.length) prevTs = docs[index + 1]['timestamp'];
            final showDateChip = _isNewDay(data['timestamp'], prevTs);

            return _SwipeReplyWrapper(
              triggerThreshold: 110,
              maxDrag: 140,
              isMe: isMe, // Pass isMe to allow left swipe for right-aligned messages
              onTriggered: () {
                // run the same logic that previously existed in onRightSwipe
                if (controller.replyMessage.value.isEmpty) {
                  // Determine sender name: if sender is current user, use "You", otherwise use receiver's name
                  final senderId = data['senderId'] ?? '';
                  final senderName = senderId == currentUserId ? 'You' : receiverUserName;
                  
                  controller.replyToMessage(
                    data['message'],
                    senderId: senderId,
                    messageId: doc.id,
                    type: (data['type'] as String?) ?? 'text',
                    senderName: senderName,
                  );

                  // ensure keyboard opens
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    controller.messageNode.requestFocus();
                  });
                }
              },
              child: Column(
                children: [
                  if (showDateChip)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: DateChip(
                        date: (data['timestamp'] as Timestamp).toDate(),
                        color: const Color(0x558AD3D5),
                      ),
                    ),
                  Container(
                    alignment: isMe
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: isMe
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        Padding(
                            padding: const EdgeInsets.only(
                              left: 10,
                              right: 10,
                              top: 0,
                            ),
                            child: data['type'] == 'voice'
                                ? Container(
                                    key: rowKey,
                                    child: Obx(() {
                                      final isCurrentAudio =
                                          controller.currentPlayingUrl.value ==
                                          data['message'];

                                      final duration = Duration(
                                        milliseconds:
                                            (controller.audioDuration.value * 1000)
                                                .toInt(),
                                      );
                                      final position = isCurrentAudio
                                          ? Duration(
                                              milliseconds:
                                                  (controller.audioPosition.value *
                                                          1000)
                                                      .toInt(),
                                            )
                                          : Duration.zero;
                                      final waveform =
                                      (data['waveform'] as List?)?.cast<double>();

                                      return AudioChatBubbleWithWaveform(
                                        isMe: isMe,
                                        isPlaying:
                                            isCurrentAudio &&
                                            controller.isPlaying.value,
                                        isLoading:
                                            isCurrentAudio &&
                                            controller.isLoading.value,
                                        isPause:
                                            isCurrentAudio &&
                                            controller.isPause.value,
                                        duration: duration,
                                        position: position,
                                        waveformSamples: waveform,
                                        onSeekChanged: (seconds) =>
                                            controller.changeSeek(seconds),
                                        onPlayPause: () => controller.playPauseAudio(
                                          data['message'],
                                        ),
                                      );
                                    }),
                                  )
                                : Container(
                                    key: rowKey,
                                    child: ChatBubble(
                                      message: data['message'],
                                      color: isMe ? Colors.blue : Colors.grey,
                                      radiusBottomLeft: isMe ? 8 : 0,
                                      radiusBottomRight: isMe ? 0 : 8,
                                      radiusTopLeft: 8,
                                      radiusTopRight: 8,
                                      replyTo: (data['replyTo'] as Map<String, dynamic>?),
                                      currentUserId: currentUserId,
                                      receiverUserName: receiverUserName,
                                      onReplyTap: (data['replyTo'] as Map<String, dynamic>?) != null
                                          ? () {
                                              final replyMessageId = (data['replyTo'] as Map<String, dynamic>?)!['messageId'] as String?;
                                              if (replyMessageId != null && replyMessageId.isNotEmpty) {
                                                controller.scrollToMessage(replyMessageId);
                                              }
                                            }
                                          : null,
                                    ),
                                ),
                          ),
                        Padding(
                          padding: const EdgeInsets.only(
                            left: 10.0,
                            right: 10,
                            bottom: 10,
                          ),
                          child: Text(
                            formatTimestamp(data['timestamp']),
                            style: TextStyle(
                              fontWeight: FontWeight.w300,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMessageInput() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Obx(() {
            final reply = controller.replyMessage.value;
            if (reply.isEmpty) return const SizedBox.shrink();
            final sender = controller.replySenderId.value;
            final replyType = controller.replyType.value;
            final displayName = sender == controller.currentUserId
                ? 'You'
                : (controller.otherUserName.value.isNotEmpty 
                    ? controller.otherUserName.value 
                    : receiverUserName);

            // Check if reply is voice or image
            final bool isVoiceReply = replyType == 'voice' || 
                (reply.contains('/raw/upload') || 
                 reply.endsWith('.aac') || 
                 reply.endsWith('.m4a') || 
                 reply.endsWith('.mp3') || 
                 reply.endsWith('.wav'));
            final bool isImageReply = replyType == 'image' || 
                (reply.startsWith('https://res.cloudinary.com') && 
                 (reply.contains('/image/upload') || reply.contains('/image/upload/')));

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  // left color bar to mimic WhatsApp style
                  Container(width: 4, height: 36, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Display sender name
                        if (sender.isNotEmpty)
                          Text(
                            displayName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        // Display content based on type
                        if (isVoiceReply)
                          Row(
                            children: const [
                              Icon(Icons.mic, size: 16, color: Colors.blue),
                              SizedBox(width: 6),
                              Text(
                                'Voice message',
                                style: TextStyle(fontSize: 13),
                              ),
                            ],
                          )
                        else if (isImageReply)
                          Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: CachedNetworkImage(
                                  imageUrl: reply,
                                  width: 36,
                                  height: 36,
                                  fit: BoxFit.cover,
                                  placeholder: (c, u) =>
                                      Container(width: 36, height: 36, color: Colors.grey.shade300),
                                  errorWidget: (c, u, e) => Container(
                                    width: 36,
                                    height: 36,
                                    alignment: Alignment.center,
                                    child: const Icon(Icons.broken_image, size: 16),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Image',
                                style: TextStyle(fontSize: 13),
                              ),
                            ],
                          )
                        else
                          Text(
                            reply,
                            style: TextStyle(fontSize: 13),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: controller.clearReply,
                    icon: Icon(Icons.close, size: 20),
                  ),
                ],
              ),
            );
          }),

          // Actual input row
          Row(
            children: [
              const SizedBox(width: 5),
              Obx(() {
                final hasText = controller.hasText.value;
                return Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    margin: EdgeInsets.only(right: hasText ? 0 : 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(color: AppColors.background, width: 1),
                    ),
                    child: TextFormField(
                      controller: controller.messageController,
                      focusNode: controller.messageNode,
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      decoration: const InputDecoration(
                        counter: Offstage(),
                        hintText: 'Enter message',
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(width: 10),
              Obx(() {
                return controller.hasText.value
                    ? GestureDetector(
                  onTap: (){
                    sendMessages(receiverUserId);
                  },
                  child: Container(
                    height: 45,
                    width: 45,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.blue,
                    ),
                    child: const Icon(
                      Icons.arrow_right_alt,
                      size: 30,
                      color: Colors.white,
                    ),
                  ),
                )
                    : GestureDetector(
                  onPanStart: (details) =>
                      controller.handleSwipeStart(details.globalPosition.dx),
                  onPanUpdate: (details) =>
                      controller.handleSwipeUpdate(details.globalPosition.dx),
                  onPanEnd: (_) => controller.handleSwipeEnd(),
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: controller.shouldBlockTap()
                              ? null
                              : () async {
                            await _chatService.getImageFromCamera();
                            if (_chatService.imageFile == null) return;
                            await _chatService.uploadImage(receiverUserId);
                            WidgetsBinding.instance.addPostFrameCallback(
                                  (_) => controller.updateAndMaybeScroll(),
                            );
                          },
                          child: const Icon(Icons.camera_alt, size: 30),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: controller.shouldBlockTap()
                              ? null
                              : _openVoiceRecordingDialog,
                          child: const Icon(Icons.mic, size: 30),
                        ),
                        if (controller.swipeExpanded.value) ...[
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: controller.shouldBlockTap()
                                ? null
                                : () async {
                              await _chatService.getImage();
                              if (_chatService.imageFile == null) return;
                              await _chatService.uploadImage(receiverUserId);
                              WidgetsBinding.instance.addPostFrameCallback(
                                    (_) => controller.updateAndMaybeScroll(),
                              );
                            },
                            child: const Icon(Icons.photo, size: 30),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }


  // ---------- helper functions ----------
  bool _isNewDay(Timestamp current, Timestamp? previous) {
    if (previous == null) return true;
    final curr = current.toDate(), prev = previous.toDate();
    return curr.year != prev.year ||
        curr.month != prev.month ||
        curr.day != prev.day;
  }

  Future<void> sendMessages(String receiverUserId) async {
    final text = controller.messageController.text.trim();
    if (text.isEmpty) return;

    // Copy reply metadata locally (so we can clear UI immediately)
    final replyText = controller.replyMessage.value;
    final replySender = controller.replySenderId.value;
    final replyMessageId = controller.replyMessageId.value;
    final replyType = controller.replyType.value;

    // Clear input & lock scroll before async work
    controller.messageController.clear();
    controller.markLockedBeforeSend();

    // Immediately hide reply box in UI (user sees reply box disappear as they tap Send)
    if (replyText.isNotEmpty) controller.clearReply();

    try {
      // 1️⃣ Send message to Firestore including reply metadata (use local copy)
      await _chatService.sendMessageWithReply(
        receiverId: receiverUserId,
        message: text,
        replyMessage: replyText.isNotEmpty ? replyText : null,
        replySenderId: replySender.isNotEmpty ? replySender : null,
        replyMessageId: replyMessageId.isNotEmpty ? replyMessageId : null,
        replyType: replyType.isNotEmpty ? replyType : null,
      );

      // 2️⃣ Compute chatRoomId (same logic as ChatService)
      final currentUserId = FirebaseAuth.instance.currentUser!.uid;
      final ids = [currentUserId, receiverUserId]..sort();
      final chatRoomId = ids.join('_');

      // 3️⃣ Send push notification
      await FirebaseApi().sendPushNotification(
        receiverUserId: receiverUserId,
        messageContent: text,
        chatId: chatRoomId,
        messageType: 'text',
      );

      // 4️⃣ Scroll to bottom if locked
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.updateAndMaybeScroll();
      });

    } catch (e, stackTrace) {
      debugPrint('sendMessages error: $e');
      debugPrintStack(stackTrace: stackTrace);
      // If send failed we might want to restore reply UI — optional:
      // controller.replyToMessage(replyText, senderId: replySender, messageId: replyMessageId, type: replyType);
    }
  }


  String formatTimestamp(Timestamp timestamp) =>
      DateFormat('hh:mm a').format(timestamp.toDate());
}

class _SwipeReplyWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback onTriggered;
  final double triggerThreshold; // in logical px
  final double maxDrag; // max translation
  final bool isMe; // true if message is from current user (right-aligned)

  const _SwipeReplyWrapper({
    Key? key,
    required this.child,
    required this.onTriggered,
    this.triggerThreshold = 120,
    this.maxDrag = 140,
    this.isMe = false,
  }) : super(key: key);

  @override
  State<_SwipeReplyWrapper> createState() => _SwipeReplyWrapperState();
}

class _SwipeReplyWrapperState extends State<_SwipeReplyWrapper>
    with SingleTickerProviderStateMixin {
  double _dx = 0.0;
  bool _triggered = false;
  late AnimationController _animController;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _animController =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _anim = Tween<double>(begin: 0, end: 0).animate(_animController)
      ..addListener(() => setState(() {}));
  }

  void _animateTo(double to) {
    _animController.stop();
    _anim = Tween<double>(begin: _dx, end: to).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    )..addListener(() {
      setState(() {
        _dx = _anim.value;
      });
    });
    _animController.reset();
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dx += details.delta.dx;
      // For right-aligned messages (isMe = true), allow left swipe (negative)
      // For left-aligned messages (isMe = false), allow right swipe (positive)
      if (widget.isMe) {
        // Left swipe for right-aligned messages
        _dx = _dx.clamp(-widget.maxDrag, 0.0);
      } else {
        // Right swipe for left-aligned messages
        _dx = _dx.clamp(0.0, widget.maxDrag);
      }
    });

    final threshold = widget.isMe ? -widget.triggerThreshold : widget.triggerThreshold;
    if (!_triggered && ((widget.isMe && _dx <= threshold) || (!widget.isMe && _dx >= threshold))) {
      _triggered = true;
      try {
        HapticFeedback.mediumImpact();
      } catch (_) {}
    }
  }

  void _onDragEnd(DragEndDetails details) {
    if (_triggered) {
      // fire the onTriggered immediately (reply UI opening, focusing input)
      widget.onTriggered();

      // animate back to zero after a short delay so user sees action
      Future.delayed(const Duration(milliseconds: 120), () {
        _animateTo(0);
        _triggered = false;
      });
    } else {
      // animate back to zero
      _animateTo(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Calculate arrow opacity based on swipe direction
    final threshold = widget.isMe ? -widget.triggerThreshold : widget.triggerThreshold;
    final arrowOpacity = widget.isMe
        ? (-_dx / widget.triggerThreshold).clamp(0.0, 1.0)
        : (_dx / widget.triggerThreshold).clamp(0.0, 1.0);

    // Choose high-contrast colors so arrow will be visible on light/dark backgrounds
    final arrowBg = Colors.blue;
    final iconColor = Colors.white;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      onHorizontalDragCancel: () {
        if (!_triggered) _animateTo(0);
      },
      child: Stack(
        alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
        children: [
          // Arrow indicator: vertically centered, positioned based on alignment
          Positioned(
            left: widget.isMe ? null : 10,
            right: widget.isMe ? 10 : null,
            top: 0,
            bottom: 0,
            child: IgnorePointer(
              ignoring: true,
              child: Opacity(
                opacity: arrowOpacity,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: arrowBg.withOpacity(0.95 * arrowOpacity),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.18 * arrowOpacity),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Transform.rotate(
                    angle: widget.isMe ? math.pi / 6 : -math.pi / 6,
                    child: Icon(
                      Icons.reply,
                      size: 22,
                      color: iconColor.withOpacity(arrowOpacity),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // The actual message widget (translated while dragging)
          Transform.translate(
            offset: Offset(_dx, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}
