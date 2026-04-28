
import 'package:fimeride_front/fimehub_login.dart';
import 'package:flutter/material.dart';
import 'package:fimeride_front/local_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalNotificationService.init();
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