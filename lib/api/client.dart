import 'package:dio/dio.dart';
import 'package:papeleta63/api/cronet_adapter.dart';
import 'package:papeleta63/api/session.dart';

const String slBaseUrl = 'https://sl-bff.americanas.io/';
const String appOrigin = 'https://sl-bff.americanas.io';
const String msLoginUrl =
    'https://sl-authorization.americanas.io/rotina-comercial';

String? _authToken;
bool _autoLoginTriggered = false;
void Function()? _onSessionExpired;

void setAuthToken(String token) {
  _authToken = _normalizeToken(token);
  if (_authToken != null && _authToken!.isNotEmpty) {
    _autoLoginTriggered = false;
  }
}

String? _normalizeToken(String token) {
  var t = token.trim();
  if (t.toLowerCase().startsWith('bearer ')) {
    t = t.substring(7).trim();
  }
  return t.isEmpty ? null : t;
}

String? getAuthToken() => _authToken;

void clearToken() {
  _authToken = null;
}

void setOnSessionExpired(void Function() handler) {
  _onSessionExpired = handler;
}

Future<void> _handleSessionExpired() async {
  if (_autoLoginTriggered) return;
  _autoLoginTriggered = true;
  clearToken();
  Session.clearToken();
  _onSessionExpired?.call();
}

final Dio apiClient = Dio(BaseOptions(
  baseUrl: slBaseUrl,
  connectTimeout: const Duration(seconds: 60),
  receiveTimeout: const Duration(seconds: 60),
  headers: {
    'Content-Type': 'application/json',
    'Accept': 'application/json, text/plain, */*',
    'Accept-Language': 'pt-BR,pt;q=0.9,en-US;q=0.8,en;q=0.7',
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
    'x-requested-with': 'amer.papeleta',
    'Origin': appOrigin,
    'Referer': '$appOrigin/',
  },
));

void setupApiInterceptors() {
  apiClient.httpClientAdapter = cronetAdapter;
  apiClient.interceptors.clear();
  apiClient.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) {
      String? token = _authToken ?? Session.getToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
        options.headers['Cookie'] = 'rc-newToken=$token';
      }
      return handler.next(options);
    },
    onError: (error, handler) async {
      if (error.response?.statusCode == 401 && _authToken != null) {
        await _handleSessionExpired();
      }
      return handler.next(error);
    },
  ));
}

void setOnSessionExpiredHandler(void Function() handler) {
  setOnSessionExpired(handler);
}
