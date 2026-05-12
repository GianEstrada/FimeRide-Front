import 'package:fimeride_front/fimehub_login.dart';
import 'package:flutter/material.dart';
import 'package:fimeride_front/local_notification_service.dart';
import 'package:fimeride_front/firebase_notification_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializar Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  await LocalNotificationService.init();
  await FirebaseNotificationService.init();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const FimeHubLogin(),
    );
  }
}
