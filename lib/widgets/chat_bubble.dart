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

  /// Optional reply metadata expected shape:
  /// {
  ///   'message': '...',
  ///   'senderId': '...',
  ///   'messageId': '...',
  ///   'type': 'text' | 'image' | 'voice'
  /// }
  final Map<String, dynamic>? replyTo;
  
  /// Current user's ID to determine if reply is from "You"
  final String? currentUserId;
  
  /// Receiver's display name to show when replying to their messages
  final String? receiverUserName;
  
  /// Callback when reply preview is tapped to scroll to original message
  final VoidCallback? onReplyTap;

  const ChatBubble({
    super.key,
    required this.message,
    required this.color,
    this.radiusTopLeft = 8,
    this.radiusTopRight = 8,
    this.radiusBottomLeft = 8,
    this.radiusBottomRight = 8,
    this.replyTo,
    this.currentUserId,
    this.receiverUserName,
    this.onReplyTap,
  });

  bool get isImage =>
      message.startsWith('https://res.cloudinary.com') &&
          (message.contains('/image/upload') || message.contains('/image/upload/'));

  bool get isAudio {
    if (!message.startsWith('https://res.cloudinary.com')) return false;
    return message.contains('/raw/upload') ||
        message.endsWith('.aac') ||
        message.endsWith('.m4a') ||
        message.endsWith('.mp3') ||
        message.endsWith('.wav');
  }

  bool _isAudioUrl(String url) {
    return url.contains('/raw/upload') ||
        url.endsWith('.aac') ||
        url.endsWith('.m4a') ||
        url.endsWith('.mp3') ||
        url.endsWith('.wav');
  }

  bool _isImageUrl(String url) {
    return url.startsWith('https://res.cloudinary.com') &&
        (url.contains('/image/upload') || url.contains('/image/upload/'));
  }

  Widget _buildReplyPreview(BuildContext context) {
    if (replyTo == null) return const SizedBox.shrink();

    final String rType = (replyTo!['type'] as String?) ?? 'text';
    final String rMessage = (replyTo!['message'] as String?) ?? '';
    final String rSenderId = (replyTo!['senderId'] as String?) ?? '';

    // Prioritize explicit type; fallback to URL heuristics
    final bool isVoiceReply = rType == 'voice' || _isAudioUrl(rMessage);
    final bool isImageReply = rType == 'image' || _isImageUrl(rMessage);

    // Determine display name: "You" if sender is current user, otherwise receiver's name
    final String displayName = (currentUserId != null && rSenderId == currentUserId)
        ? 'You'
        : (receiverUserName ?? 'Unknown');

    // WhatsApp-like small quoted block
    return GestureDetector(
      onTap: onReplyTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.08),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // subtle left accent bar
            Container(width: 4, height: 44, color: Colors.white70),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Display name
                  Text(
                    displayName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  // content preview
                  if (isVoiceReply)
                    Row(
                      children: const [
                        Icon(Icons.mic, size: 16),
                        SizedBox(width: 6),
                        Text('Voice message', style: TextStyle(fontSize: 13)),
                      ],
                    )
                  else if (isImageReply)
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: CachedNetworkImage(
                            imageUrl: rMessage,
                            width: 44,
                            height: 44,
                            fit: BoxFit.cover,
                            placeholder: (c, u) =>
                                Container(width: 44, height: 44, color: Colors.grey.shade300),
                            errorWidget: (c, u, e) => Container(
                              width: 44,
                              height: 44,
                              alignment: Alignment.center,
                              child: const Icon(Icons.broken_image, size: 18),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Image',
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    )
                  else
                    Text(
                      rMessage,
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      padding: isImage || isAudio ? EdgeInsets.zero : const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(radiusTopLeft),
          topRight: Radius.circular(radiusTopRight),
          bottomLeft: Radius.circular(radiusBottomLeft),
          bottomRight: Radius.circular(radiusBottomRight),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(5.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (replyTo != null) _buildReplyPreview(context),
            isImage
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
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: message,
                  fit: BoxFit.cover,
                  placeholder: (c, u) => Container(
                    height: 180,
                    width: 180,
                    alignment: Alignment.center,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  ),
                  errorWidget: (c, u, e) => const Icon(Icons.broken_image),
                ),
              ),
            )
                : isAudio
                ? const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.audiotrack, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  'Voice message',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ],
            )
                : Text(
              message,
              style: const TextStyle(fontSize: 16, color: Colors.white),
              softWrap: true,
            ),
          ],
        ),
      ),
    );
  }
}
