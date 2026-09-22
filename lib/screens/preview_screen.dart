import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:papeleta63/api/endpoints.dart';
import 'package:papeleta63/api/models.dart';
import 'package:papeleta63/api/session.dart';
import 'package:papeleta63/utils/a4_painter.dart';
import 'package:papeleta63/utils/celulares.dart';

class PreviewScreen extends StatefulWidget {
  final List<PapeletaData> dados;
  const PreviewScreen({super.key, required this.dados});

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  String? _busyAction;

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
      final bytes = await gerarPdfBytes(widget.dados);
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

  Future<void> _enviar() async {
    setState(() => _busyAction = 'enviar');
    try {
      final now = DateTime.now();
      final date = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final products = widget.dados.map((d) {
        return PapeletaPrintingData(
          productName: '${d.modelo} ${d.armazenamento}',
          price: parsePrice(d.precoComDesconto),
          installmentPrice: parsePrice(d.valorParcela),
          installmentQuantity: d.qtdParcelas,
          codSap: d.codSap,
          ean: d.ean,
          referenceDate: date,
          unit: 'UN',
        );
      }).toList();
      await sendPriceSigns(storeId: Session.getUserStore(), request: SendPriceSignRequest(products: products));
      _toast('Enviado com sucesso!');
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('401')) {
        _toast('Sessão expirada.');
      } else if (msg.contains('403')) {
        _toast('Acesso negado.');
      } else {
        _toast('Erro ao enviar: $msg');
      }
    } finally {
      if (mounted) setState(() => _busyAction = null);
    }
  }

  Future<void> _imprimir() async {
    setState(() => _busyAction = 'imprimir');
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
                    onPressed: _busyAction != null ? null : _enviar,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0D47A1),
                      side: const BorderSide(color: Color(0xFF0D47A1), width: 1.5),
                      fixedSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _busyAction == 'enviar'
                        ? _busyIcon(Icons.send, const Color(0xFF0D47A1))
                        : _badgeLabel(Icons.send, 'ENVIAR', const Color(0xFF0D47A1)),
                  ),
                ),
                const SizedBox(width: 8),
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
