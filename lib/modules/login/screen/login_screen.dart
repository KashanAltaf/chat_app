import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:chat_app/core/constants/app_colors.dart';
import '../../../core/constants/app_assets.dart';
import '../controller/login_controller.dart';

class LoginScreen extends GetView<LoginController> {
  static const String id = '/login';
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock,
              size: 80,
              color: AppColors.background,
            ),
            SizedBox(height: 20,),
            Text(
              'Welcome back you\'ve been missed',
              style: TextStyle(
                fontSize: 16
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Obx(() => GestureDetector(
                onTap: controller.isLoading.value
                    ? null
                    : () async {
                  // Ask permission first
                  final granted = await controller.requestNotificationPermission();
                  if (granted) {
                    // proceed with sign in
                    controller.signInWithGoogle();
                  } else {
                    // Optional: still let user sign in even without permission:
                    // controller.signInWithGoogle();
                  }
                },
                child: Container(
                  height: 51,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: AppColors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        spreadRadius: 2,
                        blurRadius: 6
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        controller.isLoading.value
                            ? SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.background,
                                  ),
                                ),
                              )
                            : Image.asset(
                                AppAssets.iconGoogle,
                                height: 24,
                                width: 24,
                              ),
                        Text(
                          'Continue with Google',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w400
                          ),
                        ),
                        SizedBox.shrink(),
                      ],
                    ),
                  ),
                ),
              )),
            ),
          ],
        ),
      ),
    );
  }
}