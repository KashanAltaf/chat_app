import 'package:chat_app/utils/firebase_api.dart';
import 'package:chat_app/utils/presence_helper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

class BottomNavController extends GetxController{
  RxInt currentIndex = 0.obs;
  int lastIndex = 0;
  RxInt selectedOption = 0.obs;

  @override
  void onInit() {
    super.onInit();
    // Ensure FCM token is saved when app starts with logged-in user
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Setup presence
      PresenceHelper.setupUserPreference(user.uid);
      // Ensure FCM token is saved
      FirebaseApi().ensureFCMTokenSaved();
    }
  }

  void onTapped(var index){
    currentIndex.value = index;
  }
}