import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:papeleta63/api/client.dart';
import 'package:papeleta63/api/session.dart';
import 'package:papeleta63/screens/login_webview_screen.dart';
import 'package:papeleta63/screens/main_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    if (Session.hasSavedCredentials()) {
      _emailController.text = Session.getUserEmail() ?? '';
      _passwordController.text = Session.getSavedPassword() ?? '';
    }
  }

  void _onLoggedIn(String token) {
    setAuthToken(token);
    Session.saveToken(token);
    try {
      final parts = token.split('.');
      if (parts.length >= 2) {
        String payload = parts[1];
        while (payload.length % 4 != 0) {
          payload += '=';
        }
        final decoded = utf8.decode(base64Url.decode(payload));
        final map = json.decode(decoded) as Map<String, dynamic>;
        final email = map['email']?.toString() ?? map['upn']?.toString() ?? _emailController.text.trim();
        var name = map['name']?.toString() ?? map['given_name']?.toString() ?? '';
        if (name.isEmpty) {
          name = email.split('@').first.replaceAll('.', ' ').replaceAll('_', ' ');
          name = name.split(' ').map((w) => w.isNotEmpty ? w[0].toUpperCase() + w.substring(1) : w).join(' ');
        }
        final store = map['loja']?.toString() ?? 'L291';
        Session.saveUserInfo(email, name, store);
      } else {
        Session.saveUserInfo(_emailController.text.trim(), 'Usuário', 'L291');
      }
    } catch (e) {
      Session.saveUserInfo(_emailController.text.trim(), 'Usuário', 'L291');
    }
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainScreen()),
      );
    }
  }

  Future<void> _entrarViaNavegador() async {
    final uri = Uri.parse(msLoginUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) _toast('Não foi possível abrir o navegador');
    }
  }

  Future<void> _entrarComToken() async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Entrar com token'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'Cole o token (JWT)'),
          maxLines: 4,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Entrar')),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      _onLoggedIn(result);
    }
  }

  Future<void> _abrirWebView() async {
    setState(() => _loading = true);
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => LoginWebViewScreen(prefillEmail: email, prefillPassword: password),
      ),
    );
    if (mounted) setState(() => _loading = false);
    if (result != null && result.isNotEmpty) {
      if (email.isNotEmpty && password.isNotEmpty) {
        Session.saveCredentials(email, password);
      }
      _onLoggedIn(result);
    }
  }

  void _toast(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FE),
      body: SafeArea(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Center(
              child: Text(
                '63',
                style: TextStyle(
                  fontSize: 460,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.withAlpha(20),
                ),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                     Image.asset('assets/ic_papeleta.png', width: 96, height: 96),
                     const SizedBox(height: 16),
                     const Text('Papeleta63', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFFD32F2F))),
                     const SizedBox(height: 32),
                     TextField(
                       controller: _emailController,
                       keyboardType: TextInputType.emailAddress,
                       decoration: _dec('E-mail (Microsoft)'),
                     ),
                     const SizedBox(height: 16),
                     TextField(
                       controller: _passwordController,
                       obscureText: _obscurePassword,
                       decoration: _dec('Senha').copyWith(
                         suffixIcon: IconButton(
                           icon: Icon(
                             _obscurePassword ? Icons.visibility_off : Icons.visibility,
                             color: const Color(0xFFD32F2F),
                           ),
                           onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                         ),
                       ),
                     ),
                     const SizedBox(height: 24),
                     SizedBox(
                       width: double.infinity,
                       height: 50,
                       child: ElevatedButton(
                         onPressed: _loading ? null : _abrirWebView,
                         style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD32F2F)),
                         child: _loading
                             ? const CircularProgressIndicator(color: Colors.white)
                             : const Text('ENTRAR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                       ),
                     ),
                     const SizedBox(height: 12),
                     TextButton(
                       onPressed: _entrarComToken,
                       child: const Text('ENTRAR COM TOKEN', style: TextStyle(color: Color(0xFFD32F2F), fontWeight: FontWeight.bold)),
                     ),
                     TextButton(
                       onPressed: _entrarViaNavegador,
                       child: const Text('ENTRAR VIA NAVEGADOR', style: TextStyle(color: Color(0xFFD32F2F))),
                     ),
                   ],
                 ),
               ),
             ),
          ],
        ),
      ),
    );
  }

   InputDecoration _dec(String label) => InputDecoration(
         labelText: label,
         filled: true,
         fillColor: const Color(0xFFFFEBEE),
         border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
         focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFD32F2F))),
       );
}
