import 'dart:io';

import 'package:flutter/material.dart';
import 'package:papeleta63/utils/celular_semana.dart';

String _money(double value, {bool omitZeroCents = false}) {
  final fixed = value.toStringAsFixed(2).split('.');
  final inteiro = (int.tryParse(fixed[0]) ?? 0).toString();
  final buf = StringBuffer();
  for (var i = 0; i < inteiro.length; i++) {
    if (i > 0 && (inteiro.length - i) % 3 == 0) buf.write('.');
    buf.write(inteiro[i]);
  }
  if (omitZeroCents && fixed[1] == '00') return buf.toString();
  return '${buf.toString()},${fixed[1]}';
}

class CelularSemanaPoster extends StatelessWidget {
  static const double posterWidth = 1055;
  static const double posterHeight = 1491;
  static const Color _ink = Color(0xFF1D1D1B);
  static const String _overlay = 'assets/overlays/celular_semana.png';

  final CelularSemanaData data;

  const CelularSemanaPoster({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: posterWidth,
      height: posterHeight,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              _overlay,
              fit: BoxFit.fill,
              filterQuality: FilterQuality.high,
            ),
          ),
          _foto(),
          _descricao(),
          _de(),
          _por(),
          _planoControle(),
          _comboValores(),
          _letraMiuda(),
        ],
      ),
    );
  }

  Widget _foto() {
    final path = data.imagemPath.trim();
    final file = path.isEmpty ? null : File(path);
    return Positioned(
      left: 85 + data.fotoDx,
      top: 390 + data.fotoDy,
      width: 407,
      height: 620,
      child: ClipRect(
        child: Transform.scale(
          scale: data.fotoScale,
          alignment: Alignment.center,
          child: file != null && file.existsSync()
              ? Image.file(
                  file,
                  fit: BoxFit.contain,
                  alignment: Alignment.centerRight,
                  filterQuality: FilterQuality.high,
                  errorBuilder: (_, __, ___) => _semFoto(),
                )
              : _semFoto(),
        ),
      ),
    );
  }

  Widget _semFoto() {
    return const Center(
      child: Icon(Icons.smartphone, size: 200, color: Color(0xFFD9D9D9)),
    );
  }

  Widget _descricao() {
    final partes = _partesDescricao(data.descricao);
    return Positioned(
      left: 503,
      top: 425,
      width: 489,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            partes.$1,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'SFProDisplay',
              color: _ink,
              fontSize: 58,
              fontWeight: FontWeight.w400,
              height: 0.9,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            partes.$2,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'SFProDisplay',
              color: _ink,
              fontSize: 62,
              fontWeight: FontWeight.w700,
              height: 0.9,
              letterSpacing: -1.2,
            ),
          ),
        ],
      ),
    );
  }

  (String, String) _partesDescricao(String descricao) {
    final texto = descricao.trim();
    if (texto.isEmpty) return ('', '');
    const prefixos = [
      'Samsung Galaxy ',
      'Motorola Moto ',
      'Samsung ',
      'Motorola ',
      'Galaxy ',
      'Moto ',
    ];
    final lower = texto.toLowerCase();
    for (final prefixo in prefixos) {
      if (lower.startsWith(prefixo.toLowerCase())) {
        final marca = texto.substring(0, prefixo.length).trimRight();
        final modelo = texto.substring(prefixo.length).trim();
        if (modelo.isNotEmpty) return (marca, modelo);
      }
    }
    final palavras = texto.split(RegExp(r'\s+'));
    final n = palavras.length <= 2 ? 1 : 2;
    return (palavras.take(n).join(' '), palavras.skip(n).join(' '));
  }

  Widget _de() {
    return Positioned(
      left: 503,
      top: 541,
      width: 489,
      child: Text(
        'de: R\$ ${_money(data.precoOriginal)} à vista',
        style: const TextStyle(
          fontFamily: 'SFProDisplay',
          color: _ink,
          fontSize: 36,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }

  Widget _por() {
    return Positioned(
      left: 503,
      top: 590,
      width: 489,
      height: 88,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.topLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'por:',
              style: TextStyle(
                fontFamily: 'SFProDisplay',
                color: _ink,
                fontSize: 32,
                fontWeight: FontWeight.w400,
                height: 1,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'R\$ ${_money(data.precoFinal)}',
              style: const TextStyle(
                fontFamily: 'SFProDisplay',
                color: _ink,
                fontSize: 82,
                fontWeight: FontWeight.w700,
                letterSpacing: -2.8,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _planoControle() {
    return Positioned(
      left: 503,
      top: 700,
      width: 489,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            '+ plano controle',
            style: TextStyle(
              fontFamily: 'SFProDisplay',
              color: _ink,
              fontSize: 46,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
          SizedBox(height: 4),
          Text(
            '(válido na portabilidade para quaisquer bandeiras*)',
            style: TextStyle(
              fontFamily: 'SFProDisplay',
              color: _ink,
              fontSize: 20,
              fontWeight: FontWeight.w400,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _comboValores() {
    final temCentavos =
        ((data.precoOriginal * 100).round() % 100) != 0;
    return Positioned.fill(
      child: Stack(
        children: [
          _valorCaixa(
            left: 99,
            width: 191,
            top: 1150,
            texto: 'R\$ ${_money(data.precoOriginal, omitZeroCents: true)}',
            fontSize: temCentavos ? 32 : 38,
          ),
          _valorCaixa(
            left: 302,
            width: 190,
            top: 1155,
            texto: 'R\$ ${_money(data.descontoPortabilidade)}',
            fontSize: 36,
          ),
          _valorCaixa(
            left: 526,
            width: 191,
            top: 1150,
            texto: '${data.percentualFormatado}% OFF',
            fontSize: 38,
          ),
          _valorCaixa(
            left: 750,
            width: 190,
            top: 1150,
            texto: 'R\$ ${_money(data.seguro)}',
            fontSize: 36,
          ),
        ],
      ),
    );
  }

  Widget _valorCaixa({
    required double left,
    required double width,
    required double top,
    required String texto,
    required double fontSize,
  }) {
    return Positioned(
      left: left,
      top: top,
      width: width,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          texto,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'SFProDisplay',
            color: _ink,
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
      ),
    );
  }

  Widget _letraMiuda() {
    final texto = 'Descontos aplicados separadamente e podem ser adquiridos '
        'de forma individual.\n'
        'O desconto do seguro não está atrelado à venda de nenhum item e a '
        'contratação é opcional.\n'
        'Parcelamento disponível no crédito para todas as bandeiras, '
        'disponível apenas para ${data.descricao.toUpperCase()}.\n'
        'Desconto do plano controle disponível para portabilidade para '
        'quaisquer bandeiras, consulte planos\n'
        'e condições. Ofertas válidas de ${data.ofertaInicio} a '
        '${data.ofertaFim} podendo encerrar sem aviso prévio.';
    return Positioned(
      left: 57,
      top: 1210,
      width: 935,
      height: 150,
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: 935,
            child: Text(
              texto,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'SFProDisplay',
                color: _ink,
                fontSize: 19.0,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
