import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static const String projectId = 'serbuin-smart-loyalty-app';
  static const String messagingSenderId = '398979153007';
  static const String authDomain = 'serbuin-smart-loyalty-app.firebaseapp.com';
  static const String storageBucket = 'serbuin-smart-loyalty-app.firebasestorage.app';

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
    apiKey: 'AIzaSyAYBkgg2pFsD1ip3u6mUnBinL-XJWL6sG4',
    appId: '1:398979153007:web:297bf9fa1c205589bda19a',
    messagingSenderId: messagingSenderId,
    projectId: projectId,
    authDomain: authDomain,
    storageBucket: storageBucket,
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAYBkgg2pFsD1ip3u6mUnBinL-XJWL6sG4',
    appId: '1:398979153007:android:638e6499da073588bda19a',
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
