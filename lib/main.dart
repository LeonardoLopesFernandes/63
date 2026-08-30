import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:app_links/app_links.dart';
import 'package:papeleta63/api/client.dart';
import 'package:papeleta63/api/cronet_adapter.dart';
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
  setupApiInterceptors();
  await Session.init();
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
  late bool _loggedIn;

  @override
  void initState() {
    super.initState();
    _loggedIn = Session.isLoggedIn();
    Session.onLoginChange = () {
      if (mounted) setState(() => _loggedIn = Session.isLoggedIn());
    };
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
      home: _loggedIn ? const MainScreen() : const LoginScreen(),
    );
  }
}
