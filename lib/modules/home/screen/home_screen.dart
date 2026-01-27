import 'package:cached_network_image/cached_network_image.dart';
import 'package:chat_app/modules/chat/screen/chat_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/intl.dart';

import '../../../data/services/chat_service.dart';
import '../../../utils/firebase_api.dart';
import '../../login/screen/login_screen.dart';

class HomeScreen extends StatelessWidget {
  static const String id = '/home';

  HomeScreen({super.key});

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final ChatService _chatService = ChatService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: _buildUserList(context),
    );
  }

  /// 🔹 Builds the user list from Firestore
  Widget _buildUserList(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Something went wrong'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No users found'));
        }

        return ListView(
          children: snapshot.data!.docs
              .map((doc) => _buildUserListItem(context, doc))
              .toList(),
        );
      },
    );
  }

  /// 🔹 Builds a single user tile
  Widget _buildUserListItem(BuildContext context, DocumentSnapshot document) {
    final data = document.data() as Map<String, dynamic>;

    // Skip current user
    if (_auth.currentUser?.uid == data['uid']) {
      return const SizedBox.shrink();
    }

    return ListTile(
      leading: CircleAvatar(
        backgroundImage: data['photoUrl'] != null
            ? CachedNetworkImageProvider(data['photoUrl'])
            : null,
        child: data['photoUrl'] == null ? const Icon(Icons.person) : null,
      ),
      title: Text(data['name'] ?? 'No Name'),
      trailing: StreamBuilder<QuerySnapshot>(
        stream: _chatService.getMessages(_auth.currentUser!.uid, data['uid']),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Text('Loading...');
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Text('No message yet');
          }

          // Get the latest message timestamp
          final Timestamp timestamp = snapshot.data!.docs.last['timestamp'];
          final DateTime dateTime = timestamp.toDate();
          final formattedTime = DateFormat('hh:mm a').format(dateTime);

          return Text(formattedTime, maxLines: 1, overflow: TextOverflow.ellipsis);
        },
      ),
      subtitle: StreamBuilder<QuerySnapshot>(
        stream: _chatService.getMessages(_auth.currentUser!.uid, data['uid']),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Text('Loading...');
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Text('No message yet');
          }

          // Get the latest message (the last one in ascending order)
          final lastMessage = snapshot.data!.docs.last['message'] ?? '';
          return lastMessage.toString().contains('/image/')
              ? Row(
                  children: [
                    Icon(Icons.camera_alt_outlined, size: 25, color: Colors.blue),
                    SizedBox(width: 5),
                    Text('Photo'),
                  ],
                )
          : lastMessage.toString().contains('/raw/')
              ? Row(
            children: [
              Icon(Icons.mic, size: 25, color: Colors.blue,),
              SizedBox(width: 5),
              Text('Voice message'),
            ],
          )
              : Text(lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis);
        },
      ),
      onTap: () {
        Get.toNamed(
          ChatScreen.id,
          arguments: {
            'receiverUserEmail': data['email'],
            'receiverUserId': data['uid'],
            'receiverUserName': data['name'],
            'receiverUserPhoto': data['photoUrl'],
          },
        );
      },
    );
  }
}
