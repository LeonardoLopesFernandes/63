import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:app_links/app_links.dart';
import 'package:papeleta63/api/client.dart';
import 'package:papeleta63/api/cronet_adapter.dart';
import 'package:papeleta63/api/endpoints.dart';
import 'package:papeleta63/api/session.dart';
import 'package:papeleta63/screens/login_screen.dart';
import 'package:papeleta63/screens/main_screen.dart';

final _appLinks = AppLinks();

void _handleDeepLink(Uri? uri) {
  if (uri == null) return;
  final token = _extractToken(uri.toString());
  if (token != null) {
    setAuthToken(token);
    Session.saveToken(token);
  }
}

String? _extractToken(String link) {
  final m = RegExp(r'[?&](newToken|token)=([^&]+)').firstMatch(link);
  if (m != null) {
    final t = Uri.decodeComponent(m.group(2)!);
    if (t.length > 50) return t;
  }
  return null;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  initCronetTransport();
  await Session.init();
  setupApiInterceptors();
  _appLinks.getInitialLink().then(_handleDeepLink);
  _appLinks.uriLinkStream.listen(_handleDeepLink);
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  /// null = verificando sessão (splash); true/false = destino.
  bool? _loggedIn;

  @override
  void initState() {
    super.initState();
    setOnSessionExpiredHandler(() {
      if (mounted) setState(() => _loggedIn = false);
    });
    Session.onLoginChange = () {
      if (mounted) setState(() => _loggedIn = Session.isLoggedIn());
    };
    _bootCheck();
  }

  /// Leitura na abertura: 1) JWT local (instantâneo); 2) se houver token,
  /// uma chamada leve à API confirma que não expirou no servidor.
  /// Se expirou e há credenciais salvas, vai ao Login que reloga sozinho.
  Future<void> _bootCheck() async {
    if (!Session.isLoggedIn()) {
      if (mounted) setState(() => _loggedIn = false);
      return;
    }
    if (Session.isTokenExpired()) {
      // Não limpa aqui: LoginScreen usa o token/credenciais p/ relogar.
      if (mounted) setState(() => _loggedIn = false);
      return;
    }
    if (mounted) setState(() => _loggedIn = true);
    try {
      final now = DateTime.now();
      final today =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final ok = await validateSession(
        storeId: Session.getUserStore(),
        startDate: today,
      ).timeout(const Duration(seconds: 15));
      if (ok == false && mounted) {
        // 401 confirmado no servidor: força fluxo de auto-login.
        Session.clearToken();
        setState(() => _loggedIn = false);
      }
    } catch (_) {
      // Sem rede/timeout: mantém decisão do JWT local.
    }
  }

  @override
  void dispose() {
    Session.onLoginChange = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Papeleta63',
      debugShowCheckedModeBanner: false,
      locale: const Locale('pt', 'BR'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('pt', 'BR'), Locale('en', 'US')],
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF4F8FE),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0D47A1)),
      ),
      home: _buildHome(),
    );
  }

  Widget _buildHome() {
    if (_loggedIn == null) {
      // Splash enquanto valida a sessão na abertura.
      return const Scaffold(
        backgroundColor: Color(0xFFF4F8FE),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Verificando sessão...',
                  style: TextStyle(color: Colors.black54)),
            ],
          ),
        ),
      );
    }
    return _loggedIn! ? const MainScreen() : const LoginScreen();
  }
}
