import 'package:chat_app/modules/bottomNav/binding/bottom_nav_binding.dart';
import 'package:chat_app/modules/bottomNav/screen/bottom_nav_screen.dart';
import 'package:chat_app/modules/chat/binding/chat_binding.dart';
import 'package:chat_app/modules/home/binding/home_binding.dart';
import 'package:chat_app/modules/search/binding/search_binding.dart';
import 'package:chat_app/modules/search/screen/search_screen.dart';
import 'package:chat_app/modules/settings/binding/settings_binding.dart';
import 'package:chat_app/modules/settings/screen/settings_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:chat_app/modules/login/binding/login_binding.dart';
import 'package:chat_app/modules/login/screen/login_screen.dart';

import '../modules/chat/screen/chat_screen.dart';
import '../modules/home/screen/home_screen.dart';


class Routes {
  static final Routes _sharedInstance = Routes._internal();

  factory Routes() {
    return _sharedInstance;
  }

  Routes._internal();

  //Define Routes Below
  String getLoginScreen() => LoginScreen.id;
  
  List<GetPage> routeMap = [
    GetPage(
      name: LoginScreen.id,
      binding: LoginBinding(),
      page: () => const LoginScreen(),
      transition: Transition.rightToLeft,
    ),

    GetPage(
      name: HomeScreen.id,
      binding: HomeBinding(),
      page: () => HomeScreen(),
      transition: Transition.rightToLeft,
    ),

    GetPage(
      name: ChatScreen.id,
      binding: ChatBinding(),
      page: () => ChatScreen(),
      transition: Transition.rightToLeft,
    ),

    GetPage(
      name: BottomNavScreen.id,
      binding: BottomNavBinding(),
      page: () => BottomNavScreen(),
      transition: Transition.rightToLeft,
    ),

    GetPage(
      name: SearchScreen.id,
      binding: SearchBinding(),
      page: () => SearchScreen(),
      transition: Transition.rightToLeft,
    ),

    GetPage(
      name: SettingScreen.id,
      binding: SettingsBinding(),
      page: () => SettingScreen(),
      transition: Transition.rightToLeft,
    ),
    
  ];
}
