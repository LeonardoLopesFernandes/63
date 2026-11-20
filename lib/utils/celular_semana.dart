import 'dart:math' as math;

class CelularSemanaData {
  final String descricao;
  final String imagemPath;
  final double precoOriginal;
  final double descontoPortabilidade;
  final double percentualCartao;
  final double seguro;
  final String ofertaInicio;
  final String ofertaFim;

  const CelularSemanaData({
    required this.descricao,
    required this.imagemPath,
    required this.precoOriginal,
    required this.descontoPortabilidade,
    required this.percentualCartao,
    required this.seguro,
    required this.ofertaInicio,
    required this.ofertaFim,
  });

  double get precoBase => math.max(0, precoOriginal - descontoPortabilidade);

  double get precoFinal =>
      math.max(0, precoBase * (1 - percentualCartao / 100));

  String get percentualFormatado {
    final p = percentualCartao;
    return p == p.roundToDouble()
        ? p.toStringAsFixed(0)
        : p.toStringAsFixed(1).replaceAll('.', ',');
  }
}
