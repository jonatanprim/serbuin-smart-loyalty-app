import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static const String projectId = 'serbuin-smart-loyalty-app';
  static const String messagingSenderId = '398979153007';
  static const String authDomain = 'serbuin-smart-loyalty-app.firebaseapp.com';
  static const String storageBucket = 'serbuin-smart-loyalty-app.appspot.com';

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSy_SerbuinSmartLoyaltyApiKeyWebDefault',
    appId: '1:398979153007:web:8c57173b98c52089eb001a',
    messagingSenderId: messagingSenderId,
    projectId: projectId,
    authDomain: authDomain,
    storageBucket: storageBucket,
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSy_SerbuinSmartLoyaltyApiKeyAndroidDefault',
    appId: '1:398979153007:android:5fa7216c88e91823ab002b',
    messagingSenderId: messagingSenderId,
    projectId: projectId,
    storageBucket: storageBucket,
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSy_SerbuinSmartLoyaltyApiKeyIosDefault',
    appId: '1:398979153007:ios:4ab8231c77f02938cd003c',
    messagingSenderId: messagingSenderId,
    projectId: projectId,
    storageBucket: storageBucket,
    iosBundleId: 'com.serbuin.serbuinApp',
  );
}
