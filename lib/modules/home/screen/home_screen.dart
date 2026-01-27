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
          // User list (real-time search) - only shows users with existing chats
          Expanded(
            child: Obx(() {
              final searchQuery = controller.searchQuery.value;
              final currentUserId = _auth.currentUser?.uid;
              
              if (currentUserId == null) {
                return const Center(child: Text('Please log in'));
              }

              // Get all users first, then check which ones have messages
              return StreamBuilder<QuerySnapshot>(
                stream: _firestore.collection('users').snapshots(),
                builder: (context, usersSnapshot) {
                  if (usersSnapshot.hasError) {
                    return const Center(child: Text('Something went wrong'));
                  }
                  if (usersSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!usersSnapshot.hasData || usersSnapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('No users found'));
                  }

                  // Filter users: exclude current user and apply search filter
                  final filteredUsers = usersSnapshot.data!.docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final userId = data['uid'] as String?;
                    
                    if (userId == null || userId == currentUserId) return false;

                    // Apply search filter if search query is not empty
                    if (searchQuery.isNotEmpty) {
                      final name = (data['name'] ?? '').toLowerCase();
                      return name.startsWith(searchQuery.toLowerCase());
                    }

                    return true;
                  }).toList();

                  if (filteredUsers.isEmpty) {
                    return const Center(child: Text('No contact found'));
                  }

                  // Build list items - each will check if messages exist
                  // Only show users who have actual messages (not empty messages collection)
                  return ListView(
                    children: filteredUsers.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final userId = data['uid'] as String;
                      // Check if this user has messages with current user
                      return StreamBuilder<QuerySnapshot>(
                        stream: _chatService.getLastMessage(currentUserId, userId),
                        builder: (context, messagesSnapshot) {
                          // Only show if messages exist (messages collection is not empty)
                          if (messagesSnapshot.hasData && 
                              messagesSnapshot.data!.docs.isNotEmpty) {
                            return _buildUserListItem(context, doc);
                          }
                          // Hide users without messages - they should appear in search screen
                          return const SizedBox.shrink();
                        },
                      );
                    }).toList(),
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
        stream: _chatService.getLastMessage(_auth.currentUser!.uid, data['uid']),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox(width: 60, height: 20, child: CircularProgressIndicator(strokeWidth: 2));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Text('', style: TextStyle(fontSize: 12));
          }

          final messageData = snapshot.data!.docs.first.data() as Map<String, dynamic>;
          final Timestamp timestamp = messageData['timestamp'] as Timestamp;
          final formattedTime =
          DateFormat('hh:mm a').format(timestamp.toDate());

          return Text(formattedTime, 
            maxLines: 1, 
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          );
        },
      ),
      subtitle: StreamBuilder<QuerySnapshot>(
        stream: _chatService.getLastMessage(_auth.currentUser!.uid, data['uid']),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox(height: 20, child: Text('Loading...', style: TextStyle(fontSize: 12)));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Text('No message yet', style: TextStyle(fontSize: 12));
          }

          final messageData = snapshot.data!.docs.first.data() as Map<String, dynamic>;
          final lastMessage = messageData['message'] ?? '';
          final messageType = messageData['type'] as String?;
          
          if (messageType == 'image' || lastMessage.toString().contains('/image/')) {
            return const Row(
              children: [
                Icon(Icons.camera_alt_outlined, size: 20, color: Colors.blue),
                SizedBox(width: 5),
                Text('Photo', style: TextStyle(fontSize: 12)),
              ],
            );
          } else if (messageType == 'voice' || lastMessage.toString().contains('/raw/')) {
            return const Row(
              children: [
                Icon(Icons.mic, size: 20, color: Colors.blue),
                SizedBox(width: 5),
                Text('Voice message', style: TextStyle(fontSize: 12)),
              ],
            );
          } else {
            return Text(lastMessage,
              maxLines: 1, 
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            );
          }
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

