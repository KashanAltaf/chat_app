import 'package:chat_app/modules/home/screen/home_screen.dart';
import 'package:chat_app/utils/presence_helper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:chat_app/data/services/storage_service.dart';
import 'package:chat_app/data/services/auth_service.dart';
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
}
