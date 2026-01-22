import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:chat_app/modules/chat/controller/chat_controller.dart';
import 'package:permission_handler/permission_handler.dart';

class VoiceRecordingDialog extends GetView<ChatController> {
  final String receiverUserId;
  final Function(String) onSend;

  const VoiceRecordingDialog({
    super.key,
    required this.receiverUserId,
    required this.onSend,
  });

  Future<bool> _ensureMicPermission() async {
    try {
      final status = await Permission.microphone.request();
      return status.isGranted;
    } catch (e) {
      debugPrint('Permission error: $e');
      try {
        final status = await Permission.microphone.status;
        return status.isGranted;
      } catch (_) {
        return false;
      }
    }
  }

  Future<void> _handleStartRecording() async {
    final ok = await _ensureMicPermission();
    if (!ok) {
      Get.snackbar('Permission Required', 'Microphone permission is required to record voice messages');
      return;
    }
    await controller.startRecording();
  }

  Future<void> _handleSend() async {
    if (!controller.isRecording.value && controller.currentTempFilePath.value == null) {
      Get.back();
      return;
    }

    await controller.stopRecording();
    final path = controller.currentTempFilePath.value;
    
    if (path != null) {
      onSend(path);
    }
    
    controller.resetRecording();
    Get.back();
  }

  Future<void> _handleCancel() async {
    await controller.stopRecording();
    controller.resetRecording();
    Get.back();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Voice Recording',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Obx(() {
              if (!controller.isRecording.value) {
                return Column(
                  children: [
                    const Icon(Icons.mic, size: 64, color: Colors.blue),
                    const SizedBox(height: 16),
                    const Text('Tap to start recording'),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _handleStartRecording,
                      icon: const Icon(Icons.mic),
                      label: const Text('Start Recording'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
                  ],
                );
              }

              return Column(
                children: [
                  Obx(() => Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: controller.isPaused.value ? Colors.red.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      controller.isPaused.value ? Icons.pause : Icons.mic,
                      size: 64,
                      color: controller.isPaused.value ? Colors.red : Colors.blue,
                    ),
                  )),
                  const SizedBox(height: 16),
                  Obx(() => Text(
                    controller.formatDuration(controller.recordingDuration.value),
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                  )),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Pause/Resume button
                      Obx(() => IconButton(
                        icon: Icon(
                          controller.isPaused.value ? Icons.play_arrow : Icons.pause,
                          size: 32,
                        ),
                        onPressed: controller.isPaused.value
                            ? () => controller.resumeRecording()
                            : () => controller.pauseRecording(),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(16),
                        ),
                      )),
                      const SizedBox(width: 24),
                      // Send button
                      IconButton(
                        icon: const Icon(Icons.send, size: 32),
                        onPressed: _handleSend,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(16),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            }),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _handleCancel,
              child: Text(
                  'Cancel',
                style: TextStyle(
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

