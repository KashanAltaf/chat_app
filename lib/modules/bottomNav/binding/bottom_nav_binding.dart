import 'package:chat_app/modules/bottomNav/controller/bottom_nav_controller.dart';
import 'package:chat_app/modules/chat/controller/chat_controller.dart';
import 'package:chat_app/modules/home/controller/home_controller.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_instance/src/bindings_interface.dart';

import '../../login/controller/login_controller.dart';

class BottomNavBinding extends Bindings {
  @override
  void dependencies() {

    Get.lazyPut<BottomNavController>(() => BottomNavController());

  }
}