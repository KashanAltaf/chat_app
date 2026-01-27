import 'package:cached_network_image/cached_network_image.dart';
import 'package:chat_app/modules/search/controller/search_controller.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../data/services/chat_service.dart';
import '../../chat/screen/chat_screen.dart';

class SearchScreen extends GetView<SearchingController>{

  static const String id = '/search';


  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ChatService _chatService = ChatService();

  SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Search'),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextFormField(
              controller: controller.controller,
              onChanged: (value) {
                controller.searchQuery.value = value;
              },
              decoration: InputDecoration(
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.blue, width: 2),
                  borderRadius: BorderRadius.circular(40),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(40),
                  borderSide: BorderSide(color: Colors.black, width: 1),
                ),
                hintText: "Search all of the contacts in the app",
                hintStyle: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: Colors.black.withOpacity(0.5),
                ),
                suffixIcon: _buildSuffixIcon(),
              ),
            ),
          ),
          Expanded(
            child: Obx(() {
              final searchQuery = controller.searchQuery.value;
              final currentUserId = _auth.currentUser?.uid;
              
              // Show recent searches when search query is empty
              if (searchQuery.isEmpty) {
                return _buildRecentSearches();
              }

              // Show search results when query is not empty
              // Get all users and filter out those with messages
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

                  // Get all users first
                  final allUsers = usersSnapshot.data!.docs;

                  // Filter users: exclude current user and apply search filter
                  final filteredDocs = allUsers.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final userId = data['uid'] as String?;
                    
                    if (userId == null || userId == currentUserId) return false;

                    // Apply search filter dynamically as user types (Twitter-like: matches anywhere in name)
                    final name = (data['name'] ?? '').toLowerCase();
                    final query = searchQuery.toLowerCase();
                    if (!name.contains(query)) return false;

                    return true;
                  }).toList();

                  if (filteredDocs.isEmpty) {
                    return const Center(child: Text('No contact found'));
                  }

                  // Build list items - only show users without messages
                  // Users with messages will be filtered out (they appear in home screen)
                  return ListView(
                    children: filteredDocs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final userId = data['uid'] as String;
                      // Check if this user has messages with current user
                      return StreamBuilder<QuerySnapshot>(
                        stream: _chatService.getLastMessage(currentUserId ?? '', userId),
                        builder: (context, messagesSnapshot) {
                          // Only show if messages collection is empty or doesn't exist
                          if (messagesSnapshot.hasData && 
                              messagesSnapshot.data!.docs.isEmpty) {
                            // No messages - show in search screen
                            return _buildUserListItem(context, doc);
                          }
                          // Hide users with messages - they should appear in home screen
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

  Widget _buildRecentSearches() {
    return Obx(() {
      if (controller.recentSearches.isEmpty) {
        return const Center(
          child: Text(
            'No recent searches',
            style: TextStyle(color: Colors.grey),
          ),
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent searches',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: controller.clearRecentSearches,
                  child: const Text('Clear all'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: controller.recentSearches.length,
              itemBuilder: (context, index) {
                final searchTerm = controller.recentSearches[index];
                return ListTile(
                  leading: const Icon(Icons.search, color: Colors.grey),
                  title: Text(searchTerm),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => controller.removeRecentSearch(searchTerm),
                  ),
                  onTap: () {
                    controller.controller.text = searchTerm;
                    controller.searchQuery.value = searchTerm;
                  },
                );
              },
            ),
          ),
        ],
      );
    });
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
      onTap: () {
        // Add search query to recent searches
        final searchQuery = controller.searchQuery.value;
        if (searchQuery.isNotEmpty) {
          controller.addToRecentSearches(searchQuery);
        }
        
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