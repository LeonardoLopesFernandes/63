import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;
import 'package:papeleta63/utils/celulares.dart';

const int A4_W = 2480;
const int A4_H = 3508;
const int MARGIN = 150; // ~12,7mm (superior)
const int MARGIN_BOTTOM = 260; // reduz altura dos quadrantes
const int MARGIN_H = 0; // laterais zeradas (largura máxima)
const double GAP = 80; // ~7mm faixa de corte central

double _measureText(String text, double fontSize, {FontWeight weight = FontWeight.normal}) {
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(fontSize: fontSize, fontWeight: weight, color: Colors.black),
    ),
    textDirection: TextDirection.ltr,
  );
  tp.layout();
  return tp.width;
}

/// Distância do topo da caixa até a linha de base (mesma métrica usada pelo
/// preview). Serve para posicionar o texto vetorial exatamente como o raster.
double _baselineOffset(String text, double fontSize,
    {FontWeight weight = FontWeight.normal}) {
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(fontSize: fontSize, fontWeight: weight, color: Colors.black),
    ),
    textDirection: TextDirection.ltr,
  );
  tp.layout();
  return tp.computeDistanceToActualBaseline(TextBaseline.alphabetic);
}

void _drawText(
  Canvas canvas,
  String text,
  double x,
  double y, {
  required double fontSize,
  FontWeight fontWeight = FontWeight.normal,
  Color color = Colors.black,
  TextAlign align = TextAlign.left,
  double maxWidth = double.infinity,
}) {
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(fontSize: fontSize, fontWeight: fontWeight, color: color),
    ),
    textAlign: align,
    textDirection: TextDirection.ltr,
  );
  tp.layout(maxWidth: maxWidth);
  double dx = x;
  if (align == TextAlign.center) {
    dx = x - tp.width / 2;
  } else if (align == TextAlign.right) {
    dx = x - tp.width;
  }
  final baseline = tp.computeDistanceToActualBaseline(TextBaseline.alphabetic);
  tp.paint(canvas, Offset(dx, y - baseline));
}

/// Ajustes usados apenas no PDF (o preview mantém [MARGIN_BOTTOM]/[MARGIN_H]).
/// [PDF_MARGIN_H] deixa uma borda nas laterais da folha; [PDF_MARGIN_BOTTOM]
/// deixa cada quadrante um pouco mais baixo.
const int PDF_MARGIN_TOP = 250; // ~21mm (borda superior)
const int PDF_MARGIN_H = 180; // ~15mm (borda lateral)
const int PDF_MARGIN_BOTTOM = 300;

class PapeletaPainter extends CustomPainter {
  final List<PapeletaData> dados;
  final ui.Image? logo;
  final int marginTop;
  final int marginBottom;
  final int marginH;

  /// Parcela mínima (R$). Quando informada, o nº de parcelas é calculado a
  /// partir do preço do aparelho (preço / parcela mínima). Null = usa o
  /// qtdParcelas já calculado.
  final double? minParcela;

  /// Mostra o texto "exclusivo no cartão cliente a".
  final bool mostrarExclusivo;

  PapeletaPainter(this.dados,
      {this.logo,
      this.marginTop = MARGIN,
      this.marginBottom = MARGIN_BOTTOM,
      this.marginH = MARGIN_H,
      this.minParcela,
      this.mostrarExclusivo = true});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(Colors.white, BlendMode.src);

    const gap = GAP;
    final qw = (A4_W - 2 * marginH) / 2.0;
    final qh = (A4_H - marginTop - marginBottom - gap) / 2.0;

    for (var i = 0; i < dados.length && i < 4; i++) {
      final item = dados[i];
      final col = i % 2;
      final row = i ~/ 2;
      final ox = marginH + col * qw;
      final oy = marginTop + row * (qh + gap);
      canvas.save();
      canvas.translate(ox, oy);
      _drawCardOnCanvas(canvas, qw, qh, item);
      canvas.restore();
    }

