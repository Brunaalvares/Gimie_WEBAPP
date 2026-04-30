import 'package:firebase_core/firebase_core.dart';

class FirebaseConfig {
  // Firebase Configuration for gimie-launch
  static const String projectId = 'gimie-launch';
  static const String projectNumber = '669182239244';
  
  // Android Configuration
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDummyKeyReplaceWithYourActualKey',
    appId: '1:669182239244:android:YOUR_APP_ID',
    messagingSenderId: '669182239244',
    projectId: 'gimie-launch',
    storageBucket: 'gimie-launch.appspot.com',
  );
  
  // iOS Configuration
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDummyKeyReplaceWithYourActualIOSKey',
    appId: '1:669182239244:ios:YOUR_IOS_APP_ID',
    messagingSenderId: '669182239244',
    projectId: 'gimie-launch',
    storageBucket: 'gimie-launch.appspot.com',
    iosBundleId: 'com.gimie.app',
  );
  
  // Get Firebase Options based on platform
  static FirebaseOptions get currentPlatform {
    // This will be automatically handled by firebase_options.dart
    // when you run `flutterfire configure`
    throw UnsupportedError(
      'Please run `flutterfire configure` to generate firebase_options.dart',
    );
  }
}
