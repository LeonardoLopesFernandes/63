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

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;
  bool _autenticando = false;

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

    if (Session.hasSavedCredentials()) {
      _emailController.text = Session.getUserEmail() ?? '';
      _passwordController.text = Session.getSavedPassword() ?? '';
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onLoggedIn(String token) {
    setAuthToken(token);
    Session.saveToken(token);
    try {
      final parts = token.split('.');
      if (parts.length >= 2) {
        var p = parts[1];
        p = p.padRight(p.length + (4 - p.length % 4) % 4, '=');
        final decoded = utf8.decode(base64Url.decode(p));
        final j = jsonDecode(decoded);
        Map<String, dynamic>? claims;
        if (j is Map) claims = Map<String, dynamic>.from(j);

        final user = claims?['user'] is Map ? Map<String, dynamic>.from(claims!['user']) : null;

        String email = (user?['email'] ??
                claims?['email'] ??
                claims?['preferred_username'] ??
                claims?['upn'])
            ?.toString() ??
            _emailController.text.trim();

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
          nome = nome.split(' ').map((w) => w.isNotEmpty ? w[0].toUpperCase() + w.substring(1) : w).join(' ');
        }

        Session.saveUserInfo(email, nome, loja ?? Session.getUserStore());
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
      setState(() => _autenticando = true);
      await Future.delayed(const Duration(milliseconds: 1500));
      _onLoggedIn(result);
    }
  }

  void _toast(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    if (_autenticando) {
      return Scaffold(
        backgroundColor: const Color(0xFFF4F8FE),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: _pulseAnim,
                child: Image.asset('assets/ic_papeleta.png', width: 96, height: 96),
              ),
              const SizedBox(height: 24),
              const Text(
                'Autenticando...',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFD32F2F)),
              ),
              const SizedBox(height: 8),
              const Text(
                'Carregando credenciais...',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

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
