import 'package:chat_app/modules/search/controller/search_controller.dart';
import 'package:chat_app/modules/settings/controller/settings_controller.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/constants/app_colors.dart';
import '../../../utils/firebase_api.dart';
import '../../login/screen/login_screen.dart';

class SettingScreen extends GetView<SettingController>{

  static const String id = '/settings';
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  SettingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Settings"),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: GestureDetector(
          onTap: () async {
            final firebaseApi = FirebaseApi();
            await firebaseApi.removeFCMTokenFromFirestore();

            // Firebase logout
            await FirebaseAuth.instance.signOut();

            // Google logout (THIS is the key)
            await _googleSignIn.signOut();

            // Clear navigation & controllers
            Get.deleteAll();
            Get.offAllNamed(LoginScreen.id);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
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
                   Icon(
                      Icons.logout,
                     size: 30,
                    ),
                    Text(
                      'Logout',
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
          ),
        ),
      ),
    );
  }

}