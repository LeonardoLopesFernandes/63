import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:papeleta63/api/session.dart';
import 'package:papeleta63/utils/celular_semana.dart';
import 'package:papeleta63/widgets/celular_semana_poster.dart';

class SpinnerCelularScreen extends StatefulWidget {
  final String? descricaoInicial;
  final double? precoInicial;
  final double? descontoInicial;

  const SpinnerCelularScreen({
    super.key,
    this.descricaoInicial,
    this.precoInicial,
    this.descontoInicial,
  });

  @override
  State<SpinnerCelularScreen> createState() => _SpinnerCelularScreenState();
}

class _SpinnerCelularScreenState extends State<SpinnerCelularScreen> {
  static const Color _red = Color(0xFFD32F2F);
  static const Color _blue = Color(0xFF0D47A1);
  static const String _signSize1x1 = '1X1';
  static const String _signSize4x1 = '4X1';

  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _discountCtrl = TextEditingController();
  final _cardCtrl = TextEditingController(text: '10');
  final _insuranceCtrl = TextEditingController();
  final _startCtrl = TextEditingController();
  final _endCtrl = TextEditingController();
  final _scroll = ScrollController();
  final _posterKey = GlobalKey();

  String _imagePath = '';
  CelularSemanaData? _preview;
  String? _busy;
  double _fotoDx = 0;
  double _fotoDy = 0;
  double _fotoScale = 1;
  double _fotoScaleBase = 1;
  bool _ajustandoFoto = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final sunday = monday.add(const Duration(days: 6));
    if (widget.descricaoInicial != null) {
      _descCtrl.text = widget.descricaoInicial!;
    }
    if (widget.precoInicial != null && widget.precoInicial! > 0) {
      _priceCtrl.text =
          _fmtCurrency((widget.precoInicial! * 100).round().toString());
    }
    if (widget.descontoInicial != null && widget.descontoInicial! > 0) {
      _discountCtrl.text =
          _fmtCurrency((widget.descontoInicial! * 100).round().toString());
    }
    _startCtrl.text = _dateText(monday);
    _endCtrl.text = _dateText(sunday);
    _loadDraft();
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _discountCtrl.dispose();
    _cardCtrl.dispose();
    _insuranceCtrl.dispose();
    _startCtrl.dispose();
    _endCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  String _key(String name) => 'spinner_celular_$name';

