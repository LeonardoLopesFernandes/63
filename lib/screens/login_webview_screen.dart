import 'package:flutter/material.dart';
import 'package:papeleta63/api/client.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Tela de login Microsoft via WebView (espelha LoginWebViewActivity do Kotlin).
/// Captura o token quando a URL de redirecionamento contém `?token=JWT`.
class LoginWebViewScreen extends StatefulWidget {
  final String? prefillEmail;
  final String? prefillPassword;

  const LoginWebViewScreen({super.key, this.prefillEmail, this.prefillPassword});

  @override
  State<LoginWebViewScreen> createState() => _LoginWebViewScreenState();
}

class _LoginWebViewScreenState extends State<LoginWebViewScreen> {
  late final WebViewController _controller;
  bool _done = false;

  @override
  void initState() {
    super.initState();
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
            if (!_done && _hasToken(url)) {
              _done = true;
              final token = _extractToken(url);
              if (token != null && mounted) {
                Navigator.of(context).pop(token);
              }
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onPageFinished: (url) {
            _maybeInjectCredentials(url);
            _maybeExtractTokenFromPage();
          },
        ),
      )
      ..loadRequest(Uri.parse(msLoginUrl));
  }

  void _maybeInjectCredentials(String url) {
    final email = widget.prefillEmail;
    final password = widget.prefillPassword;
    if (email == null || password == null || email.isEmpty || password.isEmpty) return;
    // Tenta preencher os campos comuns do formulário Microsoft.
    _controller.runJavaScript('''
      (function() {
        try {
          var inputs = document.querySelectorAll('input');
          var userFilled = false, passFilled = false;
          inputs.forEach(function(i){
            var t = (i.type||'').toLowerCase();
            var id = (i.id||'').toLowerCase();
            var name = (i.name||'').toLowerCase();
            if (!userFilled && (t=='email' || id.indexOf('user')>=0 || id.indexOf('mail')>=0 || name.indexOf('user')>=0)) {
              i.value = ${_js(email)}; i.dispatchEvent(new Event('input',{bubbles:true})); userFilled = true;
            } else if (!passFilled && (t=='password' || id.indexOf('pass')>=0)) {
              i.value = ${_js(password)}; i.dispatchEvent(new Event('input',{bubbles:true})); passFilled = true;
            }
          });
        } catch(e){}
      })();
    ''');
  }

  String _js(String s) {
    final escaped = s.replaceAll("'", "\\'");
    return "'$escaped'";
  }

  bool _hasToken(String url) =>
      url.contains(RegExp(r'[?&](newToken|token)=')) ||
      url.contains('minhaloja.americanas.io');

  String? _extractToken(String url) {
    final m = RegExp(r'[?&](newToken|token)=([^&]+)').firstMatch(url);
    if (m == null) return null;
    final token = m.group(2)!.trim();
    return token.isNotEmpty ? token : null;
  }

  void _maybeExtractTokenFromPage() {
    if (_done) return;
    _controller.runJavaScriptReturningResult('''
      (function() {
        try {
          var t = localStorage.getItem('newToken') || localStorage.getItem('token') ||
                  sessionStorage.getItem('newToken') || sessionStorage.getItem('token') ||
                  window.newToken || window.token;
          return (t && t.length > 20) ? t : '';
        } catch(e){ return ''; }
      })();
    ''').then((value) {
      if (!_done && value is String && value.isNotEmpty) {
        _done = true;
        if (mounted) Navigator.of(context).pop(value);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login Americanas'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
