import 'package:chat_app/core/constants/app_colors.dart';
import 'package:flutter/material.dart';

class ChatBubble extends StatelessWidget {
  final String message;
  final Color color;
  final double radiusTopLeft;
  final double radiusBottomLeft;
  final double radiusTopRight;
  final double radiusBottomRight;

  const ChatBubble({
    required this.message,
    required this.color,
    required this.radiusBottomLeft,
    required this.radiusBottomRight,
    required this.radiusTopLeft,
    required this.radiusTopRight,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.75, // limit bubble width
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(radiusTopRight),
          topLeft: Radius.circular(radiusTopLeft),
          bottomRight: Radius.circular(radiusBottomRight),
          bottomLeft: Radius.circular(radiusBottomLeft),
        ),
        color: color,
      ),
      child: Text(
        message,
        style: const TextStyle(
          fontSize: 16,
          color: AppColors.white,
        ),
        softWrap: true,
        overflow: TextOverflow.visible,
      ),
    );
  }
}
