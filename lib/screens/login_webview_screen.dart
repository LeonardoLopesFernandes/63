import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:papeleta63/api/client.dart';
import 'package:papeleta63/api/session.dart';
import 'package:papeleta63/screens/main_screen.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Tela de login Microsoft via WebView (port da lógica do minha-loja com tema Papeleta 63).
/// Captura token de query string, cookies, localStorage/sessionStorage ou redirecionamento.
class LoginWebViewScreen extends StatefulWidget {
  static const String EXTRA_AUTO_LOGIN = 'extra_auto_login';
  static const String EXTRA_EMAIL = 'extra_email';
  static const String EXTRA_SENHA = 'extra_senha';
  static const String EXTRA_SILENCIOSO = 'extra_silencioso';

  final String? prefillEmail;
  final String? prefillPassword;

  const LoginWebViewScreen({
    super.key,
    this.prefillEmail,
    this.prefillPassword,
  });

  @override
  State<LoginWebViewScreen> createState() => _LoginWebViewScreenState();
}

class _LoginWebViewScreenState extends State<LoginWebViewScreen>
    with SingleTickerProviderStateMixin {
  late final WebViewController _controller;
  bool _argsRead = false;
  bool _autoLogin = false;
  bool _silencioso = false;
  String _email = '';
  String _senha = '';
  bool _reveal = false;
  bool _saved = false;
  Timer? _injectTimer;
  Timer? _timeoutTimer;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_argsRead) {
      _argsRead = true;
      final args = ModalRoute.of(context)?.settings.arguments as Map?;
      _autoLogin = args?[LoginWebViewScreen.EXTRA_AUTO_LOGIN] ?? false;
      _email = args?[LoginWebViewScreen.EXTRA_EMAIL] ?? widget.prefillEmail ?? '';
      _senha = args?[LoginWebViewScreen.EXTRA_SENHA] ?? widget.prefillPassword ?? '';
      _silencioso = args?[LoginWebViewScreen.EXTRA_SILENCIOSO] ?? false;
      _reveal = !_silencioso;

      // IMPORTANTE: NÃO limpar cookies/cache/localStorage. Manter a sessão
      // Microsoft faz o auto-login ser instantâneo (igual ao minha-loja).

      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setUserAgent(
          'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
        )
        ..setNavigationDelegate(
          NavigationDelegate(
            onNavigationRequest: (request) {
              final url = request.url;
              if (!_saved && _urlPossuiToken(url)) {
                final token = _extrairTokenDaUrl(url);
                if (token != null && token.length > 50) {
                  _salvarToken(token);
                  return NavigationDecision.prevent;
                }
              }
              return NavigationDecision.navigate;
            },
            onPageFinished: (url) => _onPageFinished(url),
          ),
        )
        ..loadRequest(Uri.parse(msLoginUrl));

      if (_silencioso) {
        _timeoutTimer = Timer(const Duration(seconds: 60), () {
          if (mounted && !_saved) {
            setState(() => _reveal = true);
          }
        });
      }

      if (_autoLogin) {
        _injectTimer =
            Timer.periodic(const Duration(milliseconds: 1200), (_) {
          if (!_saved) _injectCredentials();
        });
      }
    }
  }

  String _montarScriptPreenchimento() {
    final email = _email.replaceAll("'", "\\'");
    final senha = _senha.replaceAll("'", "\\'");
    return """
      (function(){
        try {
          var e = document.getElementById('i0116');
          var p = document.getElementById('i0118');
          var btn = document.getElementById('idSIButton9');
          if (e && e.value.trim() === '') {
            e.value = '$email';
            if (btn) { btn.click(); }
            return;
          }
          if (p && p.value.trim() === '') {
            p.value = '$senha';
            if (btn) { btn.click(); }
            return;
          }
        } catch(err) {}
      })();
    """;
  }

  Future<void> _injectCredentials() async {
    try {
      await _controller.runJavaScript(_montarScriptPreenchimento());
    } catch (_) {}
  }

  bool _urlPossuiToken(String url) {
    return url.contains(RegExp(r'[?&](newToken|token)=')) ||
        url.contains('minhaloja.americanas.io');
  }

  String? _extrairTokenDaUrl(String url) {
    final m = RegExp(r'[?&](newToken|token)=([^&]+)').firstMatch(url);
    if (m == null) return null;
    final token = Uri.decodeComponent(m.group(2)!).trim();
    return token.length > 50 ? token : null;
  }

  Future<String?> _extrairToken(String url) async {
    final tokenUrl = _extrairTokenDaUrl(url);
    if (tokenUrl != null) return tokenUrl;

    // Lê cookies via JS (WebViewCookieManager desta versão não expõe getCookies).
    try {
      final result = await _controller.runJavaScriptReturningResult(
        "(()=>{try{return document.cookie||'';}catch(e){return '';}})()",
      );
      if (result is String) {
        final cookies = result.replaceAll('"', '');
        for (final part in cookies.split(';')) {
          final kv = part.trim().split('=');
          if (kv.length >= 2 &&
              (kv[0].trim() == 'newToken' || kv[0].trim() == 'token')) {
            final value = kv.sublist(1).join('=').trim();
            if (value.length > 50) return value;
          }
        }
      }
    } catch (_) {}

    try {
      final result = await _controller.runJavaScriptReturningResult(
        "(()=>{try{return (localStorage.getItem('newToken')||localStorage.getItem('token')||sessionStorage.getItem('newToken')||sessionStorage.getItem('token')||'');}catch(e){return '';}})()",
      );
      if (result is String) {
        final clean = result.replaceAll('"', '').trim();
        if (clean.isNotEmpty && clean.length > 50) return clean;
      }
    } catch (_) {}

    return null;
  }

  Future<void> _onPageFinished(String url) async {
    if (_saved) return;
    final token = await _extrairToken(url);
    if (token != null && token.length > 50) {
      _salvarToken(token);
      return;
    }
    if (_autoLogin) {
      await _injectCredentials();
    }
  }

  void _salvarToken(String token) {
    if (_saved) return;
    _saved = true;
    _injectTimer?.cancel();
    _timeoutTimer?.cancel();

    setAuthToken(token);
    Session.saveToken(token);
    // Garante auto-login nas próximas aberturas.
    if (_email.isNotEmpty && _senha.isNotEmpty) {
      Session.saveCredentials(_email, _senha);
    }

    Map<String, dynamic>? claims;
    try {
      final parts = token.split('.');
      if (parts.length >= 2) {
        var p = parts[1];
        p = p.padRight(p.length + (4 - p.length % 4) % 4, '=');
        final j = jsonDecode(utf8.decode(base64Url.decode(p)));
        if (j is Map) claims = Map<String, dynamic>.from(j);
      }
    } catch (_) {}

    final user = claims?['user'] is Map
        ? Map<String, dynamic>.from(claims!['user'])
        : null;

    String email = (user?['email'] ??
            claims?['email'] ??
            claims?['preferred_username'] ??
            claims?['upn'])
        ?.toString() ??
        (_email.isNotEmpty ? _email : '');

    String nome = (user?['nome'] ??
            user?['name'] ??
            claims?['name'] ??
            claims?['given_name'])
        ?.toString() ??
        '';

    final stores = user?['stores'] ?? claims?['stores'];
    final loja = user?['loja']?.toString() ??
        claims?['loja']?.toString() ??
        (stores is List && stores.isNotEmpty ? stores.first.toString() : null);

    if (email.isEmpty) email = 'usuario@americanas.io';
    if (nome.isEmpty) {
      nome = email.split('@').first.replaceAll('.', ' ').replaceAll('_', ' ');
      nome = nome
          .split(' ')
          .map((w) => w.isNotEmpty ? w[0].toUpperCase() + w.substring(1) : w)
          .join(' ');
    }

    Session.saveUserInfo(email, nome, loja ?? Session.getUserStore());

    if (mounted) {
      if (_silencioso) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Auto-login realizado com sucesso!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Login realizado com sucesso!')),
        );
      }

      // Se foi aberto como pop (ex: Navigator.push com return de String)
      if (Navigator.of(context).canPop() && !_silencioso) {
        Navigator.of(context).pop(token);
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainScreen()),
          (route) => false,
        );
      }
    }
  }

  Widget _buildPulsingLogo() {
    return Container(
      color: const Color(0xFFF4F8FE),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: _pulseAnim,
              child: Image.asset(
                'assets/ic_papeleta.png',
                width: 120,
                height: 120,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Conectando...',
              style: TextStyle(
                color: Color(0xFFD32F2F),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Entrando automaticamente...',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _silencioso && !_reveal
          ? null
          : AppBar(
              backgroundColor: const Color(0xFFFFFFFF),
              elevation: 0,
              surfaceTintColor: const Color(0xFFFFFFFF),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black87),
                onPressed: () => Navigator.pop(context),
              ),
              title: const Text('',
                  style: TextStyle(color: Colors.transparent, fontSize: 0)),
            ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (!_reveal)
            Positioned.fill(
              child: _buildPulsingLogo(),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _injectTimer?.cancel();
    _timeoutTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }
}
