import 'package:chat_app/core/constants/app_assets.dart';
import 'package:chat_app/modules/bottomNav/controller/bottom_nav_controller.dart';
import 'package:chat_app/modules/home/screen/home_screen.dart';
import 'package:chat_app/modules/search/screen/search_screen.dart';
import 'package:chat_app/modules/settings/screen/settings_screen.dart';
import 'package:chat_app/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_state_manager/src/simple/get_view.dart';

class BottomNavScreen extends GetView<BottomNavController>{

  static const String id = '/bottomNav';

  BottomNavScreen({super.key}) {
    // initialize index when widget is created
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.currentIndex.value = 0;
    });
  }


  late List<Widget> widgetList = [
    HomeScreen(),
    SearchScreen(),
    SettingScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Obx(
            () => Scaffold(
          backgroundColor: Colors.white,
          body: widgetList[controller.currentIndex.value],
          bottomNavigationBar: BottomNavigationBar(
            key: ValueKey(controller.currentIndex.value),
            backgroundColor: Colors.white,
            elevation: 2,
            selectedItemColor: Colors.black,
            unselectedItemColor: Colors.black.withOpacity(0.5),
            selectedIconTheme: IconThemeData(
              color: Colors.black
            ),
            unselectedIconTheme: IconThemeData(
              color: Colors.black.withOpacity(0.5),
            ),
            selectedLabelStyle: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
            unselectedLabelStyle: TextStyle(
              fontWeight: FontWeight.w400,
              fontSize: 16,
              color: Colors.black.withOpacity(0.5),
            ),
            onTap: (index) async {
                controller.onTapped(index);
                controller.lastIndex = index;
            },
            currentIndex: controller.currentIndex.value,
            items: [
              BottomNavigationBarItem(
                icon: Image.asset(
                  AppAssets.iconHomeUnselected,
                  height: 24,
                  width: 24,
                  color: Colors.black.withOpacity(0.5),
                ),
                activeIcon: Image.asset(
                  AppAssets.iconHomeSelected,
                  height: 24,
                  width: 24,
                  color: Colors.black,
                ),
                label: "Home",
              ),
              BottomNavigationBarItem(
                icon: Image.asset(
                  AppAssets.iconSearchUnselected,
                  height: 24,
                  width: 24,
                  color: Colors.black.withOpacity(0.5),
                ),
                activeIcon: Image.asset(
                  AppAssets.iconSearchSelected,
                  height: 24,
                  width: 24,
                  color: Colors.black,
                ),
                label: "Search",
              ),
              BottomNavigationBarItem(
                icon: Image.asset(
                  AppAssets.iconSettingsUnselected,
                  height: 24,
                  width: 24,
                  color: Colors.black.withOpacity(0.5),
                ),
                activeIcon: Image.asset(
                  AppAssets.iconSettingsSelected,
                  height: 24,
                  width: 24,
                  color: Colors.black,
                ),
                label: "Settings"
              ),
            ],
          ),
        ),
      ),
    );
  }
}