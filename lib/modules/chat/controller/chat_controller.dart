import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';

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

  // Audio playback state
  final AudioPlayer player = AudioPlayer();
  RxnString currentPlayingUrl = RxnString();
  RxBool isPlaying = false.obs;
  RxBool isLoading = false.obs;
  RxBool isPause = false.obs;
  RxInt audioDuration = 0.obs; // in seconds
  RxInt audioPosition = 0.obs; // in seconds
  Timer? _positionTimer;

  // Recorder state
  final FlutterSoundRecorder recorder = FlutterSoundRecorder();
  RxBool recorderInitialized = false.obs;
  RxBool isRecording = false.obs;
  RxBool isPaused = false.obs;
  RxnString currentTempFilePath = RxnString();
  RxInt recordingDuration = 0.obs; // in seconds
  bool _isInitializing = false;
  Timer? _recordingTimer;

  // Swipe gesture state
  RxBool swipeExpanded = false.obs;
  double swipeStartX = 0.0;
  bool isSwiping = false;
  static const double swipeThreshold = 30.0; // pixels to trigger swipe

  void handleSwipeStart(double startX) {
    swipeStartX = startX;
    isSwiping = false;
  }

  void handleSwipeUpdate(double currentX) {
    final deltaX = currentX - swipeStartX;
    
    // Only process if movement is significant
    if (deltaX.abs() > 5) {
      isSwiping = true;
    }
    
    // Swipe left to expand (show photo icon)
    if (deltaX < -swipeThreshold && !swipeExpanded.value) {
      swipeExpanded.value = true;
      swipeStartX = currentX; // Reset start position
    } 
    // Swipe right to collapse (hide photo icon)
    else if (deltaX > swipeThreshold && swipeExpanded.value) {
      swipeExpanded.value = false;
      swipeStartX = currentX; // Reset start position
    }
  }

  void handleSwipeEnd() {
    swipeStartX = 0.0;
    isSwiping = false;
  }
  
  bool shouldBlockTap() => isSwiping;

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
    
    // Initialize recorder lazily when needed (not in onInit to avoid blocking)
  }

  /// Ensures recorder is initialized. Returns true if successful, false otherwise.
  Future<bool> ensureRecorderInitialized() async {
    if (recorderInitialized.value) return true;
    if (_isInitializing) {
      // Wait for ongoing initialization
      int attempts = 0;
      while (_isInitializing && attempts < 10) {
        await Future.delayed(const Duration(milliseconds: 100));
        attempts++;
      }
      return recorderInitialized.value;
    }

    _isInitializing = true;
    try {
      debugPrint('Initializing recorder...');
      
      await recorder.openRecorder();
      await recorder.setSubscriptionDuration(const Duration(milliseconds: 200));
      recorderInitialized.value = true;
      debugPrint('Recorder initialized successfully');
      _isInitializing = false;
      return true;
    } catch (e, stackTrace) {
      debugPrint('Failed to initialize recorder: $e');
      debugPrint('Stack trace: $stackTrace');
      recorderInitialized.value = false;
      _isInitializing = false;
      
      // Check if it's a plugin registration issue
      final errorMessage = e.toString();
      if (errorMessage.contains('MissingPluginException') || 
          errorMessage.contains('No implementation found')) {
        debugPrint('Plugin not registered. Full app restart required (not hot reload).');
        return false;
      }
      
      // Retry once after a delay for other errors
      try {
        debugPrint('Retrying recorder initialization...');
        await Future.delayed(const Duration(milliseconds: 1000));
        
        await recorder.openRecorder();
        await recorder.setSubscriptionDuration(const Duration(milliseconds: 200));
        recorderInitialized.value = true;
        debugPrint('Recorder initialized on retry');
        return true;
      } catch (retryError) {
        debugPrint('Recorder initialization retry also failed: $retryError');
        return false;
      }
    }
  }

  @override
  void onClose() {
    scrollController.removeListener(_onUserScroll);
    scrollController.dispose();
    messageController.dispose();
    player.dispose();
    _stopRecordingTimer();
    _stopPositionTimer();
    if (recorderInitialized.value) {
      recorder.closeRecorder();
    }
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

  // Recording dialog methods
  Future<String> _getTempFilePath() async {
    final dir = await getTemporaryDirectory();
    final fileName = 'voice_${DateTime.now().millisecondsSinceEpoch}.aac';
    return '${dir.path}/$fileName';
  }

  Future<void> startRecording() async {
    if (isRecording.value) return;
    
    final initialized = await ensureRecorderInitialized();
    if (!initialized) {
      Get.snackbar('Error', 'Microphone not available. Please restart the app.');
      return;
    }

    try {
      final path = await _getTempFilePath();
      currentTempFilePath.value = path;
      await recorder.startRecorder(toFile: path, codec: Codec.aacADTS);
      isRecording.value = true;
      isPaused.value = false;
      recordingDuration.value = 0;
      _startRecordingTimer();
    } catch (e) {
      debugPrint('Failed to start recording: $e');
      Get.snackbar('Recording Error', 'Failed to start recording. Please try again.');
    }
  }

  Future<void> pauseRecording() async {
    if (!isRecording.value || isPaused.value) return;
    try {
      await recorder.pauseRecorder();
      isPaused.value = true;
      _stopRecordingTimer();
    } catch (e) {
      debugPrint('Failed to pause recording: $e');
    }
  }

  Future<void> resumeRecording() async {
    if (!isRecording.value || !isPaused.value) return;
    try {
      await recorder.resumeRecorder();
      isPaused.value = false;
      _startRecordingTimer();
    } catch (e) {
      debugPrint('Failed to resume recording: $e');
    }
  }

  Future<void> stopRecording() async {
    _stopRecordingTimer();
    if (!isRecording.value) return;
    try {
      await recorder.stopRecorder();
      isRecording.value = false;
      isPaused.value = false;
    } catch (e) {
      debugPrint('Failed to stop recording: $e');
    }
  }

  void _startRecordingTimer() {
    _stopRecordingTimer();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      recordingDuration.value++;
    });
  }

  void _stopRecordingTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = null;
  }

  void resetRecording() {
    _stopRecordingTimer();
    isRecording.value = false;
    isPaused.value = false;
    recordingDuration.value = 0;
    currentTempFilePath.value = null;
  }

  String formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  // Audio playback methods
  Future<void> startPlayer(String url) async {
    try {
      isLoading.value = true;
      
      if (currentPlayingUrl.value != url) {
        await player.setUrl(url);
        currentPlayingUrl.value = url;
        audioPosition.value = 0;
      }
      
      await player.play();
      isPlaying.value = true;
      isPause.value = false;
      isLoading.value = false;
      
      // Get duration
      final duration = player.duration ?? Duration.zero;
      audioDuration.value = duration.inSeconds;
      
      _startPositionTimer();
      
      // Listen for completion
      player.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          stopPlayer();
        }
      });
    } catch (e) {
      debugPrint('Playback error: $e');
      isLoading.value = false;
      isPlaying.value = false;
    }
  }

  Future<void> pausePlayer() async {
    await player.pause();
    isPlaying.value = false;
    isPause.value = true;
    _stopPositionTimer();
  }

  Future<void> resumePlayer() async {
    await player.play();
    isPlaying.value = true;
    isPause.value = false;
    _startPositionTimer();
  }

  Future<void> stopPlayer() async {
    await player.stop();
    isPlaying.value = false;
    isPause.value = false;
    currentPlayingUrl.value = null;
    audioPosition.value = 0;
    audioDuration.value = 0;
    _stopPositionTimer();
  }

  // Legacy method for backward compatibility - uses GetX reactive variables
  Future<void> playPauseAudio(String url) async {
    // If same audio is playing, pause it
    if (currentPlayingUrl.value == url && isPlaying.value) {
      await pausePlayer();
      return;
    }
    
    // If same audio is paused, resume it
    if (currentPlayingUrl.value == url && isPause.value) {
      await resumePlayer();
      return;
    }
    
    // If different audio or no audio playing, start new
    await startPlayer(url);
  }

  void changeSeek(double value) {
    final duration = Duration(seconds: value.toInt());
    player.seek(duration);
    audioPosition.value = value.toInt();
  }

  void _startPositionTimer() {
    _stopPositionTimer();
    _positionTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (player.position.inSeconds != audioPosition.value) {
        audioPosition.value = player.position.inSeconds;
      }
      if (player.duration != null && player.duration!.inSeconds != audioDuration.value) {
        audioDuration.value = player.duration!.inSeconds;
      }
    });
  }

  void _stopPositionTimer() {
    _positionTimer?.cancel();
    _positionTimer = null;
  }
}
