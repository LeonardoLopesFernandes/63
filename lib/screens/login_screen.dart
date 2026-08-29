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

  @override
  void initState() {
    super.initState();
    if (Session.hasSavedCredentials()) {
      _emailController.text = Session.getUserEmail() ?? '';
      _passwordController.text = Session.getSavedPassword() ?? '';
    }
  }

  void _onLoggedIn(String token, {String name = '', String store = 'L291'}) {
    setAuthToken(token);
    Session.saveToken(token);
    Session.saveUserInfo(_emailController.text.trim(), name, store);
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
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.badge, size: 72, color: Color(0xFF0D47A1)),
                const SizedBox(height: 16),
                const Text('Papeleta63', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1))),
                const SizedBox(height: 32),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _dec('E-mail (Microsoft)'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: _dec('Senha'),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _abrirWebView,
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D47A1)),
                    child: _loading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('ENTRAR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _entrarComToken,
                  child: const Text('ENTRAR COM TOKEN', style: TextStyle(color: Color(0xFF0D47A1), fontWeight: FontWeight.bold)),
                ),
                TextButton(
                  onPressed: _entrarViaNavegador,
                  child: const Text('ENTRAR VIA NAVEGADOR', style: TextStyle(color: Color(0xFF0D47A1))),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFFF0F4F9),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF0D47A1))),
      );
}
