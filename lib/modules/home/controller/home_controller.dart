import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

class HomeController extends GetxController {
  RxBool isTap = false.obs; // search field visible or not
  final TextEditingController searchController = TextEditingController();
  final FocusNode searchNode = FocusNode();

  RxString searchQuery = ''.obs;

  @override
  void onInit() {
    super.onInit();
    searchController.addListener(() {
      searchQuery.value = searchController.text;
    });
  }

  void toggleSearch() {
    isTap.value = !isTap.value;
    if (isTap.value) {
      // focus after UI rebuild
      Future.delayed(const Duration(milliseconds: 100), () {
        searchNode.requestFocus();
      });
    } else {
      clearSearch();
    }
  }

  void clearSearch() {
    searchController.clear();
    searchQuery.value = '';
  }
}
