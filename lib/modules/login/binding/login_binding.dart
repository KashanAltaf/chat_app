import 'package:get/get.dart';
import 'package:chat_app/core/network/api_client.dart';
import '../controller/login_controller.dart';
import '../repository/login_repository.dart';

class LoginBinding extends Bindings {
  @override
  void dependencies() {

    Get.lazyPut<LoginController>(() => LoginController()  );

  }
}