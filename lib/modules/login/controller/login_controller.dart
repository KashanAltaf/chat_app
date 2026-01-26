import 'dart:io';

import 'package:chat_app/modules/home/screen/home_screen.dart';
import 'package:chat_app/utils/presence_helper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:chat_app/data/services/storage_service.dart';
import 'package:chat_app/data/services/auth_service.dart';
import 'package:permission_handler/permission_handler.dart';
import '../repository/login_repository.dart';

class LoginController extends GetxController {
  final AuthService _authService = AuthService();
  final StorageService _storageService = StorageService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  var isLoading = false.obs;

  Future<void> signInWithGoogle() async {
    try {
      isLoading.value = true;
      final userCredential = await _authService.signInWithGoogle();
      if (userCredential.user != null) {
        PresenceHelper.setupUserPreference(
          _auth.currentUser!.uid,
        );
        Get.offNamed(HomeScreen.id);
        Get.snackbar(
          'Success',
          'Signed in successfully',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
        // TODO: Navigate to home screen
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to sign in: ${e.toString()}',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> requestNotificationPermission() async {
    try {
      if (Platform.isIOS) {
        final settings = await FirebaseMessaging.instance.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
        );

        if (settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional) {
          // Optionally get FCM token here:
          // final token = await FirebaseMessaging.instance.getToken();
          return true;
        } else {
          Get.snackbar('Permission', 'Notifications permission denied.');
          return false;
        }
      } else if (Platform.isAndroid) {
        // On Android < 13, notifications are allowed by default.
        // On Android 13+ (API 33+) you must request POST_NOTIFICATIONS runtime permission.
        final status = await Permission.notification.status;
        if (status.isGranted) {
          return true;
        }

        final result = await Permission.notification.request();
        if (result.isGranted) {
          return true;
        } else {
          Get.snackbar('Permission', 'Notifications permission denied.');
          return false;
        }
      } else {
        // Fallback for other platforms (web etc.)
        return true;
      }
    } catch (e, st) {
      debugPrint('requestNotificationPermission error: $e\n$st');
      Get.snackbar('Error', 'Failed to request notification permission.');
      return false;
    }
  }

}
