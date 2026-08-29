import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Espelho fiel do SessionManager do Kotlin (Papeleta63Prefs).
class Session {
  static late SharedPreferences _prefs;

  static const String _kBearerToken = 'BEARER_TOKEN';
  static const String _kUserEmail = 'USER_EMAIL';
  static const String _kUserName = 'USER_NAME';
  static const String _kUserStore = 'USER_STORE';
  static const String _kMsPassword = 'MS_PASSWORD';

  static VoidCallback? onLoginChange;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static void saveToken(String token) {
    _prefs.setString(_kBearerToken, token);
    onLoginChange?.call();
  }

  static String? getToken() => _prefs.getString(_kBearerToken);

  static bool isLoggedIn() => getToken() != null && getToken()!.isNotEmpty;

  static void clearToken() {
    _prefs.remove(_kBearerToken);
    onLoginChange?.call();
  }

  static void saveUserInfo(String email, String name, String store) {
    _prefs.setString(_kUserEmail, email);
    _prefs.setString(_kUserName, name);
    _prefs.setString(_kUserStore, store);
  }

  static String? getUserEmail() => _prefs.getString(_kUserEmail);
  static String? getUserName() => _prefs.getString(_kUserName);
  static String getUserStore() => _prefs.getString(_kUserStore) ?? 'L291';

  static void saveCredentials(String email, String password) {
    _prefs.setString(_kUserEmail, email);
    _prefs.setString(_kMsPassword, password);
  }

  static String? getSavedPassword() => _prefs.getString(_kMsPassword);

  static bool hasSavedCredentials() {
    final e = getUserEmail();
    final p = getSavedPassword();
    return e != null && e.isNotEmpty && p != null && p.isNotEmpty;
  }

  static void clearCredentials() {
    _prefs.remove(_kMsPassword);
  }
}
