import 'package:get/get.dart';

class BottomNavController extends GetxController{
  RxInt currentIndex = 0.obs;
  int lastIndex = 0;
  RxInt selectedOption = 0.obs;

  void onTapped(var index){
    currentIndex.value = index;
  }
}