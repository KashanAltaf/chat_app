import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'image_downloader.dart';
import 'image_preview_screen.dart';

class ChatBubble extends StatelessWidget {
  final String message;
  final Color color;
  final double radiusTopLeft;
  final double radiusTopRight;
  final double radiusBottomLeft;
  final double radiusBottomRight;

  const ChatBubble({
    super.key,
    required this.message,
    required this.color,
    this.radiusTopLeft = 8,
    this.radiusTopRight = 8,
    this.radiusBottomLeft = 8,
    this.radiusBottomRight = 8,
  });

  bool get isImage => message.startsWith('https://res.cloudinary.com');

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      padding: isImage ? EdgeInsets.zero : const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isImage ? Colors.transparent : color,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(radiusTopLeft),
          topRight: Radius.circular(radiusTopRight),
          bottomLeft: Radius.circular(radiusBottomLeft),
          bottomRight: Radius.circular(radiusBottomRight),
        ),
      ),
      child: isImage
          ? GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ImagePreviewScreen(imageUrl: message),
            ),
          );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CachedNetworkImage(
            imageUrl: message,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              height: 180,
              width: 180,
              alignment: Alignment.center,
              child: const CircularProgressIndicator(strokeWidth: 2),
            ),
            errorWidget: (context, url, error) =>
            const Icon(Icons.broken_image),
          ),
        ),
      )
          : Text(
              message,
              style: const TextStyle(fontSize: 16, color: Colors.white),
              softWrap: true,
            ),
    );
  }
}
