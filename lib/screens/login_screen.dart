import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:papeleta63/api/client.dart';
import 'package:papeleta63/api/session.dart';
import 'package:papeleta63/screens/login_webview_screen.dart';
import 'package:papeleta63/screens/main_screen.dart';
import 'package:url_launcher/url_launcher.dart';

/// Tela de login do Papeleta 63 (port fiel da interface e fluxo do minha-loja).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _senhaController = TextEditingController();
  bool _mostrarSenha = false;
  bool _salvarCredenciais = false;
  bool _showForm = false;
  bool _reconectando = false;
  bool _waitingBrowserReturn = false;
  bool _validatingToken = false;
  String _clipboardHash = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _logoScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );
    _controller.forward();

    // Só pula direto p/ Main se o token ainda é válido.
    // Expirado -> cai no fluxo abaixo e reloga sozinho (silencioso).
    if (Session.hasValidToken()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const MainScreen()),
          );
        }
      });
      return;
    }

    _emailController.text = Session.getUserEmail() ?? '';
    _salvarCredenciais = Session.hasSavedCredentials();

    if (Session.hasSavedCredentials()) {
      _senhaController.text = Session.getSavedPassword() ?? '';
      _iniciarReconexaoSilenciosa();
    } else {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) setState(() => _showForm = true);
      });
    }
  }

  void _iniciarReconexaoSilenciosa() {
    setState(() {
      _reconectando = true;
      _showForm = false;
    });
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      _abrirWebView(autoLogin: true, silencioso: true);
    });
  }

  void _abrirWebView({required bool autoLogin, bool silencioso = false}) {
    final email = _emailController.text.trim();
    final senha = _senhaController.text;
    // Sempre persiste p/ o auto-login funcionar na próxima abertura,
    // mesmo se o checkbox estiver desmarcado nesta vez.
    if (email.isNotEmpty && senha.isNotEmpty) {
      Session.saveCredentials(email, senha);
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: RouteSettings(arguments: {
          LoginWebViewScreen.EXTRA_AUTO_LOGIN: autoLogin,
          LoginWebViewScreen.EXTRA_EMAIL: email,
          LoginWebViewScreen.EXTRA_SENHA: senha,
          LoginWebViewScreen.EXTRA_SILENCIOSO: silencioso,
        }),
        builder: (_) => LoginWebViewScreen(prefillEmail: email, prefillPassword: senha),
      ),
    ).then((result) {
      // A WebView pode voltar com o token via pop: conclui o login aqui.
      if (!mounted) return;
      if (result is String && result.trim().length > 50) {
        _onLoggedIn(result.trim());
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed && _waitingBrowserReturn) {
      await _checkClipboardForToken();
    }
  }

  Future<void> _handleOpenBrowser() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      _clipboardHash = data?.text ?? '';
      _waitingBrowserReturn = true;
      setState(() {});
      await launchUrl(
        Uri.parse(msLoginUrl),
        mode: LaunchMode.externalApplication,
      );
      if (mounted) {
        _toast('Faça login no navegador, copie o token e volte ao app.');
      }
    } catch (e) {
      _waitingBrowserReturn = false;
      if (mounted) {
        setState(() {});
        _toast('Não foi possível abrir o navegador: $e');
      }
    }
  }

  Future<void> _checkClipboardForToken() async {
    if (_validatingToken) return;
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final clipboardText = data?.text ?? '';
      if (clipboardText.isEmpty || clipboardText == _clipboardHash) return;

      String token = clipboardText.trim();
      if (token.toLowerCase().startsWith('bearer ')) {
        token = token.substring(7).trim();
      }
      final cookieIdx = token.indexOf('newToken=');
      if (cookieIdx >= 0) {
        var value = token.substring(cookieIdx + 'newToken='.length);
        final sep = value.indexOf(RegExp(r'[;&]'));
        if (sep >= 0) value = value.substring(0, sep);
        token = value.trim();
      }
      if (token.contains('token=')) {
        final qi = token.indexOf('token=');
        var value = token.substring(qi + 'token='.length);
        final amp = value.indexOf(RegExp(r'[&\s]'));
        if (amp >= 0) value = value.substring(0, amp);
        token = Uri.decodeComponent(value).trim();
      }

      if (token.length < 50) {
        if (mounted) {
          _toast('Nenhum token encontrado. Copie o token no navegador e volte ao app.');
        }
        return;
      }
      if (token == _clipboardHash) return;
      _clipboardHash = token;

      _onLoggedIn(token);
    } catch (_) {}
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
      _toast('Login realizado com sucesso!');
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainScreen()),
      );
    }
  }

  void _entrar() {
    final email = _emailController.text.trim();
    final senha = _senhaController.text;
    if (email.isNotEmpty && senha.isNotEmpty) {
      Session.saveCredentials(email, senha);
    }
    _abrirWebView(autoLogin: true);
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Widget _buildLogo() {
    return ScaleTransition(
      scale: _logoScale,
      child: FadeTransition(
        opacity: _logoOpacity,
        child: Image.asset(
          'assets/ic_papeleta.png',
          width: 84,
          height: 84,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FE),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: Align(
                alignment: Alignment.center,
                child: Text(
                  '63',
                  style: TextStyle(
                    fontSize: 320,
                    color: Colors.grey.withAlpha(20),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildLogo(),
                    const SizedBox(height: 8),
                    const Text(
                      'Papeleta 63',
                      style: TextStyle(
                        color: Color(0xFF1D1B20),
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        'Para ter acesso ao portal, vamos manter os fluxos de '
                        'autenticação segura.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF49454F),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (_reconectando)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Sessão expirada. Reconectando automaticamente...',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFF1D1B20),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      )
                    else if (_showForm)
                      AnimatedOpacity(
                        opacity: _showForm ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 600),
                        child: _buildForm(),
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

  Widget _buildForm() {
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
    );
    const primaryRed = Color(0xFFD32F2F);

    return Card(
      color: Colors.white,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'E-mail',
                style: TextStyle(
                  color: Color(0xFF49454F),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 48,
              child: TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: 'Email Microsoft',
                  hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                  filled: true,
                  fillColor: Colors.white,
                  border: inputBorder,
                  enabledBorder: inputBorder,
                  focusedBorder: inputBorder,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Senha',
                style: TextStyle(
                  color: Color(0xFF49454F),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 48,
              child: TextField(
                controller: _senhaController,
                obscureText: !_mostrarSenha,
                decoration: InputDecoration(
                  hintText: 'Senha',
                  hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                  filled: true,
                  fillColor: Colors.white,
                  border: inputBorder,
                  enabledBorder: inputBorder,
                  focusedBorder: inputBorder,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _mostrarSenha
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: Colors.grey[700],
                    ),
                    onPressed: () =>
                        setState(() => _mostrarSenha = !_mostrarSenha),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryRed,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _entrar,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _MicrosoftLogo(size: 20),
                    SizedBox(width: 10),
                    Text(
                      'Login Microsoft',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () =>
                  setState(() => _salvarCredenciais = !_salvarCredenciais),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Checkbox(
                      value: _salvarCredenciais,
                      activeColor: primaryRed,
                      checkColor: Colors.white,
                      side: const BorderSide(color: Colors.grey),
                      onChanged: (v) =>
                          setState(() => _salvarCredenciais = v ?? false),
                    ),
                    const Text(
                      'Salvar credenciais e ativar login automático',
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 13,
                      ),
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }
}

/// Logo 2x2 da Microsoft (4 quadrados coloridos).
class _MicrosoftLogo extends StatelessWidget {
  final double size;
  const _MicrosoftLogo({this.size = 20});

  @override
  Widget build(BuildContext context) {
    final c = size / 2 - 1;
    final tiles = [
      Container(color: const Color(0xFFF25022)),
      Container(color: const Color(0xFF7FBA00)),
      Container(color: const Color(0xFF00A4EF)),
      Container(color: const Color(0xFFFFBA08)),
    ];
    return SizedBox(
      width: size,
      height: size,
      child: Column(
        children: [
          Row(children: [
            SizedBox(width: c, height: c, child: tiles[0]),
            const SizedBox(width: 2),
            SizedBox(width: c, height: c, child: tiles[1]),
          ]),
          const SizedBox(height: 2),
          Row(children: [
            SizedBox(width: c, height: c, child: tiles[2]),
            const SizedBox(width: 2),
            SizedBox(width: c, height: c, child: tiles[3]),
          ]),
        ],
      ),
    );
  }
}
