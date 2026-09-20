import 'dart:convert';

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
  static const String _kPrinterIp = 'PRINTER_IP';
  static const String _kProfilePhoto = 'PROFILE_PHOTO';

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

  /// Decodifica o payload do JWT sem validar assinatura (só p/ ler `exp`).
  static Map<String, dynamic>? _jwtPayload() {
    try {
      final token = getToken();
      if (token == null || token.isEmpty) return null;
      final parts = token.split('.');
      if (parts.length < 2) return null;
      var p = parts[1];
      p = p.padRight(p.length + (4 - p.length % 4) % 4, '=');
      final decoded = utf8.decode(base64Url.decode(p));
      final j = jsonDecode(decoded);
      if (j is Map) return Map<String, dynamic>.from(j);
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Expiração do token (claim `exp` em segundos). Null = sem exp / opaco.
  static DateTime? tokenExpiry() {
    final payload = _jwtPayload();
    if (payload == null) return null;
    final exp = payload['exp'];
    if (exp is num) {
      return DateTime.fromMillisecondsSinceEpoch((exp * 1000).toInt(), isUtc: true)
          .toLocal();
    }
    return null;
  }

  /// true se o JWT tem `exp` e já passou (com margem de 60s).
  static bool isTokenExpired({Duration skew = const Duration(seconds: 60)}) {
    final exp = tokenExpiry();
    if (exp == null) return false; // token opaco: deixa a API dizer (401)
    return DateTime.now().isAfter(exp.subtract(skew));
  }

  /// Leitura rápida na abertura: token existe E não expirado.
  static bool hasValidToken() => isLoggedIn() && !isTokenExpired();

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

  static void savePrinterIp(String ip) => _prefs.setString(_kPrinterIp, ip);
  static String getPrinterIp() => _prefs.getString(_kPrinterIp) ?? '192.168.1.100';

  static void saveProfilePhoto(String path) => _prefs.setString(_kProfilePhoto, path);
  static String? getProfilePhoto() => _prefs.getString(_kProfilePhoto);
  static void clearProfilePhoto() => _prefs.remove(_kProfilePhoto);

  static void clearAll() => _prefs.clear();
}