    final cx = A4_W / 2.0;
    final cy = marginTop + qh + gap / 2.0;
    final contentTop = marginTop.toDouble();
    final contentBottom = marginTop + 2 * qh + gap;
    final contentLeft = marginH.toDouble();
    final contentRight = (A4_W - marginH).toDouble();

    final dashPaint = Paint()
      ..color = Colors.grey.shade700
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final scLinePaint = TextPainter(
      text: const TextSpan(text: '✂', style: TextStyle(fontSize: 36, color: Colors.grey)),
      textDirection: TextDirection.ltr,
    );
    scLinePaint.layout();
    for (var x = marginH; x < A4_W - marginH; x += 80) {
      scLinePaint.paint(canvas, Offset(x.toDouble(), cy + 10 - (scLinePaint.height)));
    }
    canvas.drawLine(Offset(contentLeft, cy + 18), Offset(contentRight, cy + 18), dashPaint);
    canvas.drawLine(Offset(cx, contentTop), Offset(cx, contentBottom), dashPaint);
  }

  void _drawCardOnCanvas(Canvas canvas, double qw, double qh, PapeletaData item) {
    final w = qw;
    final h = qh;
    final cx = w / 2;

    final borderPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14;
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), borderPaint);

    final precoDescFmt = formatarMoeda(item.precoComDesconto);
    final precoOrigFmt = formatarMoeda(item.precoOriginal);

    final precoDescNum = double.tryParse(
                item.precoComDesconto.replaceAll('.', '').replaceAll(',', '.')) ??
            0.0;
    var qtdParcelasInt = int.tryParse(item.qtdParcelas.toString()) ?? 1;
    final minP = minParcela;
    if (minP != null && minP > 0) {
      qtdParcelasInt = (precoDescNum / minP).floor();
      if (qtdParcelasInt < 1) qtdParcelasInt = 1;
    }
    if (qtdParcelasInt > 10) qtdParcelasInt = 10;
    final rawParc = precoDescNum / (qtdParcelasInt > 0 ? qtdParcelasInt : 1);
    final valorParcNum = (rawParc * 100).ceil() / 100;
    final valorParcFmt = _brCurrency(valorParcNum);

    // logo (top-right, pintado de preto) — espelha carregarLogo do Kotlin
    final logoImg = logo;
    if (logoImg != null) {
      const logoW = 48.0;
      final logoH = logoW * logoImg.height / logoImg.width;
      final logoPaint = Paint()
        ..colorFilter = const ColorFilter.mode(Colors.black, BlendMode.srcIn);
      canvas.drawImageRect(
        logoImg,
        Rect.fromLTWH(0, 0, logoImg.width.toDouble(), logoImg.height.toDouble()),
        Rect.fromLTWH(w - 22 - logoW, 20, logoW, logoH),
        logoPaint,
      );
    }

    // title
    _drawText(canvas, '${item.modelo} ${item.armazenamento}', cx, h * 0.10, fontSize: w * 0.06,
        fontWeight: FontWeight.bold, align: TextAlign.center);

    // specs
    final specX = w * 0.07;
    var specY = h * 0.16;
    final specLeading = w * 0.033 * 1.3;
    for (final spec in item.specs) {
      _drawText(canvas, '• $spec', specX, specY, fontSize: w * 0.033, fontWeight: FontWeight.bold);
      specY += specLeading;
    }

    // badge "preço com plano controle"
    final badge1Top = h * 0.38;
    final b1Line1 = 'preço com plano controle';
    final b1Line2 = 'consulte operadora (CLARO ou TIM) e modalidade';
    final b1L = w * 0.06;
    final b1R = w * 0.94;
    final b1H = w * 0.065;
    final badgeBP = Paint()
      ..color = Colors.grey
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(b1L, badge1Top, b1R - b1L, b1H),
            Radius.circular(w * 0.03)),
        badgeBP);
    _drawText(canvas, b1Line1, cx, badge1Top + w * 0.024, fontSize: w * 0.026,
        fontWeight: FontWeight.bold, color: Colors.grey.shade700, align: TextAlign.center);
    _drawText(canvas, b1Line2, cx, badge1Top + w * 0.050, fontSize: w * 0.022,
        color: Colors.grey.shade700, align: TextAlign.center);

    // black section
    final blackTop = h * 0.460;
    final blackPaint = Paint()..color = Colors.black;
    canvas.drawRect(Rect.fromLTWH(0, blackTop, w, h - blackTop), blackPaint);

    // discounted price
    final discTop = blackTop + h * 0.05;
    final dBigS = w * 0.14;
    final dLine1 = discTop + dBigS * 0.30;
    final dLine2 = discTop + dBigS * 0.72;
    final dLabelW = _measureText('à vista', w * 0.035, weight: FontWeight.bold) >
            _measureText('R\$', w * 0.055, weight: FontWeight.bold)
        ? _measureText('à vista', w * 0.035, weight: FontWeight.bold)
        : _measureText('R\$', w * 0.055, weight: FontWeight.bold);
    final dGap = w * 0.04;
    final dBlockW = dLabelW + dGap + _measureText(precoDescFmt, dBigS, weight: FontWeight.bold);
    final dLeft = cx - dBlockW / 2;
    _drawText(canvas, 'à vista', dLeft + dLabelW, dLine1, fontSize: w * 0.035,
        fontWeight: FontWeight.bold, color: Colors.white, align: TextAlign.right);
    _drawText(canvas, 'R\$', dLeft + dLabelW, dLine2, fontSize: w * 0.055,
        fontWeight: FontWeight.bold, color: Colors.white, align: TextAlign.right);
    _drawText(canvas, precoDescFmt, dLeft + dLabelW + dGap, dLine2, fontSize: dBigS,
        fontWeight: FontWeight.bold, color: Colors.white, align: TextAlign.left);

    // installment oval
    final instTop = discTop + dBigS + h * 0.02;
    final instH = w * 0.10;
    final ovalL = w * 0.06;
    final ovalR = w * 0.94;
    final ovalCx = (ovalL + ovalR) / 2;
    final whiteStroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(ovalL, instTop, ovalR - ovalL, instH),
            Radius.circular(w * 0.04)),
        whiteStroke);

    final iLine1 = instTop + instH * 0.42;
    final iLine2 = instTop + instH * 0.78;
    final iSm = w * 0.024;

    _drawText(canvas, '${qtdParcelasInt}x', ovalL + w * 0.04, iLine2, fontSize: w * 0.07,
        fontWeight: FontWeight.bold, color: Colors.white, align: TextAlign.left);
    final leftSmX = ovalL + w * 0.04 +
        _measureText('${qtdParcelasInt}x', w * 0.07, weight: FontWeight.bold) +
        w * 0.02;
    _drawText(canvas, 'sem', leftSmX, iLine1, fontSize: iSm, color: Colors.white, align: TextAlign.left);
    _drawText(canvas, 'juros', leftSmX, iLine2, fontSize: iSm, color: Colors.white, align: TextAlign.left);

    _drawText(canvas, 'R\$ $valorParcFmt', ovalCx, iLine2, fontSize: w * 0.075,
        fontWeight: FontWeight.bold, color: Colors.white, align: TextAlign.center);

    if (mostrarExclusivo) {
      _drawText(canvas, 'exclusivo no', ovalR - w * 0.04, iLine1, fontSize: iSm, color: Colors.white, align: TextAlign.right);
      _drawText(canvas, 'cartão cliente a', ovalR - w * 0.04, iLine2, fontSize: iSm, color: Colors.white, align: TextAlign.right);
    }

    // badge "preço sem plano controle"
    final badge2Top = instTop + instH + h * 0.02;
    final b2Text = 'preço sem plano controle';
    final b2Paint = TextPainter(
      text: TextSpan(
        text: b2Text,
        style: TextStyle(fontSize: w * 0.026, fontWeight: FontWeight.bold, color: Colors.white),
      ),
      textDirection: TextDirection.ltr,
    );
    b2Paint.layout();
    final b2W = b2Paint.width + w * 0.06;
    final b2H = w * 0.045;
    final b2L = cx - b2W / 2;
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(b2L, badge2Top, b2W, b2H),
            Radius.circular(w * 0.04)),
        whiteStroke);
    // Centraliza o texto no badge (horizontal e vertical).
    final b2TextX = b2L + (b2W - b2Paint.width) / 2;
    final b2TextY = badge2Top + (b2H - b2Paint.height) / 2;
    b2Paint.paint(canvas, Offset(b2TextX, b2TextY));

    // original price
    final origTop = badge2Top + b2H + h * 0.02;
    final oBigS = w * 0.115;
    final oLine1 = origTop + oBigS * 0.28;
    final oLine2 = origTop + oBigS * 0.72;
    final oLabelW = _measureText('à vista', w * 0.03, weight: FontWeight.bold) >
            _measureText('R\$', w * 0.048, weight: FontWeight.bold)
        ? _measureText('à vista', w * 0.03, weight: FontWeight.bold)
        : _measureText('R\$', w * 0.048, weight: FontWeight.bold);
    final oGap = w * 0.04;
    final oBlockW = oLabelW + oGap + _measureText(precoOrigFmt, oBigS, weight: FontWeight.bold);
    final oLeft = cx - oBlockW / 2;
    _drawText(canvas, 'à vista', oLeft + oLabelW, oLine1, fontSize: w * 0.03,
        fontWeight: FontWeight.bold, color: Colors.white, align: TextAlign.right);
    _drawText(canvas, 'R\$', oLeft + oLabelW, oLine2, fontSize: w * 0.048,
        fontWeight: FontWeight.bold, color: Colors.white, align: TextAlign.right);
    _drawText(canvas, precoOrigFmt, oLeft + oLabelW + oGap, oLine2, fontSize: oBigS,
        fontWeight: FontWeight.bold, color: Colors.white, align: TextAlign.left);

    // fine print
    final fineSizeW = w * 0.032;
    final fineY = h - w * 0.095;
    final fineLeading = fineSizeW * 1.3;
    _drawText(canvas, 'Oferta válida apenas para pagamento com cartão de crédito.', cx, fineY,
        fontSize: fineSizeW, color: Colors.grey.shade300, align: TextAlign.center);
    _drawText(canvas, 'Consultar com o promotor qual a operadora e a modalidade', cx, fineY + fineLeading,
        fontSize: fineSizeW, color: Colors.grey.shade300, align: TextAlign.center);
    _drawText(canvas, '(ativação, migração ou portabilidade) em que a oferta é válida.', cx, fineY + fineLeading * 2,
        fontSize: fineSizeW, color: Colors.grey.shade300, align: TextAlign.center);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

