import '../services/biometric_service.dart';

final bioService = BiometricAuthService();

void handleFingerprintLogin() async {
  bool success = await bioService.authenticateWithBiometrics();
  if (success) {
    print("Biometric login success!");
    // Navigate to home page or do Firebase reauth
  } else {
    print("Biometric login failed.");
  }
}
