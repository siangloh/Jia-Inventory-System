import 'package:shared_preferences/shared_preferences.dart';

class RememberMeService {
  static const String _keyRememberMe = 'remember_me';
  static const String _keyEmail = 'saved_email';
  static const String _keyPassword = 'saved_password';
  static const String _keyAutoLogin = 'auto_login';

  /// Save login credentials
  static Future<void> saveCredentials(
      String email, String password, bool rememberMe) async {
    final prefs = await SharedPreferences.getInstance();

    if (rememberMe) {
      await prefs.setString(_keyEmail, email);
      await prefs.setString(_keyPassword, password);
      await prefs.setBool(_keyRememberMe, true);
    } else {
      // Clear saved credentials if remember me is unchecked
      await clearCredentials();
    }
  }

  /// Save auto-login preference (when user successfully logs in with remember me)
  static Future<void> saveAutoLogin(bool autoLogin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoLogin, autoLogin);
  }

  /// Get saved credentials
  static Future<Map<String, dynamic>> getSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();

    return {
      'email': prefs.getString(_keyEmail) ?? '',
      'password': prefs.getString(_keyPassword) ?? '',
      'rememberMe': prefs.getBool(_keyRememberMe) ?? false,
      'autoLogin': prefs.getBool(_keyAutoLogin) ?? false,
    };
  }

  /// Check if user should be auto-logged in
  static Future<bool> shouldAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final rememberMe = prefs.getBool(_keyRememberMe) ?? false;
    final autoLogin = prefs.getBool(_keyAutoLogin) ?? false;

    return rememberMe && autoLogin;
  }

  /// Clear all saved credentials
  static Future<void> clearCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyEmail);
    await prefs.remove(_keyPassword);
    await prefs.setBool(_keyRememberMe, false);
    await prefs.setBool(_keyAutoLogin, false);
  }

  /// Clear only auto-login (keep credentials for form filling)
  static Future<void> clearAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoLogin, false);
    await prefs.remove(_keyRememberMe);
    await prefs.remove(_keyPassword);
  }

  /// Get saved email only
  static Future<String> getSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyEmail) ?? '';
  }

  /// Check if remember me was previously enabled
  static Future<bool> isRememberMeEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyRememberMe) ?? false;
  }
}
