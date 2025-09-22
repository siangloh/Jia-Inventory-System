import 'package:local_auth/local_auth.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BiometricAuthService {
  final LocalAuthentication auth = LocalAuthentication();

  Future<bool> authenticateWithBiometrics() async {
    try {
      final bool canAuthenticateWithBiometrics =
          await auth.canCheckBiometrics || await auth.isDeviceSupported();

      if (!canAuthenticateWithBiometrics) {
        print("Biometric authentication not available.");
        return false;
      }

      final bool didAuthenticate = await auth.authenticate(
        localizedReason: 'Please authenticate to continue',
        options: const AuthenticationOptions(
          biometricOnly: true,
        ),
      );

      return didAuthenticate;
    } catch (e) {
      print("Biometric auth error: $e");
      return false;
    }
  }

  /// Example: Combine biometric + Firebase reauth
  Future<bool> reauthenticateWithBiometrics(
      String email, String password) async {
    final bool bioOk = await authenticateWithBiometrics();
    if (!bioOk) return false;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final credential = EmailAuthProvider.credential(
        email: email,
        password: password, // stored securely
      );

      await user.reauthenticateWithCredential(credential);
      return true;
    } catch (e) {
      print("Firebase reauth failed: $e");
      return false;
    }
  }
}
