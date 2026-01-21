import 'package:chat_app/core/constants/app_colors.dart';
import 'package:flutter/material.dart';

class ChatBubble extends StatelessWidget {
  final String message;
  const ChatBubble({
    required this.message,
    super.key
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.blue
      ),
      child: Text(
        message,
        style: TextStyle(
          fontSize: 16,
          color: AppColors.white
        ),
      ),
    );
  }
}
