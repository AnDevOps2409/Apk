// File được tạo thủ công từ google-services.json
// project_id: stock-154a6

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web - '
        'you can reconfigure this by running the FlutterFire CLI again.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for ios - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDJVTQkyTT9hqg9-Bum4MXh7nUHZswLk9c',
    appId: '1:77598238528:android:6558e8ff19c7b6950f3ca5',
    messagingSenderId: '77598238528',
    projectId: 'stock-154a6',
    storageBucket: 'stock-154a6.firebasestorage.app',
    databaseURL: 'https://stock-154a6-default-rtdb.asia-southeast1.firebasedatabase.app',
  );
}
