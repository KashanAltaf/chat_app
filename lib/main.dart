import 'package:chat_app/utils/firebase_api.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:get/get.dart';
import 'firebase_options.dart';
import 'modules/home/screen/home_screen.dart';
import 'modules/login/screen/login_screen.dart';
import 'routes/app_routes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize App Check with error handling
  // This prevents app crashes if App Check fails
  try {
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.debug,
      appleProvider: AppleProvider.debug,
    );
  } catch (e) {
    // App Check errors are non-critical for development
    // They won't prevent the app from working
    debugPrint('App Check initialization failed (non-critical): $e');
  }

  await FirebaseApi().initNotifications();
  runApp(const MyApp());
}
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  String getInitialRoute() {
    final user = FirebaseAuth.instance.currentUser;
    return user == null ? LoginScreen.id : HomeScreen.id;
  }

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: getInitialRoute(),
      getPages: Routes().routeMap,
    );
  }
}