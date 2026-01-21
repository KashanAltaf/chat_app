import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';

class ChatController extends GetxController {
  final TextEditingController messageController = TextEditingController();
  RxBool hasText = false.obs;

  final ScrollController scrollController = ScrollController();

  // Lock mechanism & helpers
  RxBool isLockedToBottom = true.obs; // true = keep pinned to bottom
  int lastMessageCount = 0;
  double previousMaxScrollExtent = 0.0;
  bool hasInitialScrolled = false; // Track if we've done the initial scroll

  // threshold in px to consider "not at bottom"
  final double bottomThreshold = 120.0;

  @override
  void onInit() {
    super.onInit();
    // Reset scroll state when opening a new chat
    hasInitialScrolled = false;
    lastMessageCount = 0;
    previousMaxScrollExtent = 0.0;
    isLockedToBottom.value = true;
    
    messageController.addListener(() {
      hasText.value = messageController.text.isNotEmpty;
    });

    // Listen to user scrolls so we can unlock when user scrolls up
    scrollController.addListener(_onUserScroll);
  }

  @override
  void onClose() {
    scrollController.removeListener(_onUserScroll);
    scrollController.dispose();
    messageController.dispose();
    super.onClose();
  }

  void _onUserScroll() {
    if (!scrollController.hasClients) return;
    final pixels = scrollController.position.pixels;

    // With reverse: true, position 0 is at bottom
    // If user scrolled away from bottom (position > threshold), unlock.
    if (pixels > bottomThreshold) {
      if (isLockedToBottom.value) isLockedToBottom.value = false;
    } else {
      if (!isLockedToBottom.value) isLockedToBottom.value = true;
    }
  }

  // Call to ensure the controller scrolls appropriately after the frame updates.
  // With reverse: true, position 0 is at bottom (latest messages)
  Future<void> updateAndMaybeScroll() async {
    if (!scrollController.hasClients) return;

    // With reverse: true, we want to stay at position 0 (bottom) when locked
    if (isLockedToBottom.value) {
      final currentPosition = scrollController.position.pixels;
      // If we're not at the bottom (position 0), jump there instantly
      if (currentPosition > 0.5) {
        scrollController.jumpTo(0);
      }
    }
  }

  // Force lock and jump to bottom (position 0 with reverse: true)
  void lockAndJumpToBottom() {
    isLockedToBottom.value = true;
    if (!scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.jumpTo(0);
      }
    });
  }

  // Call from sendMessages: mark locked so that subsequent incoming snapshot will animate properly
  void markLockedBeforeSend() {
    isLockedToBottom.value = true;
  }
}