String _brCurrency(double numero) {
  final reais = numero.floor();
  final centavos = ((numero - reais) * 100).round();
  final s = reais.toString();
  final reversed = s.split('').reversed.toList();
  final out = <String>[];
  for (var i = 0; i < reversed.length; i++) {
    if (i != 0 && i % 3 == 0) out.add('.');
    out.add(reversed[i]);
  }
  return '${out.reversed.join('')},${centavos.toString().padLeft(2, '0')}';
}

Future<ui.Image> renderA4Image(List<PapeletaData> dados,
    {double scale = 1.0,
    int marginTop = MARGIN,
    int marginBottom = MARGIN_BOTTOM,
    int marginH = MARGIN_H,
    double? minParcela,
    bool mostrarExclusivo = true}) async {
  ui.Image? logo;
  try {
    final data = await rootBundle.load('assets/logo.png');
    logo = await decodeImageFromList(data.buffer.asUint8List());
  } catch (_) {
    logo = null;
  }
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  if (scale != 1.0) canvas.scale(scale);
  PapeletaPainter(dados,
          logo: logo,
          marginTop: marginTop,
          marginBottom: marginBottom,
          marginH: marginH,
          minParcela: minParcela,
          mostrarExclusivo: mostrarExclusivo)
      .paint(canvas, Size(A4_W.toDouble(), A4_H.toDouble()));
  final picture = recorder.endRecording();
  return picture.toImage((A4_W * scale).round(), (A4_H * scale).round());
}

