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
  bool _busy = false;

  void _toast(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _compartilhar() async {
    setState(() => _busy = true);
    try {
      final bytes = await gerarPdfBytes(widget.dados);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/papeleta_a4.pdf');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)], subject: 'Papeleta A4', text: 'Papeleta A4');
    } catch (e) {
      _toast('Erro ao compartilhar: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _imprimir() async {
    setState(() => _busy = true);
    try {
      final bytes = await gerarPdfBytes(widget.dados);
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
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8E8E8),
      appBar: AppBar(
        title: const Text('Visualização de Papeleta', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Center(
                child: FutureBuilder<Uint8List>(
                  future: renderA4Png(widget.dados),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : _imprimir,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2E7D32),
                      side: const BorderSide(color: Color(0xFF2E7D32), width: 1.5),
                      fixedSize: const Size.fromHeight(48),
                    ),
                    child: Text(_busy ? 'IMPRIMINDO...' : 'Imprimir PDF', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _busy ? null : _compartilhar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF111111),
                      foregroundColor: Colors.white,
                      fixedSize: const Size.fromHeight(48),
                    ),
                    child: Text(_busy ? 'Compartilhando...' : 'Compartilhar PDF', style: const TextStyle(fontWeight: FontWeight.bold)),
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
