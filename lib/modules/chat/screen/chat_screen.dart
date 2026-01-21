import 'package:cached_network_image/cached_network_image.dart';
import 'package:chat_app/core/constants/app_colors.dart';
import 'package:chat_app/data/services/chat_service.dart';
import 'package:chat_app/modules/chat/controller/chat_controller.dart';
import 'package:chat_app/widgets/chat_bubble.dart';
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

  void sendMessages() async {
    if (controller.messageController.text.isNotEmpty) {
      final text = controller.messageController.text;
      controller.messageController.clear();

      // mark locked before sending - stream callback will animate down after the message is inserted.
      controller.markLockedBeforeSend();

      await _chatService.sendMessage(receiverUserId, text);

      // Optional: ensure UI stays at bottom after send (safe fallback)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.updateAndMaybeScroll();
      });
    }
  }

  String formatTimestamp(Timestamp timestamp) {
    DateTime date = timestamp.toDate();
    return DateFormat('hh:mm a').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () {
                  Get.back();
                },
                child: Icon(Icons.arrow_back, size: 20),
              ),
              SizedBox(width: Get.width * 0.05),
              CircleAvatar(
                backgroundImage: receiverUserPhoto.isNotEmpty
                    ? CachedNetworkImageProvider(receiverUserPhoto)
                    : null,
                child: receiverUserPhoto.isEmpty
                    ? const Icon(Icons.person)
                    : null,
              ),
              SizedBox(width: Get.width * 0.04),
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
            ],
          ),
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

  Widget _buildMessageList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _chatService.getMessages(
        _firebaseAuth.currentUser!.uid,
        receiverUserId,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        
        // Only show loading indicator on initial load when we have no data
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }

        // If we have data, use it even if connection state is waiting (prevents flicker on keyboard open/close)
        final docs = snapshot.hasData ? snapshot.data!.docs : <QueryDocumentSnapshot>[];
        final reversedDocs = docs.reversed.toList();

        // With reverse: true, ListView starts at position 0 (bottom) by default
        // Mark as initial scrolled so we don't try to scroll on first load
        if (reversedDocs.isNotEmpty && !controller.hasInitialScrolled) {
          controller.hasInitialScrolled = true;
          controller.lastMessageCount = reversedDocs.length;
        }

        // Scroll to bottom (position 0) when new messages arrive (only if locked to bottom)
        if (reversedDocs.isNotEmpty && controller.hasInitialScrolled) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (reversedDocs.length != controller.lastMessageCount) {
              controller.lastMessageCount = reversedDocs.length;
              controller.updateAndMaybeScroll();
            }
          });
        }

        return ListView.builder(
          controller: controller.scrollController,
          reverse: true,
          itemCount: reversedDocs.length,
          padding: const EdgeInsets.only(bottom: 10, top: 10),
          itemBuilder: (context, index) {
            return _buildMessageItem(reversedDocs[index]);
          },
        );
      },
    );
  }

  Widget _buildMessageItem(QueryDocumentSnapshot document) {
    Map<String, dynamic> data = document.data() as Map<String, dynamic>;
    var alignment = (data['senderId'] == _firebaseAuth.currentUser!.uid)
        ? Alignment.centerRight
        : Alignment.centerLeft;

    return Container(
      alignment: alignment,
      child: Column(
        crossAxisAlignment: (data['senderId'] == _firebaseAuth.currentUser!.uid)
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        mainAxisAlignment: (data['senderId'] == _firebaseAuth.currentUser!.uid)
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 10, right: 10, top: 10),
            child: ChatBubble(
              message: data['message'],
              color: (data['senderId'] == _firebaseAuth.currentUser!.uid)
                  ? Colors.blue
                  : Colors.grey,
              radiusBottomLeft:
                  (data['senderId'] == _firebaseAuth.currentUser!.uid) ? 8 : 0,
              radiusBottomRight:
                  (data['senderId'] == _firebaseAuth.currentUser!.uid) ? 0 : 8,
              radiusTopLeft:
                  (data['senderId'] == _firebaseAuth.currentUser!.uid) ? 8 : 8,
              radiusTopRight:
                  (data['senderId'] == _firebaseAuth.currentUser!.uid) ? 8 : 8,
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
    );
  }

  Widget _buildMessageInput() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8),
      child: Row(
        children: [
          SizedBox(width: 5,),
          Obx(() {
            bool hasText = controller.hasText.value;
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                // If you want extra spacing when icons are shown
                margin: EdgeInsets.only(right: hasText ? 0 : 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: AppColors.background, width: 1),
                ),
                child: TextFormField(
                  controller: controller.messageController,
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
            // Only icons part rebuilds
            return controller.hasText.value
                ? GestureDetector(
                    onTap: sendMessages,
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
                : _SwipeGestureIcons();

          }),
        ],
      ),
    );
  }
}

class _SwipeGestureIcons extends StatefulWidget {
  const _SwipeGestureIcons({super.key});

  @override
  State<_SwipeGestureIcons> createState() => _SwipeGestureIconsState();
}

class _SwipeGestureIconsState extends State<_SwipeGestureIcons> with TickerProviderStateMixin {
  bool _expanded = false;
  double _accumulatedDx = 0.0;

  static const double _dragThreshold = 40; // distance in logical pixels to trigger
  static const double _velocityThreshold = 300; // logical pixels/sec to trigger on fling

  void _onDragUpdate(DragUpdateDetails details) {
    _accumulatedDx += details.delta.dx;
    // NOW: swipe LEFT -> expand, swipe RIGHT -> collapse
    if (_accumulatedDx < -_dragThreshold && !_expanded) {
      setState(() => _expanded = true);
      _accumulatedDx = 0;
    } else if (_accumulatedDx > _dragThreshold && _expanded) {
      setState(() => _expanded = false);
      _accumulatedDx = 0;
    }
  }

  void _onDragEnd(DragEndDetails details) {
    final v = details.primaryVelocity ?? 0.0;
    // NOW: negative velocity (left fling) expands, positive velocity (right fling) collapses
    if (v < -_velocityThreshold) {
      if (!_expanded) setState(() => _expanded = true);
    } else if (v > _velocityThreshold) {
      if (_expanded) setState(() => _expanded = false);
    }
    _accumulatedDx = 0;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: _expanded
              ? [
            const Icon(Icons.camera_alt_outlined, size: 30),
            const SizedBox(width: 12),
            const Icon(Icons.mic, size: 30),
            const SizedBox(width: 12),
            const Icon(Icons.photo, size: 30),
          ]
              : [
            const Icon(Icons.camera_alt_outlined, size: 30),
            const SizedBox(width: 12),
            const Icon(Icons.mic, size: 30),
          ],
        ),
      ),
    );
  }
}
