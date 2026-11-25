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
  final double fotoDx;
  final double fotoDy;
  final double fotoScale;

  const CelularSemanaData({
    required this.descricao,
    required this.imagemPath,
    required this.precoOriginal,
    required this.descontoPortabilidade,
    required this.percentualCartao,
    required this.seguro,
    required this.ofertaInicio,
    required this.ofertaFim,
    this.fotoDx = 0,
    this.fotoDy = 0,
    this.fotoScale = 1,
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

  CelularSemanaData copyWith({
    String? descricao,
    String? imagemPath,
    double? precoOriginal,
    double? descontoPortabilidade,
    double? percentualCartao,
    double? seguro,
    String? ofertaInicio,
    String? ofertaFim,
    double? fotoDx,
    double? fotoDy,
    double? fotoScale,
  }) {
    return CelularSemanaData(
      descricao: descricao ?? this.descricao,
      imagemPath: imagemPath ?? this.imagemPath,
      precoOriginal: precoOriginal ?? this.precoOriginal,
      descontoPortabilidade:
          descontoPortabilidade ?? this.descontoPortabilidade,
      percentualCartao: percentualCartao ?? this.percentualCartao,
      seguro: seguro ?? this.seguro,
      ofertaInicio: ofertaInicio ?? this.ofertaInicio,
      ofertaFim: ofertaFim ?? this.ofertaFim,
      fotoDx: fotoDx ?? this.fotoDx,
      fotoDy: fotoDy ?? this.fotoDy,
      fotoScale: fotoScale ?? this.fotoScale,
    );
  }
}
