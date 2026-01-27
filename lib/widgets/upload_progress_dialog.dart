import 'package:flutter/material.dart';
import 'package:get/get.dart';

class UploadProgressController extends GetxController {
  final RxDouble progress = 0.0.obs;
  final RxBool isCancelled = false.obs;
  
  void updateProgress(double value) {
    progress.value = value.clamp(0.0, 1.0);
  }
  
  void cancel() {
    isCancelled.value = true;
  }
  
  void reset() {
    progress.value = 0.0;
    isCancelled.value = false;
  }
}

class UploadProgressDialog extends StatelessWidget {
  final UploadProgressController controller;
  final VoidCallback? onCancel;

  const UploadProgressDialog({
    super.key,
    required this.controller,
    this.onCancel,
  });

  static UploadProgressController show({VoidCallback? onCancel}) {
    final progressController = UploadProgressController();
    
    Get.dialog(
      WillPopScope(
        onWillPop: () async => false, // Prevent closing by back button
        child: UploadProgressDialog(
          controller: progressController,
          onCancel: onCancel,
        ),
      ),
      barrierDismissible: false,
    );
    
    return progressController;
  }

  static void dismiss() {
    if (Get.isDialogOpen ?? false) {
      Get.back();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      contentPadding: const EdgeInsets.all(24),
      content: Obx(() => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Uploading',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          LinearProgressIndicator(
            value: controller.progress.value,
            minHeight: 8,
            backgroundColor: Colors.grey.shade300,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
          ),
          const SizedBox(height: 8),
          Text(
            '${(controller.progress.value * 100).toStringAsFixed(0)}%',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 20),
          TextButton(
            onPressed: () {
              controller.cancel();
              onCancel?.call();
              dismiss();
            },
            child: const Text('Cancel'),
          ),
        ],
      )),
    );
  }
}

