import 'dart:io';

import 'package:flutter/material.dart';
import 'package:papeleta63/utils/celulares.dart';
import 'package:papeleta63/utils/celular_semana.dart';
import 'package:qr_flutter/qr_flutter.dart';

class CelularSemanaPoster extends StatelessWidget {
  static const double posterWidth = 1240;
  static const double posterHeight = 1754;
  static const Color _red = Color(0xFFE60012);
  static const Color _ink = Color(0xFF1D1D1B);
  static const Color _boxColor = Color(0xFFF1F1F1);

  final CelularSemanaData data;

  const CelularSemanaPoster({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: posterWidth,
      height: posterHeight,
      child: ColoredBox(
        color: _red,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(26, 22, 26, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 210,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'celular da\nsemana',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 112,
                      fontWeight: FontWeight.w900,
                      height: 0.86,
                      letterSpacing: -4,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(child: _cartaoBranco()),
              const SizedBox(height: 14),
              _faixaCombo(),
              const SizedBox(height: 12),
              _caixasCombo(),
              const SizedBox(height: 12),
              _letraMiuda(),
              const SizedBox(height: 12),
              _rodape(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cartaoBranco() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
      ),
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              height: 48,
              padding: const EdgeInsets.only(left: 18, right: 8),
              decoration: BoxDecoration(
                color: _red,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'oferta especial cartão cliente',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'a',
                      style: TextStyle(
                        color: _red,
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 43, child: _foto()),
                const SizedBox(width: 20),
                Expanded(flex: 57, child: _informacoes()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _foto() {
    final path = data.imagemPath.trim();
    if (path.isEmpty) return _semFoto();
    final file = File(path);
    if (!file.existsSync()) return _semFoto();
    return Center(
      child: Image.file(
        file,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stack) => _semFoto(),
      ),
    );
  }

  Widget _semFoto() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.smartphone, size: 210, color: Color(0xFFD9D9D9)),
          SizedBox(height: 12),
          Text(
            'imagem do celular',
            style: TextStyle(
              color: Color(0xFF9E9E9E),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _informacoes() {
    final de = 'R\$ ${fmtPrice(data.precoOriginal)}';
    final por = 'R\$ ${fmtPrice(data.precoFinal)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          data.descricao,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _ink,
            fontSize: 42,
            fontWeight: FontWeight.w700,
            height: 1.02,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'de: $de à vista',
          style: const TextStyle(
            color: _ink,
            fontSize: 25,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text.rich(
            TextSpan(
              children: [
                const TextSpan(
                  text: 'por: ',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w500),
                ),
                TextSpan(
                  text: por,
                  style: const TextStyle(
                    fontSize: 66,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -2,
                  ),
                ),
              ],
            ),
            style: const TextStyle(color: _ink, height: 1),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          '+ plano controle',
          style: TextStyle(
            color: _ink,
            fontSize: 33,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 2),
        const Text(
          '(válido na portabilidade para quaisquer bandeiras*)',
          style: TextStyle(
            color: _ink,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
          decoration: BoxDecoration(
            border: Border.all(color: _red, width: 3),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Column(
            children: [
              Text(
                'condições válidas também\npara pagamento no pix',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _ink,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  height: 1.08,
                ),
              ),
              SizedBox(height: 6),
              Text(
                '(consulte opções de parcelamento)',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _faixaCombo() {
    return Container(
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _red,
        borderRadius: BorderRadius.circular(26),
      ),
      child: const Text(
        'oferta especial combo*:',
        style: TextStyle(
          color: Colors.white,
          fontSize: 27,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _caixasCombo() {
    return SizedBox(
      height: 174,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _comboBox(
              white: true,
              children: [
                const Text(
                  'preço sem\ndesconto',
                  textAlign: TextAlign.center,
                  style: _label,
                ),
                const SizedBox(height: 8),
                Text(
                  'R\$ ${fmtPrice(data.precoOriginal)}',
                  textAlign: TextAlign.center,
                  style: _valor,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _comboBox(
              children: [
                const Text(
                  'preço no\nplano controle*',
                  textAlign: TextAlign.center,
                  style: _label,
                ),
                const SizedBox(height: 4),
                const Text(
                  'desconto de',
                  textAlign: TextAlign.center,
                  style: _subLabel,
                ),
                Text(
                  'R\$ ${fmtPrice(data.descontoPortabilidade)}',
                  textAlign: TextAlign.center,
                  style: _valor,
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          const Text('+', style: _plus),
          const SizedBox(width: 4),
          Expanded(
            child: _comboBox(
              children: [
                const Text(
                  'desconto no\ncartão cliente•a',
                  textAlign: TextAlign.center,
                  style: _label,
                ),
                const SizedBox(height: 8),
                Text(
                  '${data.percentualFormatado}% OFF',
                  textAlign: TextAlign.center,
                  style: _valorGrande,
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          const Text('+', style: _plus),
          const SizedBox(width: 4),
          Expanded(
            child: _comboBox(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Text('seguro', style: _label),
                    SizedBox(width: 5),
                    Icon(Icons.security, size: 22, color: _ink),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'R\$ ${fmtPrice(data.seguro)}',
                  textAlign: TextAlign.center,
                  style: _valorMedio,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static const TextStyle _label = TextStyle(
    color: _ink,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.05,
  );
  static const TextStyle _subLabel = TextStyle(
    color: _ink,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.05,
  );
  static const TextStyle _valor = TextStyle(
    color: _ink,
    fontSize: 32,
    fontWeight: FontWeight.w800,
    height: 1.05,
  );
  static const TextStyle _valorMedio = TextStyle(
    color: _ink,
    fontSize: 27,
    fontWeight: FontWeight.w800,
    height: 1.05,
  );
  static const TextStyle _valorGrande = TextStyle(
    color: _ink,
    fontSize: 37,
    fontWeight: FontWeight.w900,
    height: 1.05,
  );
  static const TextStyle _plus = TextStyle(
    color: _ink,
    fontSize: 44,
    fontWeight: FontWeight.w500,
    height: 1,
  );

  Widget _comboBox({bool white = false, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: white ? Colors.white : _boxColor,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: children,
      ),
    );
  }

  Widget _letraMiuda() {
    const base = TextStyle(
      color: _ink,
      fontSize: 13.5,
      height: 1.28,
      fontWeight: FontWeight.w500,
    );
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          const TextSpan(
            text:
                'Descontos aplicados separadamente e podem ser adquiridos '
                'de forma individual.\n',
          ),
          const TextSpan(
            text:
                'O desconto do seguro não está atrelado à venda de nenhum '
                'item e a contratação é opcional.\n',
          ),
          TextSpan(
            text:
                'Parcelamento disponível no crédito para todas as bandeiras, '
                'disponível apenas para ${data.descricao}.\n',
          ),
          TextSpan(
            text:
                'Desconto do plano controle disponível para portabilidade '
                'para quaisquer bandeiras, consulte planos e condições. '
                'Ofertas válidas de ${data.ofertaInicio} a ${data.ofertaFim} '
                'podendo encerrar sem aviso prévio.',
          ),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _rodape() {
    return SizedBox(
      height: 128,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 122,
            height: 122,
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
            child: QrImageView(
              data:
                  'https://play.google.com/store/apps/details?id=amer.papeleta.papeleta63',
              padding: EdgeInsets.zero,
              backgroundColor: Colors.white,
              size: 108,
            ),
          ),
          const SizedBox(width: 14),
          const Text(
            'baixe\no app!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 45,
              fontWeight: FontWeight.w900,
              height: 0.92,
              letterSpacing: -1,
            ),
          ),
          const Spacer(),
          Image.asset('assets/logo.png', height: 96),
        ],
      ),
    );
  }
}
