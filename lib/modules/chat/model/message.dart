import 'package:cloud_firestore/cloud_firestore.dart';

class Message{
  final String senderId;
  final String senderEmail;
  final String receiverId;
  final String message;
  final Timestamp timestamp;
  final String? type; // 'text' | 'image' | 'voice'

  Message({
    required this.senderEmail,
    required this.senderId,
    required this.receiverId,
    required this.message,
    required this.timestamp,
    this.type,
  });

  //convert to a Map
  Map<String, dynamic> toMap(){
    final map = {
      'senderId' : senderId,
      'senderEmail' : senderEmail,
      'receiverId' : receiverId,
      'message' : message,
      'timestamp' : timestamp,
    };
    if (type != null) {
      map['type'] = type!;
    }
    return map;
  }
}