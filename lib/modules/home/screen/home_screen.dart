import 'package:chat_app/modules/chat/screen/chat_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../data/services/chat_service.dart';
import '../../login/screen/login_screen.dart';

class HomeScreen extends StatelessWidget {
  static const String id = '/home';

  HomeScreen({super.key});

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: GestureDetector(
      onTap: () async {
        // Firebase logout
        await FirebaseAuth.instance.signOut();

        // Google logout (THIS is the key)
        await _googleSignIn.signOut();

        // Clear navigation & controllers
        Get.deleteAll();
        Get.offAllNamed(LoginScreen.id);
      },
      child: const Icon(
        Icons.logout,
        size: 30,
      ),
    ),

    )
        ],
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
  Widget _buildUserListItem(
      BuildContext context, DocumentSnapshot document) {
    final data = document.data() as Map<String, dynamic>;

    // Skip current user
    if (_auth.currentUser?.uid == data['uid']) {
      return const SizedBox.shrink();
    }

    return ListTile(
      leading: CircleAvatar(
        backgroundImage: data['photoUrl'] != null
            ? NetworkImage(data['photoUrl'])
            : null,
        child: data['photoUrl'] == null
            ? const Icon(Icons.person)
            : null,
      ),
      title: Text(data['name'] ?? 'No Name'),
      subtitle: StreamBuilder<QuerySnapshot>(
        stream: ChatService().getMessages(
            _auth.currentUser!.uid, data['uid']),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Text('Loading...');
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Text('No message yet');
          }

          // Get the latest message (the last one in ascending order)
          final lastMessage = snapshot.data!.docs.last['message'] ?? '';
          return Text(
              lastMessage,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
        },
      ),
      onTap: () {
        Get.toNamed(
          ChatScreen.id,
          arguments: {
            'receiverUserEmail': data['email'],
            'receiverUserId': data['uid'],
            'receiverUserName' : data['name'],
            'receiverUserPhoto' : data['photoUrl'],
          },
        );
      },
    );
  }
}
