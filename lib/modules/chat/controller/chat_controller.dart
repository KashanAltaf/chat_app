// lib/modules/chat/controller/chat_controller.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:just_audio/just_audio.dart' as ja;

import '../../../utils/waveform_utils.dart';

class ChatController extends GetxController {
  final TextEditingController messageController = TextEditingController();
  RxBool hasText = false.obs;
  RxBool isPlaying = false.obs;

  final ScrollController scrollController = ScrollController();

  RxList<double> recordedWaveform = <double>[].obs;

  // Lock mechanism & helpers
  RxBool isLockedToBottom = true.obs; // true = keep pinned to bottom
  int lastMessageCount = 0;
  double previousMaxScrollExtent = 0.0;
  bool hasInitialScrolled = false; // Track if we've done the initial scroll

  // threshold in px to consider "not at bottom"
  final double bottomThreshold = 120.0;

  // Audio playback state (use just_audio aliased as ja)
  final ja.AudioPlayer player = ja.AudioPlayer();
  RxnString currentPlayingUrl = RxnString();
  RxBool isLoading = false.obs;
  RxBool isPause = false.obs;
  RxInt audioDuration = 0.obs; // in seconds
  RxInt audioPosition = 0.obs; // in seconds

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

  // Stream subscriptions (nullable)
  StreamSubscription<ja.PlayerState>? _playerStateSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;

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

    // Setup player listeners ONCE to keep UI in sync with actual playback
    _playerStateSub = player.playerStateStream.listen((playerState) {
      final playing = playerState.playing;
      final processing = playerState.processingState;

      // Buffering/loading -> treat as loading; show pause icon if playing or buffering
      isLoading.value = (processing == ja.ProcessingState.buffering) ||
          (processing == ja.ProcessingState.loading);

      // isPlaying = actual playing OR buffering (so icon remains pause while buffering)
      isPlaying.value = playing || isLoading.value;

      // If playback completed, reset
      if (processing == ja.ProcessingState.completed) {
        // schedule reset to allow UI to settle
        Future.microtask(() => _onPlaybackComplete());
      }
    });

    // Position & duration streams to update progress
    _positionSub = player.positionStream.listen((pos) {
      audioPosition.value = pos.inSeconds;
    });

    _durationSub = player.durationStream.listen((dur) {
      audioDuration.value = dur?.inSeconds ?? 0;
    });

    // Note: recorder initialization is lazy via ensureRecorderInitialized()
  }

  Future<void> _onPlaybackComplete() async {
    try {
      // Stop playback to ensure it doesn't auto-restart or loop.
      await player.stop();
    } catch (_) {}

    // Reset UI state
    isPlaying.value = false;
    isLoading.value = false;
    isPause.value = false;
    currentPlayingUrl.value = null;
    audioPosition.value = 0;
    audioDuration.value = 0;
  }


  @override
  void onClose() {
    scrollController.removeListener(_onUserScroll);
    scrollController.dispose();
    messageController.dispose();

    _playerStateSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();

    player.dispose();
    _stopRecordingTimer();
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
      final path = await recorder.stopRecorder();
      isRecording.value = false;
      isPaused.value = false;

      if (path != null) {
        recordedWaveform.value = await WaveformUtils.extractWaveform(File(path));
      }
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

  /// Ensure recorder is initialized. Returns true if successful, false otherwise.
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

  // -----------------------------
  // AUDIO PLAYBACK API (robust)
  // -----------------------------

  /// Play or toggle the given url for a messageId.
  /// If a different audio is playing, it will stop and start the new one.
  Future<void> playOrToggle(String url) async {
    try {
      // If different audio requested -> start fresh
      if (currentPlayingUrl.value != url) {
        isLoading.value = true;

        // Stop previous
        try {
          await player.stop();
        } catch (_) {}

        // Assign current and set source
        currentPlayingUrl.value = url;
        // use aliased AudioSource from just_audio
        await player.setAudioSource(ja.AudioSource.uri(Uri.parse(url)));
        try {
          await player.setLoopMode(ja.LoopMode.off);
        } catch (_) {}
        await player.play();
        // Note: isPlaying/isLoading will be updated by playerStateStream listener
      } else {
        // Same url: toggle play/pause
        if (player.playing) {
          await player.pause();
        } else {
          await player.play();
        }
      }
    } catch (e) {
      debugPrint('Playback error: $e');
      // Reset on failure
      currentPlayingUrl.value = null;
      isLoading.value = false;
      isPlaying.value = false;
      audioPosition.value = 0;
      audioDuration.value = 0;
    }
  }

  Future<void> pausePlayer() async {
    try {
      await player.pause();
    } catch (e) {
      debugPrint('pause error: $e');
    }
  }

  Future<void> resumePlayer() async {
    try {
      await player.play();
    } catch (e) {
      debugPrint('resume error: $e');
    }
  }

  Future<void> stopPlayer() async {
    try {
      await player.stop();
    } catch (e) {
      debugPrint('stop error: $e');
    } finally {
      // immediate UI reset
      isPlaying.value = false;
      isLoading.value = false;
      isPause.value = false;
      currentPlayingUrl.value = null;
      audioPosition.value = 0;
      audioDuration.value = 0;
    }
  }

  /// Seek by seconds (seconds -> double)
  Future<void> seekSeconds(double seconds) async {
    try {
      final ms = (seconds * 1000).toInt();
      await player.seek(Duration(milliseconds: ms));
    } catch (e) {
      debugPrint('seek error: $e');
    }
  }

  /// Legacy wrapper - kept for compatibility
  Future<void> playPauseAudio(String url) async {
    await playOrToggle(url);
  }

  // Keep old changeSeek signature for compatibility with UI controls
  void changeSeek(double value) {
    final duration = Duration(seconds: value.toInt());
    player.seek(duration);
    audioPosition.value = value.toInt();
  }
}
