import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'voice_chat_controller.dart';

class VoiceChat extends GetView<VoiceChatController> {
  final QueryDocumentSnapshot<Object?> data;
  const VoiceChat({required this.data, super.key});

  @override
  Widget build(BuildContext context) {
    Get.put(VoiceChatController());
    
    final currentUser = FirebaseAuth.instance.currentUser!;
    final receiverId = data['uid'];

    List<String> ids = [currentUser.uid, receiverId];
    ids.sort();
    final chatRoomId = ids.join('_');

    return Scaffold(
      appBar: AppBar(title: const Text('Voice Chat')),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chat_rooms')
                  .doc(chatRoomId)
                  .collection('messages')
                  .orderBy('timestamp')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                var docs = snapshot.data!.docs;
                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var msg = docs[index];
                    bool isMe = msg['senderId'] == currentUser.uid;

                    if (msg['type'] == 'voice') {
                      return ListTile(
                        title: Text(isMe ? 'You' : 'Friend'),
                        trailing: IconButton(
                          icon: const Icon(Icons.play_arrow),
                          onPressed: () => controller.playAudio(msg['message']),
                        ),
                      );
                    }

                    return const SizedBox.shrink();
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Obx(() => Row(
              children: [
                IconButton(
                  icon: Icon(controller.isRecording.value ? Icons.stop : Icons.mic),
                  onPressed: () async {
                    if (controller.isRecording.value) {
                      final path = await controller.stopRecording();
                      if (path != null) await controller.sendVoiceMessage(path, receiverId);
                    } else {
                      await controller.startRecording();
                    }
                  },
                ),
                const SizedBox(width: 10),
                Text(controller.isRecording.value ? 'Recording...' : 'Press to record'),
              ],
            )),
          ),
        ],
      ),
    );
  }
}