  Future<void> _loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final desc = prefs.getString(_key('descricao'));
    final image = prefs.getString(_key('imagem'));
    final card = prefs.getString(_key('cartao'));
    final insurance = prefs.getString(_key('seguro'));
    final start = prefs.getString(_key('inicio'));
    final end = prefs.getString(_key('fim'));
    final fotoDx = prefs.getDouble(_key('foto_dx')) ?? 0;
    final fotoDy = prefs.getDouble(_key('foto_dy')) ?? 0;
    final fotoScale = prefs.getDouble(_key('foto_scale')) ?? 1;
    if (!mounted) return;
    setState(() {
      if (desc != null && desc.trim().isNotEmpty) _descCtrl.text = desc;
      if (image != null) _imagePath = image;
      if (card != null && card.isNotEmpty) _cardCtrl.text = card;
      if (insurance != null) {
        _insuranceCtrl.text = _fmtCurrency(insurance);
      }
      if (start != null && start.isNotEmpty) _startCtrl.text = start;
      if (end != null && end.isNotEmpty) _endCtrl.text = end;
      _fotoDx = fotoDx;
      _fotoDy = fotoDy;
      _fotoScale = fotoScale;
    });
  }

  Future<void> _saveDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key('descricao'), _descCtrl.text.trim());
    await prefs.setString(_key('imagem'), _imagePath);
    await prefs.setString(_key('cartao'), _cardCtrl.text.trim());
    await prefs.setString(
      _key('seguro'),
      _insuranceCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''),
    );
    await prefs.setString(_key('inicio'), _startCtrl.text.trim());
    await prefs.setString(_key('fim'), _endCtrl.text.trim());
    await prefs.setDouble(_key('foto_dx'), _fotoDx);
    await prefs.setDouble(_key('foto_dy'), _fotoDy);
    await prefs.setDouble(_key('foto_scale'), _fotoScale);
  }

  double _money(String text) {
    final digits = text.replaceAll(RegExp(r"[^0-9]"), "");
    return (int.tryParse(digits) ?? 0) / 100;
  }

  double _cardPercent() {
    final raw = _cardCtrl.text.replaceAll(',', '.').trim();
    return double.tryParse(raw) ?? 0;
  }

  Future<void> _escolherImagem() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 95,
    );
    if (picked == null) return;
    final dir = await getApplicationDocumentsDirectory();
    final ext = picked.path.contains('.')
        ? picked.path.substring(picked.path.lastIndexOf('.'))
        : '.jpg';
    final dest = File(
      '${dir.path}/spinner_celular_${DateTime.now().millisecondsSinceEpoch}$ext',
    );
    await File(picked.path).copy(dest.path);
    if (!mounted) return;
    setState(() {
      _imagePath = dest.path;
      _fotoDx = 0;
      _fotoDy = 0;
      _fotoScale = 1;
      _preview = _preview?.copyWith(
        imagemPath: dest.path,
        fotoDx: 0,
        fotoDy: 0,
        fotoScale: 1,
      );
    });
    await _saveDraft();
  }

  Future<void> _gerarPreview() async {
    final desc = _descCtrl.text.trim();
    final price = _money(_priceCtrl.text);
    final discount = _money(_discountCtrl.text);
    final card = _cardPercent();
    if (_imagePath.isEmpty) {
      _toast('Escolha a imagem do celular');
      return;
    }
    if (desc.isEmpty) {
      _toast('Digite a descrição do celular');
      return;
    }
    if (price <= 0) {
      _toast('Digite o valor do celular');
      return;
    }
    if (discount < 0 || discount > price) {
      _toast('Confira o desconto da portabilidade');
      return;
    }
    if (card < 0 || card > 100) {
      _toast('Confira o percentual do cartão');
      return;
    }
    final start = _startCtrl.text.trim();
    final end = _endCtrl.text.trim();
    if (start.isEmpty || end.isEmpty) {
      _toast('Preencha o período da oferta');
      return;
    }
    setState(() => _busy = 'preview');
    try {
      await precacheImage(FileImage(File(_imagePath)), context);
      if (!mounted) return;
      setState(() {
        _preview = CelularSemanaData(
          descricao: desc,
          imagemPath: _imagePath,
          precoOriginal: price,
          descontoPortabilidade: discount,
          percentualCartao: card,
          seguro: _money(_insuranceCtrl.text),
          ofertaInicio: start,
          ofertaFim: end,
          fotoDx: _fotoDx,
          fotoDy: _fotoDy,
          fotoScale: _fotoScale,
        );
      });
      await _saveDraft();
      if (_scroll.hasClients) {
        await _scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Rect get _fotoArea =>
      Rect.fromLTWH(85 + _fotoDx, 390 + _fotoDy, 407, 620);

  void _fotoTap(TapUpDetails details) {
    final inside = _fotoArea.contains(details.localPosition);
    if (_ajustandoFoto) {
      if (!inside) setState(() => _ajustandoFoto = false);
    } else if (inside) {
      setState(() => _ajustandoFoto = true);
    }
  }

  void _fotoScaleStart(ScaleStartDetails details) {
    _fotoScaleBase = _fotoScale;
  }

  void _fotoScaleUpdate(ScaleUpdateDetails details) {
    final preview = _preview;
    if (preview == null) return;
    final dx =
        (_fotoDx + details.focalPointDelta.dx).clamp(-25.0, 5.0).toDouble();
    final dy =
        (_fotoDy + details.focalPointDelta.dy).clamp(-40.0, 10.0).toDouble();
    final scale = (_fotoScaleBase * details.scale).clamp(0.7, 1.6).toDouble();
    setState(() {
      _fotoDx = dx;
      _fotoDy = dy;
      _fotoScale = scale;
      _preview = preview.copyWith(
        fotoDx: dx,
        fotoDy: dy,
        fotoScale: scale,
      );
    });
  }

  void _fotoScaleEnd(ScaleEndDetails details) {
    _saveDraft();
  }

  Future<Uint8List> _capturePng() async {
    final boundary =
        _posterKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2.35);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data!.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  Future<Uint8List> _pdfBytes(Uint8List png, String tamanho) async {
    final doc = pw.Document();
    final image = pw.MemoryImage(png);
    final fourPerPage =
        tamanho.toUpperCase().replaceAll('×', 'X') == _signSize4x1;
    doc.addPage(
      pw.Page(
        pageFormat: pdf.PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (_) {
          if (!fourPerPage) {
            return pw.Image(
              image,
              width: pdf.PdfPageFormat.a4.width,
              height: pdf.PdfPageFormat.a4.height,
              fit: pw.BoxFit.fill,
            );
          }
          pw.Widget cell() => pw.Image(
                image,
                width: pdf.PdfPageFormat.a4.width / 2,
                height: pdf.PdfPageFormat.a4.height / 2,
                fit: pw.BoxFit.fill,
              );
          return pw.Column(
            children: [
              pw.Expanded(
                child: pw.Row(
                  children: [
                    pw.Expanded(child: cell()),
                    pw.Expanded(child: cell()),
                  ],
                ),
              ),
              pw.Expanded(
                child: pw.Row(
                  children: [
                    pw.Expanded(child: cell()),
                    pw.Expanded(child: cell()),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
    return doc.save();
  }

  Future<String?> _escolherTamanhoImpressao(
      {String titulo = 'Tamanho da impressão'}) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titulo),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.looks_one_outlined),
              title: const Text('1×1'),
              subtitle: const Text('1 poster por folha'),
              onTap: () => Navigator.pop(ctx, _signSize1x1),
            ),
            ListTile(
              leading: const Icon(Icons.grid_view),
              title: const Text('4×1'),
              subtitle: const Text('4 posters por folha'),
              onTap: () => Navigator.pop(ctx, _signSize4x1),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _compartilhar() async {
    if (_preview == null) return;
    final tamanho = await _escolherTamanhoImpressao(
      titulo: 'Tamanho do compartilhamento',
    );
    if (tamanho == null || !mounted) return;
    setState(() => _busy = 'share');
    try {
      final png = await _capturePng();
      final dir = await getTemporaryDirectory();
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final fourPerPage =
          tamanho.toUpperCase().replaceAll('×', 'X') == _signSize4x1;
      final file = fourPerPage
          ? File('${dir.path}/celular_semana_4x1_$stamp.pdf')
          : File('${dir.path}/celular_semana_$stamp.png');
      if (fourPerPage) {
        await file.writeAsBytes(await _pdfBytes(png, tamanho));
      } else {
        await file.writeAsBytes(png);
      }
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: fourPerPage
            ? 'Celular da semana 4x1'
            : 'Celular da semana',
        text: fourPerPage ? 'Celular da semana 4x1' : 'Celular da semana',
      );
    } catch (e) {
      _toast('Erro ao compartilhar: $e');
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _imprimir() async {
    if (_preview == null) return;
    final tamanho = await _escolherTamanhoImpressao();
    if (tamanho == null || !mounted) return;
    setState(() => _busy = 'print');
    try {
      final png = await _capturePng();
      final bytes = await _pdfBytes(png, tamanho);
      final socket = await Socket.connect(
        Session.getPrinterIp(),
        9100,
        timeout: const Duration(seconds: 10),
      );
      try {
        final pjl = <int>[0x1B, 0x25, 0x2D, 0x31, 0x32, 0x33, 0x34, 0x35, 0x58];
        const lf = 10;
        socket.add(pjl);
        socket.add('@PJL JOB\n'.codeUnits);
        socket.add('@PJL SET MEDIA=A4\n'.codeUnits);
        socket.add('@PJL SET ORIENTATION=PORTRAIT\n'.codeUnits);
        socket.add('@PJL ENTER LANGUAGE=PDF\n'.codeUnits);
        socket.add(bytes);
        socket.add([lf]);
        socket.add(pjl);
        socket.add('@PJL EOJ\n'.codeUnits);
        socket.add(pjl);
        await socket.flush();
        _toast('Impressão enviada com sucesso!');
      } finally {
        await socket.close();
      }
    } catch (e) {
      _toast('Erro ao imprimir: $e');
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FE),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        title: RichText(
          text: const TextSpan(
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            children: [
              TextSpan(
                text: 'Celular da ',
                style: TextStyle(color: _red),
              ),
              TextSpan(
                text: 'semana',
                style: TextStyle(color: _blue),
              ),
            ],
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _previewBox(),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _busy == null ? _gerarPreview : null,
                      icon: _busy == 'preview'
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.auto_awesome),
                      label: const Text('GERAR PRÉ-VISUALIZAÇÃO'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _red,
                        foregroundColor: Colors.white,
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _imagemCard(),
                  const SizedBox(height: 10),
                  _formCard(),
                  const SizedBox(height: 6),
                  _resumoCard(),
                ],
              ),
            ),
          ),
          _bottomBar(),
        ],
      ),
    );
  }

  Widget _previewBox() {
    final preview = _preview;
    return Container(
      height: 430,
      decoration: BoxDecoration(
        color: const Color(0xFFE5E7EB),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: preview == null
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.image_outlined,
                            size: 54, color: Colors.grey),
                        SizedBox(height: 8),
                        Text(
                          'Preencha os dados e gere a pré-visualização',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : FittedBox(
                    fit: BoxFit.contain,
                    child: SizedBox(
                      width: CelularSemanaPoster.posterWidth,
                      height: CelularSemanaPoster.posterHeight,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTapUp: _fotoTap,
                        onScaleStart:
                            _ajustandoFoto ? _fotoScaleStart : null,
                        onScaleUpdate:
                            _ajustandoFoto ? _fotoScaleUpdate : null,
                        onScaleEnd: _ajustandoFoto ? _fotoScaleEnd : null,
                        child: RepaintBoundary(
                          key: _posterKey,
                          child: CelularSemanaPoster(data: preview),
                        ),
                      ),
                    ),
                  ),
          ),
          if (preview != null)
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _ajustandoFoto
                            ? 'Arraste para mover e use a pinça para dar zoom'
                            : 'Toque na foto para ajustar posição e zoom',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    if (_ajustandoFoto)
                      TextButton(
                        onPressed: () =>
                            setState(() => _ajustandoFoto = false),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: const Size(0, 32),
                        ),
                        child: const Text(
                          'CONCLUIR',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _imagemCard() {
    return _card(
      child: Row(
        children: [
          Container(
            width: 82,
            height: 96,
            decoration: BoxDecoration(
              color: const Color(0xFFF0F4F9),
              borderRadius: BorderRadius.circular(10),
            ),
            clipBehavior: Clip.antiAlias,
            child: _imagePath.isEmpty
                ? const Icon(Icons.smartphone, color: Colors.grey, size: 36)
                : Image.file(File(_imagePath), fit: BoxFit.cover),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Imagem do celular',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ),
          OutlinedButton(
            onPressed: _escolherImagem,
            style: OutlinedButton.styleFrom(
              foregroundColor: _blue,
              side: const BorderSide(color: _blue, width: 1.5),
            ),
            child: Text(_imagePath.isEmpty ? 'Escolher' : 'Trocar'),
          ),
        ],
      ),
    );
  }

  Widget _formCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _textField(
            _descCtrl,
            'Descrição do celular',
            hint: 'Ex: Motorola Moto G17 128GB',
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _currencyField(_priceCtrl, 'Valor do celular')),
              const SizedBox(width: 10),
              Expanded(
                child: _currencyField(_discountCtrl, 'Desconto portabilidade'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _cardCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  decoration: _decoration('Cartão Americanas', suffix: '%'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: _currencyField(_insuranceCtrl, 'Seguro')),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _dateField(_startCtrl, 'Oferta início')),
              const SizedBox(width: 10),
              Expanded(child: _dateField(_endCtrl, 'Oferta fim')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _resumoCard() {
    final price = _money(_priceCtrl.text);
    final discount = _money(_discountCtrl.text);
    final base = (price - discount).clamp(0.0, double.infinity).toDouble();
    final card = _cardPercent().clamp(0.0, 100.0).toDouble();
    final finalPrice = base * (1 - card / 100);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x1AD32F2F)),
      ),
      child: Row(
        children: [
          Expanded(child: _resumoItem('de', 'R\$ ${_fmtMoney(price)}')),
          Expanded(
              child: _resumoItem('desconto', 'R\$ ${_fmtMoney(discount)}')),
          Expanded(
            child: _resumoItem(
              'por',
              'R\$ ${_fmtMoney(finalPrice)}',
              destaque: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _resumoItem(String label, String value, {bool destaque = false}) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF6B7280),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(
              fontSize: destaque ? 17 : 15,
              fontWeight: FontWeight.w800,
              color: destaque ? _red : const Color(0xFF1D1B20),
            ),
          ),
        ),
      ],
    );
  }

  Widget _bottomBar() {
    final enabled = _preview != null && _busy == null;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: enabled ? _compartilhar : null,
                icon: _busy == 'share'
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.share, size: 18),
                label: const Text('COMPARTILHAR'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _blue,
                  side: const BorderSide(color: _blue, width: 1.5),
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: enabled ? _imprimir : null,
                icon: _busy == 'print'
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.print, size: 18),
                label: const Text('IMPRIMIR'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _red,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x1AD32F2F)),
      ),
      child: child,
    );
  }

  InputDecoration _decoration(String label, {String? suffix}) {
    return InputDecoration(
      labelText: label,
      suffixText: suffix,
      isDense: true,
      filled: true,
      fillColor: const Color(0xFFF0F4F9),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _blue),
      ),
    );
  }

  Widget _textField(
    TextEditingController controller,
    String label, {
    String? hint,
    TextCapitalization caps = TextCapitalization.sentences,
  }) {
    return TextField(
      controller: controller,
      textCapitalization: caps,
      decoration: _decoration(label).copyWith(hintText: hint),
    );
  }

  Widget _currencyField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [
        TextInputFormatter.withFunction((oldValue, newValue) {
          final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
          final formatted = _fmtCurrency(digits);
          return TextEditingValue(
            text: formatted,
            selection: TextSelection.collapsed(offset: formatted.length),
          );
        }),
      ],
      decoration: _decoration(label),
    );
  }

  Widget _dateField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [_DateMask()],
      decoration: _decoration(
        label,
        suffix: null,
      ).copyWith(hintText: 'dd/mm/aa'),
    );
  }

  static String _fmtCurrency(String digits) {
    final onlyDigits = digits.replaceAll(RegExp(r'[^0-9]'), '');
    if (onlyDigits.isEmpty) return '';
    final cents = int.tryParse(onlyDigits) ?? 0;
    return 'R\$ ${_brInt(cents ~/ 100)},${(cents % 100).toString().padLeft(2, '0')}';
  }

  static String _fmtMoney(double value) {
    final fixed = value.toStringAsFixed(2).split('.');
    return '${_brInt(int.tryParse(fixed[0]) ?? 0)},${fixed[1]}';
  }

  static String _brInt(int value) {
    final reversed = value.toString().split('').reversed.toList();
    final output = <String>[];
    for (var i = 0; i < reversed.length; i++) {
      if (i != 0 && i % 3 == 0) output.add('.');
      output.add(reversed[i]);
    }
    return output.reversed.join();
  }

  static String _dateText(DateTime d) {
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    final year = d.year.toString().substring(2);
    return '$day/$month/$year';
  }
}

class _DateMask extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final raw = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final digits = raw.length > 6 ? raw.substring(0, 6) : raw;
    final out = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i == 2 || i == 4) out.write('/');
      out.write(digits[i]);
    }
    final text = out.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
