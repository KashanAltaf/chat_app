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
                    ? NetworkImage(receiverUserPhoto)
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
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;

        // Scroll to bottom on initial load or when new messages arrive
        if (docs.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            // Only scroll if message count changed or it's the first load
            if (docs.length != controller.lastMessageCount || !controller.hasInitialScrolled) {
              controller.lastMessageCount = docs.length;
              // This will jump instantly on first load, animate on new messages
              controller.updateAndMaybeScroll();
            }
          });
        }

        return ListView.builder(
          controller: controller.scrollController,
          itemCount: docs.length,
          padding: const EdgeInsets.only(bottom: 10, top: 10),
          itemBuilder: (context, index) {
            return _buildMessageItem(docs[index]);
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
                  decoration: const InputDecoration(
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
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.camera_alt_outlined, size: 30),
                      SizedBox(width: 12),
                      Icon(Icons.mic, size: 30),
                    ],
                  );
          }),
        ],
      ),
    );
  }
}
