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
    final max = scrollController.position.maxScrollExtent;
    final pixels = scrollController.position.pixels;
    final distanceFromBottom = max - pixels;

    // If user scrolled away more than the threshold, unlock.
    if (distanceFromBottom > bottomThreshold) {
      if (isLockedToBottom.value) isLockedToBottom.value = false;
    } else {
      if (!isLockedToBottom.value) isLockedToBottom.value = true;
    }
  }

  // Call to ensure the controller scrolls appropriately after the frame updates.
  // If locked => only animate when content grew; jump when content shrank or first load.
  Future<void> updateAndMaybeScroll() async {
    if (!scrollController.hasClients) return;

    final newMax = scrollController.position.maxScrollExtent;

    // First load => jump instantly without animation to avoid jerk
    if (!hasInitialScrolled && newMax > 0) {
      hasInitialScrolled = true;
      scrollController.jumpTo(newMax);
      previousMaxScrollExtent = newMax;
      return;
    }

    // After initial scroll, handle updates
    if (isLockedToBottom.value) {
      // If list grew, animate downward (no "up then down").
      if (newMax > previousMaxScrollExtent + 0.5) {
        await scrollController.animateTo(
          newMax,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
        );
      } else if (newMax < previousMaxScrollExtent - 0.5) {
        // content shrank — jump (no animation needed)
        scrollController.jumpTo(newMax);
      }
      // if newMax ≈ previous, do nothing
    }
    previousMaxScrollExtent = newMax;
  }

  // Force lock and jump to bottom (used on keyboard close)
  void lockAndJumpToBottom() {
    isLockedToBottom.value = true;
    if (!scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.jumpTo(scrollController.position.maxScrollExtent);
        previousMaxScrollExtent = scrollController.position.maxScrollExtent;
      }
    });
  }

  // Call from sendMessages: mark locked so that subsequent incoming snapshot will animate properly
  void markLockedBeforeSend() {
    isLockedToBottom.value = true;
  }
}
