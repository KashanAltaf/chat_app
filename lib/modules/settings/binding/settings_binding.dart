import 'package:chat_app/modules/settings/controller/settings_controller.dart';
import 'package:get/get.dart';
import 'package:chat_app/core/network/api_client.dart';

class SettingsBinding extends Bindings {
  @override
  void dependencies() {

    Get.lazyPut<SettingController>(() => SettingController()  );

  }
}