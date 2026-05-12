import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDgXXXXXXXXXXXXXXXXXXXXXXX',
    appId: '1:123456789:android:abcdefghijklmnop',
    messagingSenderId: '123456789',
    projectId: 'fimeride-project',
    databaseURL: 'https://fimeride-project.firebaseio.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDgXXXXXXXXXXXXXXXXXXXXXXX',
    appId: '1:123456789:ios:abcdefghijklmnop',
    messagingSenderId: '123456789',
    projectId: 'fimeride-project',
    databaseURL: 'https://fimeride-project.firebaseio.com',
    iosBundleId: 'com.example.fimeride',
  );

  static FirebaseOptions get currentPlatform {
    return android;
  }
}
