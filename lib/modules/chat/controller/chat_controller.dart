import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

class ChatController extends GetxController{
  final TextEditingController messageController = TextEditingController();
  RxBool hasText = false.obs;

  @override
  void onInit() {
    super.onInit();
    messageController.addListener(() {
      hasText.value = messageController.text.isNotEmpty;
    });
  }
}