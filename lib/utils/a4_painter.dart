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
const int MARGIN = 250;
const int MARGIN_H = 180;

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

class PapeletaPainter extends CustomPainter {
  final List<PapeletaData> dados;
  final ui.Image? logo;

  PapeletaPainter(this.dados, {this.logo});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(Colors.white, BlendMode.src);

    const gap = 80.0;
    final qw = (A4_W - 2 * MARGIN_H) / 2.0;
    final qh = (A4_H - 2 * MARGIN - gap) / 2.0 - 200.0;

    for (var i = 0; i < dados.length && i < 4; i++) {
      final item = dados[i];
      final col = i % 2;
      final row = i ~/ 2;
      final ox = MARGIN_H + col * qw;
      final oy = MARGIN + row * (qh + gap);
      canvas.save();
      canvas.translate(ox, oy);
      _drawCardOnCanvas(canvas, qw, qh, item);
      canvas.restore();
    }

    final cx = A4_W / 2.0;
    final cy = MARGIN + qh + gap / 2.0;
    final contentTop = MARGIN.toDouble();
    final contentBottom = MARGIN + 2 * qh + gap;
    final contentLeft = MARGIN_H.toDouble();
    final contentRight = (A4_W - MARGIN_H).toDouble();

    final dashPaint = Paint()
      ..color = Colors.grey.shade700
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final scLinePaint = TextPainter(
      text: const TextSpan(text: '✂', style: TextStyle(fontSize: 36, color: Colors.grey)),
      textDirection: TextDirection.ltr,
    );
    scLinePaint.layout();
    for (var x = MARGIN_H; x < A4_W - MARGIN_H; x += 80) {
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
      ..strokeWidth = 6;
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), borderPaint);

    final precoDescFmt = formatarMoeda(item.precoComDesconto);
    final precoOrigFmt = formatarMoeda(item.precoOriginal);

    final qtdParcelasInt = int.tryParse(item.qtdParcelas.toString()) ?? 1;
    final rawParc = (double.tryParse(
                item.precoComDesconto.replaceAll('.', '').replaceAll(',', '.')) ??
            0.0) /
        (qtdParcelasInt > 0 ? qtdParcelasInt : 1);
    final valorParcNum = (rawParc * 100).ceil() / 100;
    final valorParcFmt = _brCurrency(valorParcNum);

    // logo (top-right, painted black) — placeholder texto "PAPELETA"
    final logoSize = w * 0.05;
    _drawText(
      canvas,
      'PAPELETA',
      w - 22,
      20 + logoSize,
      fontSize: logoSize,
      fontWeight: FontWeight.bold,
      color: Colors.black,
      align: TextAlign.right,
    );

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

    _drawText(canvas, 'exclusivo no', ovalR - w * 0.04, iLine1, fontSize: iSm, color: Colors.white, align: TextAlign.right);
    _drawText(canvas, 'cartão cliente a', ovalR - w * 0.04, iLine2, fontSize: iSm, color: Colors.white, align: TextAlign.right);

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
            Radius.circular(w * 0.03)),
        whiteStroke);
    b2Paint.paint(canvas, Offset(b2L + w * 0.03, badge2Top + b2H * 0.68 - b2Paint.height));

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

Future<ui.Image> renderA4Image(List<PapeletaData> dados) async {
  ui.Image? logo;
  try {
    final data = await rootBundle.load('assets/logo.png');
    logo = await decodeImageFromList(data.buffer.asUint8List());
  } catch (_) {
    logo = null;
  }
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  PapeletaPainter(dados, logo: logo).paint(canvas, Size(A4_W.toDouble(), A4_H.toDouble()));
  final picture = recorder.endRecording();
  return picture.toImage(A4_W, A4_H);
}

Future<Uint8List> renderA4Png(List<PapeletaData> dados) async {
  final img = await renderA4Image(dados);
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  return bytes!.buffer.asUint8List();
}

/// Gera um PDF A4 (595x842 pt) contendo a imagem renderizada, espelhando gerarPdf do Kotlin.
Future<Uint8List> gerarPdfBytes(List<PapeletaData> dados) async {
  final png = await renderA4Png(dados);
  final pdfDoc = pw.Document();
  pdfDoc.addPage(
    pw.Page(
      pageFormat: pdf.PdfPageFormat.a4,
      build: (context) => pw.Center(
        child: pw.Image(pw.MemoryImage(png), fit: pw.BoxFit.contain),
      ),
    ),
  );
  return await pdfDoc.save();
}
