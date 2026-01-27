import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

class HomeController extends GetxController {
  RxBool isTap = false.obs; // search field visible or not
  final TextEditingController searchController = TextEditingController();
  final FocusNode searchNode = FocusNode();

  RxString searchQuery = ''.obs;
  Timer? _debounceTimer;

  @override
  void onInit() {
    super.onInit();
    searchController.addListener(() {
      // Debounce search to reduce queries
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 300), () {
        searchQuery.value = searchController.text;
      });
    });
  }

  @override
  void onClose() {
    _debounceTimer?.cancel();
    searchController.dispose();
    searchNode.dispose();
    super.onClose();
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