Future<Uint8List> renderA4Png(List<PapeletaData> dados,
    {double? minParcela, bool mostrarExclusivo = true}) async {
  final img = await renderA4Image(dados,
      minParcela: minParcela, mostrarExclusivo: mostrarExclusivo);
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  return bytes!.buffer.asUint8List();
}

/// Gera um PDF A4 (595x842 pt) com a papeleta renderizada.
///
/// [altaNitidez] = true (compartilhar): 600 DPI (cai para 300 se faltar
/// memória). [altaNitidez] = false (impressão direta via socket): 300 DPI,
/// pois a impressora dimensiona a imagem pelos pixels — em 600 DPI ela
/// imprimiria com o dobro do tamanho.
Future<Uint8List> gerarPdfBytes(List<PapeletaData> dados,
    {bool altaNitidez = true,
    double? minParcela,
    bool mostrarExclusivo = true}) async {
  // Compartilhar: PDF vetorial (rápido, nítido, com a fonte do aparelho
  // embutida). Imprimir: raster 300 DPI (a impressora dimensiona pela imagem;
  // 600 DPI sairia no dobro do tamanho).
  if (altaNitidez) {
    try {
      return await gerarPdfVetorial(dados,
          minParcela: minParcela, mostrarExclusivo: mostrarExclusivo);
    } catch (_) {
      // se o vetorial falhar, cai no raster abaixo
    }
  }
  final escalas = altaNitidez ? const [2.0, 1.0] : const [1.0];
  Object? lastError;
  for (final scale in escalas) {
    try {
      return await _gerarPdfComEscala(dados, scale,
          minParcela: minParcela, mostrarExclusivo: mostrarExclusivo);
    } catch (e) {
      lastError = e;
    }
  }
  throw lastError ?? Exception('Falha ao gerar PDF');
}

