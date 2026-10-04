import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:papeleta63/utils/a4_painter.dart';
import 'package:papeleta63/utils/celulares.dart';

class PreviewScreen extends StatefulWidget {
  final List<PapeletaData> dados;
  const PreviewScreen({super.key, required this.dados});

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  static const double _minParcela = 49.99;
  static const _maxParcelasOpts = [10, 12];

  String? _busyAction;
  int _maxParcelas = 10;
  bool _mostrarExclusivo = true;
  late Future<Uint8List> _future;

  @override
  void initState() {
    super.initState();
    _gerarPreview();
  }

  void _gerarPreview() {
    setState(() {
      _future = renderA4Png(widget.dados,
          minParcela: _minParcela,
          maxParcelas: _maxParcelas,
          mostrarExclusivo: _mostrarExclusivo);
    });
  }

  void _toast(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

Widget _badgeLabel(IconData icon, String label, Color color) => Column(
  mainAxisSize: MainAxisSize.min,
  children: [
    Icon(icon, size: 20, color: color),
    const SizedBox(height: 2),
    FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, height: 1.1, color: color), textAlign: TextAlign.center, maxLines: 1),
    ),
  ],
);

/// Ícone pulsante usado enquanto o botão está carregando (sem texto).
Widget _busyIcon(IconData icon, Color color) => TweenAnimationBuilder<double>(
  tween: Tween<double>(begin: 0.8, end: 1.2),
  duration: const Duration(milliseconds: 600),
  curve: Curves.easeInOut,
  builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
  child: Icon(icon, size: 26, color: color),
);

  Future<void> _compartilhar() async {
    setState(() => _busyAction = 'compartilhar');
    try {
      final bytes = await gerarPdfBytes(widget.dados,
          minParcela: _minParcela,
          maxParcelas: _maxParcelas,
          mostrarExclusivo: _mostrarExclusivo);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/papeleta_a4.pdf');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)], subject: 'Papeleta A4', text: 'Papeleta A4');
    } catch (e) {
      _toast('Erro ao compartilhar: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _busyAction = null);
    }
  }

  Future<void> _imprimir() async {
    setState(() => _busyAction = 'imprimir');
    try {
      // Impressão: usa o PDF vetorial (texto nítido). Como a página é A4
      // vetorial, a impressora mantém o tamanho certo.
      final bytes = await gerarPdfBytes(widget.dados,
          minParcela: _minParcela,
          maxParcelas: _maxParcelas,
          mostrarExclusivo: _mostrarExclusivo);
      final socket = await Socket.connect('10.25.168.24', 9100, timeout: const Duration(seconds: 10));
      try {
        final pjl = <int>[0x1B, 0x25, 0x2D, 0x31, 0x32, 0x33, 0x34, 0x35, 0x58];
        const lf = 10;
        socket.add(pjl);
        socket.add(utf8.encode('@PJL JOB\n'));
        socket.add(utf8.encode('@PJL SET MEDIA=A4\n'));
        socket.add(utf8.encode('@PJL SET ORIENTATION=PORTRAIT\n'));
        socket.add(utf8.encode('@PJL ENTER LANGUAGE=PDF\n'));
        socket.add(bytes);
        socket.add([lf]);
        socket.add(pjl);
        socket.add(utf8.encode('@PJL EOJ\n'));
        socket.add(pjl);
        await socket.flush();
        _toast('Impressao enviada com sucesso!');
      } finally {
        await socket.close();
      }
    } catch (e) {
      _toast('Erro ao imprimir: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _busyAction = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8E8E8),
      appBar: AppBar(
        title: Center(
          child: RichText(
            text: TextSpan(
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              children: [
                TextSpan(text: 'Visualização', style: TextStyle(color: Color(0xFF0D47A1))),
                TextSpan(text: ' de Papeleta', style: TextStyle(color: Color(0xFFD32F2F))),
              ],
            ),
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 12),
              child: Center(
                child: FutureBuilder<Uint8List>(
                  future: _future,
                  builder: (ctx, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator());
                    }
                    if (snap.hasError) {
                      return Text('Erro ao renderizar: ${snap.error}');
                    }
                    return Image.memory(snap.data!, width: double.infinity);
                  },
                ),
              ),
            ),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
            child: Column(
              children: [
                Row(
                  children: [
                    const Text('Parcelas',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                    const Spacer(),
                    DropdownButton<int>(
                      value: _maxParcelas,
                      underline: const SizedBox.shrink(),
                      items: _maxParcelasOpts
                          .map((v) => DropdownMenuItem(
                              value: v,
                              child: Text('${v}x',
                                  style: const TextStyle(fontSize: 14))))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _maxParcelas = v);
                      },
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Expanded(
                      child: Text('"Exclusivo no cartão cliente a"',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                    Switch(
                      value: _mostrarExclusivo,
                      activeTrackColor: const Color(0xFFD32F2F),
                      onChanged: (v) =>
                          setState(() => _mostrarExclusivo = v),
                    ),
                  ],
                ),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _gerarPreview,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('GERAR PREVIEW'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0D47A1),
                      side:
                          const BorderSide(color: Color(0xFF0D47A1), width: 1.5),
                      fixedSize: const Size.fromHeight(44),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busyAction != null ? null : _imprimir,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2E7D32),
                      side: const BorderSide(color: Color(0xFF2E7D32), width: 1.5),
                      fixedSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _busyAction == 'imprimir'
                        ? _busyIcon(Icons.print, const Color(0xFF2E7D32))
                        : _badgeLabel(Icons.print, 'IMPRIMIR', const Color(0xFF2E7D32)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _busyAction != null ? null : _compartilhar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF111111),
                      foregroundColor: Colors.white,
                      fixedSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _busyAction == 'compartilhar'
                        ? _busyIcon(Icons.share, Colors.white)
                        : _badgeLabel(Icons.share, 'COMPARTILHAR', Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
