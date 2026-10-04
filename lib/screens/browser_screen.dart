import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Navegador interno estilo Kiwi Browser para buscar ficha técnica
/// de aparelhos rapidamente sem sair do app.
class BrowserScreen extends StatefulWidget {
  final String initialQuery;
  const BrowserScreen({super.key, required this.initialQuery});

  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen> {
  late final WebViewController _controller;
  final TextEditingController _urlCtrl = TextEditingController();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final url = _buildSearchUrl(widget.initialQuery);
    _urlCtrl.text = url;

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) {
            _urlCtrl.text = url;
            if (mounted) setState(() => _loading = false);
          },
          onProgress: (progress) {
            if (mounted) {
              setState(() => _loading = progress < 100);
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(url));
  }

String _buildSearchUrl(String query) {
    // Prompt otimizado p/ retornar as specs no formato que o app extrai.
    final prompt = 'especificações básicas de $query neste formato exato '
        '(uma por linha, em português):\n'
        'Descrição:\n'
        'Câmera traseira:\n'
        'Câmera frontal:\n'
        'Bateria:\n'
        'RAM:\n'
        'Processador:\n'
        'Tela:';
    final q = Uri.encodeComponent(prompt);
    return 'https://www.google.com/search?q=$q';
}

  Future<void> _go() async {
    var input = _urlCtrl.text.trim();
    if (input.isEmpty) return;
    if (!input.contains('http://') && !input.contains('https://')) {
      input = _buildSearchUrl(input);
    }
    _urlCtrl.text = input;
    setState(() => _loading = true);
    await _controller.loadRequest(Uri.parse(input));
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: TextField(
                controller: _urlCtrl,
                onSubmitted: (_) => _go(),
                textInputAction: TextInputAction.go,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Digite um termo ou URL...',
                  hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  prefixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.black87, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Icon(Icons.search, color: Colors.grey, size: 20),
                    ],
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.arrow_forward, color: Colors.black54, size: 20),
                    onPressed: _go,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF0F4F9),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                ),
              ),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                WebViewWidget(controller: _controller),
                if (_loading)
                  const Positioned.fill(
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black54, size: 20),
                onPressed: () => _controller.goBack(),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward_ios, color: Colors.black54, size: 20),
                onPressed: () => _controller.goForward(),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.black54, size: 20),
                onPressed: () => _controller.reload(),
              ),
              IconButton(
                icon: const Icon(Icons.home, color: Colors.black54, size: 20),
                onPressed: () => _controller.loadRequest(Uri.parse(_buildSearchUrl(widget.initialQuery))),
              ),
            ],
          ),
        ),
      ),
    );
  }
}