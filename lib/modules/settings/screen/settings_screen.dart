import 'package:chat_app/modules/search/controller/search_controller.dart';
import 'package:chat_app/modules/settings/controller/settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:get/get.dart';

class SettingScreen extends GetView<SettingController>{

  static const String id = '/settings';

  const SettingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Settings"),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
    );
  }

}