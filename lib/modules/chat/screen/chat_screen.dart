import 'package:chat_app/core/constants/app_colors.dart';
import 'package:chat_app/data/services/chat_service.dart';
import 'package:chat_app/modules/chat/controller/chat_controller.dart';
import 'package:chat_app/widgets/chat_bubble.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

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
    if(controller.messageController.text.isNotEmpty){
      await _chatService.sendMessage(
          receiverUserId,
          controller.messageController.text
      );
      controller.messageController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: (){
                Get.back();
              },
              child: Icon(
                Icons.arrow_back,
                size: 20,
              ),
            ),
            SizedBox(width: Get.width * 0.05,),
            CircleAvatar(
              backgroundImage: receiverUserPhoto.isNotEmpty
                  ? NetworkImage(receiverUserPhoto)
                  : null,
              child: receiverUserPhoto.isEmpty
                  ? const Icon(Icons.person)
                  : null,
            ),
            SizedBox(width: Get.width * 0.04,),
            Text(
              receiverUserName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w400,
                color: AppColors.background
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _buildMessageList(),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _chatService.getMessages(
        _firebaseAuth.currentUser!.uid, // current user first
        receiverUserId, // then receiver
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(),
          );
        }

        final docs = snapshot.data!.docs;

        return ListView(
          children: docs.map((document) => _buildMessageItem(document)).toList(),
        );
      },
    );
  }


  Widget _buildMessageItem(QueryDocumentSnapshot document){
    Map<String, dynamic> data = document.data() as Map<String, dynamic>;
    var alignment = (data['senderId'] == _firebaseAuth.currentUser!.uid)
    ? Alignment.centerRight
        : Alignment.centerLeft;

    return Container(
      alignment: alignment,
      child: Column(
        crossAxisAlignment:
        (data['senderId'] == _firebaseAuth.currentUser!.uid)
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
                color: (data['senderId'] == _firebaseAuth.currentUser!.uid) ? Colors.blue : Colors.grey,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 10.0, right: 10, bottom: 10),
            child: Text(
              data['timestamp'].toString(),
              style: TextStyle(
                fontWeight: FontWeight.w300,
                fontSize: 12,
              ),
            ),
          ),
        ],
      )
    );
  }

  Widget _buildMessageInput(){
    return Row(
      children: [
        Expanded(
            child: TextFormField(
              controller: controller.messageController,
              obscureText: false,
              decoration: InputDecoration(
                hintText: 'Enter message',
              ),
            ),
        ),
        IconButton(
            onPressed: sendMessages,
            icon: Icon(Icons.arrow_upward, size: 40,),
        ),
      ],
    );
  }

}