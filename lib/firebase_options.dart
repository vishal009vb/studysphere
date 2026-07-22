// File generated manually based on google-services.json

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCFxPa8y4Te186YjSqW2_A_eYaQYCKaofE',
    appId: '1:726667741250:web:9b876c4744938e725a85db',
    messagingSenderId: '726667741250',
    projectId: 'studysphere-app-3a480',
    authDomain: 'studysphere-app-3a480.firebaseapp.com',
    storageBucket: 'studysphere-app-3a480.firebasestorage.app',
    measurementId: 'G-DUMMY',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyCFxPa8y4Te186YjSqW2_A_eYaQYCKaofE',
    appId: '1:726667741250:web:9b876c4744938e725a85db', // Reusing Web app ID for Desktop
    messagingSenderId: '726667741250',
    projectId: 'studysphere-app-3a480',
    authDomain: 'studysphere-app-3a480.firebaseapp.com',
    storageBucket: 'studysphere-app-3a480.firebasestorage.app',
    measurementId: 'G-DUMMY',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCFxPa8y4Te186YjSqW2_A_eYaQYCKaofE',
    appId: '1:726667741250:android:941a22c8e0218bab5a85db',
    messagingSenderId: '726667741250',
    projectId: 'studysphere-app-3a480',
    storageBucket: 'studysphere-app-3a480.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCFxPa8y4Te186YjSqW2_A_eYaQYCKaofE',
    appId: '1:726667741250:ios:dummy', // iOS ID not in json, using dummy
    messagingSenderId: '726667741250',
    projectId: 'studysphere-app-3a480',
    storageBucket: 'studysphere-app-3a480.firebasestorage.app',
    iosBundleId: 'com.studysphere',
  );
}