/// PDF vetorial (texto/vetores) — nítido em qualquer zoom e rápido, ao
/// contrário do raster. Usa a fonte do aparelho (SF Pro Display) embutida.
Future<Uint8List> gerarPdfVetorial(List<PapeletaData> dados,
    {double? minParcela, bool mostrarExclusivo = true}) async {
  const page = pdf.PdfPageFormat.a4;
  final s = page.width / A4_W; // px (300 DPI) -> pontos
  final qw = (A4_W - 2 * PDF_MARGIN_H) / 2.0;
  final qh = (A4_H - PDF_MARGIN_TOP - PDF_MARGIN_BOTTOM - GAP) / 2.0;

  const white = pdf.PdfColors.white;
  final grey = const pdf.PdfColor.fromInt(0xFF9E9E9E);
  final grey700 = const pdf.PdfColor.fromInt(0xFF616161);
  final grey300 = const pdf.PdfColor.fromInt(0xFFE0E0E0);

  pw.MemoryImage? logo;
  try {
    final b = await rootBundle.load('assets/logo.png');
    logo = pw.MemoryImage(b.buffer.asUint8List());
  } catch (_) {
    logo = null;
  }

  // Fonte do aparelho (SF Pro Display) embutida: PDF igual ao preview e rápido.
  pw.ThemeData? theme;
  try {
    final base = pw.Font.ttf(
        await rootBundle.load('assets/fonts/SFProDisplay-Regular.ttf'));
    final bold = pw.Font.ttf(
        await rootBundle.load('assets/fonts/SFProDisplay-Bold.ttf'));
    theme = pw.ThemeData.withFont(base: base, bold: bold);
  } catch (_) {
    theme = null;
  }

  final children = <pw.Widget>[];

  pw.Positioned txt(double leftPx, double basePx, String text, double size,
          {bool bold = false,
          pdf.PdfColor color = pdf.PdfColors.black,
          pw.TextAlign align = pw.TextAlign.left,
          double? widthPx}) =>
      pw.Positioned(
        left: leftPx * s,
        top: (basePx -
                _baselineOffset(text, size,
                    weight: bold ? FontWeight.bold : FontWeight.normal)) *
            s,
        child: pw.SizedBox(
          width: widthPx == null ? null : widthPx * s,
          child: pw.Text(
            text,
            textAlign: align,
            softWrap: false,
            maxLines: 1,
            style: pw.TextStyle(
              fontSize: size * s,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: color,
            ),
          ),
        ),
      );

  for (var i = 0; i < dados.length && i < 4; i++) {
    final item = dados[i];
    final col = i % 2, row = i ~/ 2;
    final ox = PDF_MARGIN_H + col * qw;
    final oy = PDF_MARGIN_TOP + row * (qh + GAP);
    final w = qw, h = qh, cx = w / 2;

    final precoDescFmt = formatarMoeda(item.precoComDesconto);
    final precoOrigFmt = formatarMoeda(item.precoOriginal);
    final precoDescNum = double.tryParse(
                item.precoComDesconto.replaceAll('.', '').replaceAll(',', '.')) ??
            0.0;
    var qtdParcelasInt = int.tryParse(item.qtdParcelas.toString()) ?? 1;
    final minP = minParcela;
    if (minP != null && minP > 0) {
      qtdParcelasInt = (precoDescNum / minP).floor();
      if (qtdParcelasInt < 1) qtdParcelasInt = 1;
    }
    if (qtdParcelasInt > 10) qtdParcelasInt = 10;
    final rawParc = precoDescNum / (qtdParcelasInt > 0 ? qtdParcelasInt : 1);
    final valorParcFmt = _brCurrency((rawParc * 100).ceil() / 100);

    // borda do quadrante
    children.add(pw.Positioned(
      left: ox * s,
      top: oy * s,
      child: pw.Container(
        width: w * s,
        height: h * s,
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: pdf.PdfColors.black, width: 14 * s),
        ),
      ),
    ));

    // logo
    if (logo != null) {
      const logoW = 48.0;
      final logoH = logoW * logo.height! / logo.width!;
      children.add(pw.Positioned(
        left: (ox + w - 22 - logoW) * s,
        top: (oy + 20) * s,
        child: pw.Image(logo, width: logoW * s, height: logoH * s),
      ));
    }

    // título
    children.add(txt(ox, oy + h * 0.10, '${item.modelo} ${item.armazenamento}',
        w * 0.06,
        bold: true, align: pw.TextAlign.center, widthPx: w));

    // specs
    var specY = h * 0.16;
    final specLeading = w * 0.033 * 1.3;
    for (final spec in item.specs) {
      children.add(txt(ox + w * 0.07, oy + specY, '• $spec', w * 0.033, bold: true));
      specY += specLeading;
    }

    // badge "preço com plano controle"
    final badge1Top = h * 0.38;
    final b1H = w * 0.065;
    children.add(pw.Positioned(
      left: (ox + w * 0.06) * s,
      top: (oy + badge1Top) * s,
      child: pw.Container(
        width: w * 0.88 * s,
        height: b1H * s,
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: grey, width: 2 * s),
          borderRadius: pw.BorderRadius.circular(w * 0.03 * s),
        ),
      ),
    ));
    children.add(txt(ox, oy + badge1Top + w * 0.024, 'preço com plano controle',
        w * 0.026,
        bold: true, color: grey700, align: pw.TextAlign.center, widthPx: w));
    children.add(txt(ox, oy + badge1Top + w * 0.050,
        'consulte operadora (CLARO ou TIM) e modalidade', w * 0.022,
        color: grey700, align: pw.TextAlign.center, widthPx: w));

    // seção preta
    final blackTop = h * 0.460;
    children.add(pw.Positioned(
      left: ox * s,
      top: (oy + blackTop) * s,
      child: pw.Container(
          width: w * s, height: (h - blackTop) * s, color: pdf.PdfColors.black),
    ));

    // preço com desconto (à vista)
    final discTop = blackTop + h * 0.05;
    final dBigS = w * 0.14;
    final dLine1 = discTop + dBigS * 0.08;
    final dLine2 = discTop + dBigS * 0.72;
    final dLabelW = _measureText('à vista', w * 0.035,
                weight: FontWeight.bold) >
            _measureText('R\$', w * 0.055, weight: FontWeight.bold)
        ? _measureText('à vista', w * 0.035, weight: FontWeight.bold)
        : _measureText('R\$', w * 0.055, weight: FontWeight.bold);
    final dGap = w * 0.04;
    final dBlockW =
        dLabelW + dGap + _measureText(precoDescFmt, dBigS, weight: FontWeight.bold);
    final dLeft = cx - dBlockW / 2;
    children.add(txt(ox + dLeft, oy + dLine1, 'à vista', w * 0.035,
        bold: true,
        color: white,
        align: pw.TextAlign.right,
        widthPx: dLabelW));
    children.add(txt(ox + dLeft, oy + dLine2, 'R\$', w * 0.055,
        bold: true,
        color: white,
        align: pw.TextAlign.right,
        widthPx: dLabelW));
    children.add(txt(
        ox + dLeft + dLabelW + dGap, oy + dLine2, precoDescFmt, dBigS,
        bold: true, color: white));

    // parcela
    final instTop = discTop + dBigS + h * 0.02;
    final instH = w * 0.10;
    final ovalL = w * 0.06, ovalR = w * 0.94;
    children.add(pw.Positioned(
      left: (ox + ovalL) * s,
      top: (oy + instTop) * s,
      child: pw.Container(
        width: (ovalR - ovalL) * s,
        height: instH * s,
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: white, width: 2 * s),
          borderRadius: pw.BorderRadius.circular(w * 0.04 * s),
        ),
      ),
    ));
    final iLine1 = instTop + instH * 0.42;
    final iLine2 = instTop + instH * 0.78;
    final iSm = w * 0.024;
    children.add(txt(ox + ovalL + w * 0.04, oy + iLine2, '${qtdParcelasInt}x',
        w * 0.07,
        bold: true, color: white));
    final leftSmX = ovalL +
        w * 0.04 +
        _measureText('${qtdParcelasInt}x', w * 0.07, weight: FontWeight.bold) +
        w * 0.02;
    children.add(txt(ox + leftSmX, oy + iLine1, 'sem', iSm, color: white));
    children.add(txt(ox + leftSmX, oy + iLine2, 'juros', iSm, color: white));
    children.add(txt(ox + 0, oy + iLine2, 'R\$ $valorParcFmt', w * 0.075,
        bold: true,
        color: white,
        align: pw.TextAlign.center,
        widthPx: w));
    if (mostrarExclusivo) {
      children.add(txt(ox, oy + iLine1, 'exclusivo no', iSm,
          color: white, align: pw.TextAlign.right, widthPx: ovalR - w * 0.04));
      children.add(txt(ox, oy + iLine2, 'cartão cliente a', iSm,
          color: white, align: pw.TextAlign.right, widthPx: ovalR - w * 0.04));
    }

    // badge "preço sem plano controle"
    final badge2Top = instTop + instH + h * 0.02;
    final b2W = _measureText('preço sem plano controle', w * 0.026,
                weight: FontWeight.bold) +
        w * 0.06;
    final b2H = w * 0.045;
    children.add(pw.Positioned(
      left: (ox + cx - b2W / 2) * s,
      top: (oy + badge2Top) * s,
      child: pw.Container(
        width: b2W * s,
        height: b2H * s,
        alignment: pw.Alignment.center,
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: white, width: 2 * s),
          // Raio limitado à metade da altura (como o Skia faz no preview);
          // sem isso, raio > altura/2 gera pontas estranhas no PDF.
          borderRadius: pw.BorderRadius.circular(b2H / 2 * s),
        ),
        child: pw.Text('preço sem plano controle',
            style: pw.TextStyle(
                fontSize: w * 0.026 * s,
                fontWeight: pw.FontWeight.bold,
                color: white)),
      ),
    ));

    // preço original
    final origTop = badge2Top + b2H + h * 0.02;
    final oBigS = w * 0.115;
    final oLine1 = origTop + oBigS * 0.06;
    final oLine2 = origTop + oBigS * 0.72;
    final oLabelW = _measureText('à vista', w * 0.03, weight: FontWeight.bold) >
            _measureText('R\$', w * 0.048, weight: FontWeight.bold)
        ? _measureText('à vista', w * 0.03, weight: FontWeight.bold)
        : _measureText('R\$', w * 0.048, weight: FontWeight.bold);
    final oGap = w * 0.04;
    final oBlockW =
        oLabelW + oGap + _measureText(precoOrigFmt, oBigS, weight: FontWeight.bold);
    final oLeft = cx - oBlockW / 2;
    children.add(txt(ox + oLeft, oy + oLine1, 'à vista', w * 0.03,
        bold: true,
        color: white,
        align: pw.TextAlign.right,
        widthPx: oLabelW));
    children.add(txt(ox + oLeft, oy + oLine2, 'R\$', w * 0.048,
        bold: true,
        color: white,
        align: pw.TextAlign.right,
        widthPx: oLabelW));
    children.add(txt(
        ox + oLeft + oLabelW + oGap, oy + oLine2, precoOrigFmt, oBigS,
        bold: true, color: white));

    // letra miúda
    final fineSizeW = w * 0.032;
    final fineY = h - w * 0.095;
    final fineLeading = fineSizeW * 1.3;
    children.add(txt(ox, oy + fineY,
        'Oferta válida apenas para pagamento com cartão de crédito.', fineSizeW,
        color: grey300, align: pw.TextAlign.center, widthPx: w));
    children.add(txt(ox, oy + fineY + fineLeading,
        'Consultar com o promotor qual a operadora e a modalidade', fineSizeW,
        color: grey300, align: pw.TextAlign.center, widthPx: w));
    children.add(txt(ox, oy + fineY + fineLeading * 2,
        '(ativação, migração ou portabilidade) em que a oferta é válida.',
        fineSizeW,
        color: grey300, align: pw.TextAlign.center, widthPx: w));
  }

  // linhas de corte centrais
  final cyPx = PDF_MARGIN_TOP + qh + GAP / 2.0;
  final contentTop = PDF_MARGIN_TOP.toDouble();
  final contentBottom = PDF_MARGIN_TOP + 2 * qh + GAP;
  final contentLeft = PDF_MARGIN_H.toDouble();
  final contentRight = (A4_W - PDF_MARGIN_H).toDouble();
  children.add(pw.Positioned(
    left: contentLeft * s,
    top: (cyPx + 18) * s,
    child: pw.Container(
        width: (contentRight - contentLeft) * s, height: 1, color: grey700),
  ));
  children.add(pw.Positioned(
    left: (A4_W / 2.0) * s,
    top: contentTop * s,
    child: pw.Container(
        width: 1, height: (contentBottom - contentTop) * s, color: grey700),
  ));

  final doc = pw.Document(title: 'Papeleta A4', theme: theme);
  doc.addPage(pw.Page(
    pageFormat: page,
    margin: pw.EdgeInsets.zero,
    build: (_) => pw.Stack(children: children),
  ));
  return await doc.save();
}

Future<Uint8List> _gerarPdfComEscala(List<PapeletaData> dados, double scale,
    {double? minParcela, bool mostrarExclusivo = true}) async {
  final img = await renderA4Image(dados,
      scale: scale,
      marginTop: PDF_MARGIN_TOP,
      marginBottom: PDF_MARGIN_BOTTOM,
      marginH: PDF_MARGIN_H,
      minParcela: minParcela,
      mostrarExclusivo: mostrarExclusivo);
  final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
  img.dispose();
  final png = byteData!.buffer.asUint8List();
  final pdfDoc = pw.Document();
  pdfDoc.addPage(
    pw.Page(
      pageFormat: pdf.PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      build: (context) => pw.Image(pw.MemoryImage(png), fit: pw.BoxFit.fill),
    ),
  );
  return await pdfDoc.save();
}
