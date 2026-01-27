import 'package:cached_network_image/cached_network_image.dart';
import 'package:chat_app/modules/chat/screen/chat_screen.dart';
import 'package:chat_app/modules/home/controller/home_controller.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/intl.dart';

import '../../../data/services/chat_service.dart';
import '../../../utils/firebase_api.dart';
import '../../login/screen/login_screen.dart';


class HomeScreen extends GetView<HomeController> {
  static const String id = '/home';

  HomeScreen({super.key});

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ChatService _chatService = ChatService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.search, size: 25),
            onPressed: () {
              controller.toggleSearch();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search field
          Obx(() => controller.isTap.value
              ? Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextFormField(
              controller: controller.searchController,
              focusNode: controller.searchNode,
              onChanged: (value) {
                controller.searchQuery.value = value;
              },
              decoration: InputDecoration(
                hintText: "Search the people you've contacted with",
                hintStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: Colors.grey),
                enabledBorder: OutlineInputBorder(
                  borderSide:
                  const BorderSide(color: Colors.black, width: 1),
                  borderRadius: BorderRadius.circular(10),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                  const BorderSide(color: Colors.blue, width: 1),
                ),
                suffixIcon: _buildSuffixIcon(),
              ),
            ),
          )
              : const SizedBox.shrink()),
          // User list (real-time search)
          Expanded(
            child: Obx(() {
              final searchQuery = controller.searchQuery.value;
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

                  // Filter based on searchQuery in real-time (character by character)
                  final docs = snapshot.data!.docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    if (_auth.currentUser?.uid == data['uid']) return false;

                    if (searchQuery.isEmpty) return true;

                    final name = (data['name'] ?? '').toLowerCase();
                    return name.startsWith(searchQuery.toLowerCase());
                  }).toList();

                  if (docs.isEmpty) {
                    return const Center(child: Text('No contact found'));
                  }

                  return ListView(
                    children:
                    docs.map((doc) => _buildUserListItem(context, doc)).toList(),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildSuffixIcon() {
    return Obx(() => controller.searchQuery.value.isNotEmpty
        ? IconButton(
            icon: const Icon(Icons.close),
            onPressed: controller.clearSearch,
          )
        : const SizedBox.shrink());
  }

  Widget _buildUserListItem(BuildContext context, DocumentSnapshot document) {
    final data = document.data() as Map<String, dynamic>;

    if (_auth.currentUser?.uid == data['uid']) return const SizedBox.shrink();

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

          final Timestamp timestamp = snapshot.data!.docs.last['timestamp'];
          final formattedTime =
          DateFormat('hh:mm a').format(timestamp.toDate());

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

          final lastMessage = snapshot.data!.docs.last['message'] ?? '';
          return lastMessage.toString().contains('/image/')
              ? Row(
            children: const [
              Icon(Icons.camera_alt_outlined, size: 25, color: Colors.blue),
              SizedBox(width: 5),
              Text('Photo'),
            ],
          )
              : lastMessage.toString().contains('/raw/')
              ? Row(
            children: const [
              Icon(Icons.mic, size: 25, color: Colors.blue),
              SizedBox(width: 5),
              Text('Voice message'),
            ],
          )
              : Text(lastMessage,
              maxLines: 1, overflow: TextOverflow.ellipsis);
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

