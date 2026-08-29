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
            if (!_done && url.contains('?token=')) {
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

  String? _extractToken(String url) {
    final idx = url.indexOf('?token=');
    if (idx < 0) return null;
    var token = url.substring(idx + '?token='.length);
    final amp = token.indexOf('&');
    if (amp >= 0) token = token.substring(0, amp);
    return token.trim().isNotEmpty ? token.trim() : null;
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
