import 'package:firebase_core/firebase_core.dart';

/// Paste the values from your Firebase project here (Project settings > General > Your apps > Web app,
/// and Cloud Messaging > Web configuration for the key pair). Leave them empty to run the app without
/// push notifications: nothing else changes.
class FirebaseConfig {
  static const String apiKey = 'AIzaSyBa-82bVCjm2jfu_o5EiGie93AfH_Dqlbo';
  static const String authDomain = 'annual-leave-15b6e.firebaseapp.com';
  static const String projectId = 'annual-leave-15b6e';
  static const String storageBucket = 'annual-leave-15b6e.firebasestorage.app';
  static const String messagingSenderId = '554338128675';
  static const String appId = '1:554338128675:web:13bea11b38450c1ba2b296';

  /// Cloud Messaging > Web configuration > "Key pair" (public key).
  static const String vapidKey = 'BHwVaCW4vu0Nvf1GL0p9M8m1XbwMbqLUzD9Z69JwaMW3FTZzf8D5j4l_zSPtJNNHubVr1LaexDgAPQXH1y5V2xw';

  static bool get isConfigured =>
      apiKey.isNotEmpty &&
      projectId.isNotEmpty &&
      messagingSenderId.isNotEmpty &&
      appId.isNotEmpty &&
      vapidKey.isNotEmpty;

  static FirebaseOptions get options => const FirebaseOptions(
        apiKey: apiKey,
        authDomain: authDomain,
        projectId: projectId,
        storageBucket: storageBucket,
        messagingSenderId: messagingSenderId,
        appId: appId,
      );
}
