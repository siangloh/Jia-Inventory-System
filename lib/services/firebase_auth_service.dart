import 'package:firebase_auth/firebase_auth.dart';

class FirebaseAuthService {
  // Get the current Firebase ID token
  static Future<String?> getFirebaseToken() async {
    User? user = FirebaseAuth.instance.currentUser;
    return await user?.getIdToken();
  }
}
