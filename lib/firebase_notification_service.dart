import 'package:firebase_messaging/firebase_messaging.dart';
import 'local_notification_service.dart';

class FirebaseNotificationService {
  FirebaseNotificationService._();

  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  static Future<void> init() async {
    // Solicitar permisos (iOS)
    await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: true,
      badge: true,
      carryForwardToken: true,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    // Manejar notificaciones cuando la app está en foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('🔔 Notificación en foreground: ${message.notification?.title}');
      _mostrarNotificacion(message);
    });

    // Manejar notificaciones cuando el usuario toca la notificación
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('👆 Notificación tocada: ${message.notification?.title}');
    });

    // Manejar notificaciones cuando la app está cerrada (background)
    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        print('📱 App abierta desde notificación: ${message.notification?.title}');
      }
    });

    // Obtener FCM token (para enviar notificaciones desde backend)
    String? fcmToken = await _firebaseMessaging.getToken();
    print('🔑 FCM Token: $fcmToken');
  }

  static void _mostrarNotificacion(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    LocalNotificationService.show(
      id: message.hashCode,
      title: notification.title ?? 'FimeRide',
      body: notification.body ?? '',
    );
  }

  static Future<String?> getFCMToken() async {
    return _firebaseMessaging.getToken();
  }
}
