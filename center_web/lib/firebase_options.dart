import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Firebase options for center_web.
///
/// Важно: для полноценной web-конфигурации лучше прогнать `flutterfire configure`
/// из папки `center_web` и заменить значения ниже на реальные.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      // Для web можно использовать те же ключи проекта, что и для Android mobile.
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // Используем те же данные, что и в mobile/android (можно вынести в .env при желании)
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAjFzxXkd8ejk9YnuhxUU-YnaNepxIEXtk',
    appId: '1:313112928368:web:center_web_dummy_app', // можно заменить после flutterfire configure
    messagingSenderId: '313112928368',
    projectId: 'kitakitar',
    storageBucket: 'kitakitar.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAjFzxXkd8ejk9YnuhxUU-YnaNepxIEXtk',
    appId: '1:313112928368:android:center_web_dummy_app',
    messagingSenderId: '313112928368',
    projectId: 'kitakitar',
    storageBucket: 'kitakitar.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'YOUR_IOS_API_KEY_HERE',
    appId: 'YOUR_IOS_APP_ID_HERE',
    messagingSenderId: 'YOUR_MESSAGING_SENDER_ID_HERE',
    projectId: 'kitakitar',
    storageBucket: 'kitakitar.firebasestorage.app',
    iosBundleId: 'com.example.kitakitarCenterWeb',
  );
}

