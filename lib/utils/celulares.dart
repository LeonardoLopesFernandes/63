import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

class CelularSpec {
  final String id;
  final String marca;
  final String modelo;
  final String armazenamento;
  final List<String> specs;

  const CelularSpec({
    required this.id,
    required this.marca,
    required this.modelo,
    required this.armazenamento,
    required this.specs,
  });

  factory CelularSpec.fromJson(Map<String, dynamic> json) {
    return CelularSpec(
      id: (json['id'] ?? '').toString(),
      marca: (json['marca'] ?? '').toString(),
      modelo: (json['modelo'] ?? '').toString(),
      armazenamento: (json['armazenamento'] ?? '').toString(),
      specs: (json['specs'] as List?)?.map((e) => e.toString()).toList() ?? const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'marca': marca,
        'modelo': modelo,
        'armazenamento': armazenamento,
        'specs': specs,
      };
}

class PapeletaData {
  final String modelo;
  final String armazenamento;
  final List<String> specs;
  final String precoOriginal;
  final String desconto;
  final String precoComDesconto;
  final int qtdParcelas;
  final String valorParcela;
  final String ean;
  final String codSap;
  final bool daSemana;

  const PapeletaData({
    required this.modelo,
    required this.armazenamento,
    required this.specs,
    required this.precoOriginal,
    required this.desconto,
    required this.precoComDesconto,
    required this.qtdParcelas,
    required this.valorParcela,
    this.ean = '',
    this.codSap = '',
    this.daSemana = false,
  });
}

class PapeletaFormState {
  final CelularSpec? selectedPhone;
  final String priceText;
  final String discountText;
  final String ean;
  final String codSap;
  final bool daSemana;

  const PapeletaFormState({
    this.selectedPhone,
    this.priceText = '',
    this.discountText = '',
    this.ean = '',
    this.codSap = '',
    this.daSemana = false,
  });

  PapeletaFormState copyWith({
    CelularSpec? selectedPhone,
    String? priceText,
    String? discountText,
    String? ean,
    String? codSap,
    bool? daSemana,
  }) {
    return PapeletaFormState(
      selectedPhone: selectedPhone ?? this.selectedPhone,
      priceText: priceText ?? this.priceText,
      discountText: discountText ?? this.discountText,
      ean: ean ?? this.ean,
      codSap: codSap ?? this.codSap,
      daSemana: daSemana ?? this.daSemana,
    );
  }
}

Future<List<CelularSpec>> loadCelulares() async {
  try {
    final content = await rootBundle.loadString('assets/celulares.json');
    final decoded = json.decode(content);
    if (decoded is! List) return [];
    return decoded
        .whereType<Map>()
        .map((item) => CelularSpec.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  } catch (_) {
    return [];
  }
}

double parsePrice(String value) {
  final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
  return (int.tryParse(digits) ?? 0) / 100.0;
}

String parsePriceToDigits(String price) {
  final lastDot = price.lastIndexOf('.');
  final lastComma = price.lastIndexOf(',');
  final decimalIndex = lastDot > lastComma ? lastDot : lastComma;
  if (decimalIndex >= 0) {
    final integerPart = price.substring(0, decimalIndex).replaceAll(RegExp(r'[^0-9]'), '');
    var decimalPart = price.substring(decimalIndex + 1).replaceAll(RegExp(r'[^0-9]'), '');
    decimalPart = decimalPart.padRight(2, '0');
    if (decimalPart.length > 2) decimalPart = decimalPart.substring(0, 2);
    return '$integerPart$decimalPart';
  }
  return '${price.replaceAll(RegExp(r'[^0-9]'), '')}00';
}

String formatCurrencyInput(String digits) {
  final onlyDigits = digits.replaceAll(RegExp(r'[^0-9]'), '');
  if (onlyDigits.isEmpty) return '';
  final cents = int.tryParse(onlyDigits) ?? 0;
  return 'R\$ ${_brInt(cents ~/ 100)},${(cents % 100).toString().padLeft(2, '0')}';
}

String _brInt(int value) {
  final reversed = value.toString().split('').reversed.toList();
  final output = <String>[];
  for (var i = 0; i < reversed.length; i++) {
    if (i != 0 && i % 3 == 0) output.add('.');
    output.add(reversed[i]);
  }
  return output.reversed.join();
}

String fmtPrice(double value) => value.toStringAsFixed(2).replaceAll('.', ',');

String formatarMoeda(String value) {
  final normalized = value.replaceAll('R\$', '').replaceAll(' ', '').trim();
  if (normalized.isEmpty) return '0,00';
  final lastDot = normalized.lastIndexOf('.');
  final lastComma = normalized.lastIndexOf(',');
  final decimalIndex = lastDot > lastComma ? lastDot : lastComma;
  final integerPart = decimalIndex >= 0
      ? normalized.substring(0, decimalIndex).replaceAll(RegExp(r'[^0-9]'), '')
      : normalized.replaceAll(RegExp(r'[^0-9]'), '');
  var decimalPart = decimalIndex >= 0
      ? normalized.substring(decimalIndex + 1).replaceAll(RegExp(r'[^0-9]'), '')
      : '00';
  decimalPart = decimalPart.padRight(2, '0').substring(0, 2);
  return '${_brInt(int.tryParse(integerPart.isEmpty ? '0' : integerPart) ?? 0)},$decimalPart';
}

class Pair<T1, T2> {
  final T1 first;
  final T2 second;
  const Pair(this.first, this.second);
}

Pair<int, double> calcParcelas(double price, {bool daSemana = false}) {
  const minParcela = 49.99;
  final maxQuantity = daSemana ? 15 : 12;
  var quantity = (price / minParcela).floor();
  if (quantity > maxQuantity) quantity = maxQuantity;
  if (quantity < 1) quantity = 1;
  return Pair(quantity, price / quantity);
}

CelularSpec? findPhoneByDescription(List<CelularSpec> celulares, String description) {
  final search = description.toLowerCase().trim();
  CelularSpec? best;
  var bestScore = 0;
  for (final phone in celulares) {
    final text = '${phone.marca} ${phone.modelo} ${phone.armazenamento}'.toLowerCase();
    final words = text.split(RegExp(r'\s+')).where((word) => word.length > 1);
    final score = words.where(search.contains).length;
    if (score > bestScore) {
      bestScore = score;
      best = phone;
    }
  }
  return bestScore > 0 ? best : null;
}

Future<List<CelularSpec>> loadSavedPhones() async {
  try {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/phones.json');
    if (!await file.exists()) return [];
    final decoded = json.decode(await file.readAsString());
    if (decoded is! List) return [];
    return decoded
        .whereType<Map>()
        .map((item) => CelularSpec.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  } catch (_) {
    return [];
  }
}

Future<void> addSavedPhone(CelularSpec phone) async {
  final phones = await loadSavedPhones();
  if (phones.any((item) => item.modelo.toLowerCase() == phone.modelo.toLowerCase() && item.armazenamento.toLowerCase() == phone.armazenamento.toLowerCase())) return;
  phones.add(phone);
  final directory = await getApplicationDocumentsDirectory();
  await File('${directory.path}/phones.json').writeAsString(json.encode(phones.map((item) => item.toJson()).toList()));
}

Future<CelularSpec?> fetchSpecsFromApi(String description) async {
  return CelularSpec(
    id: DateTime.now().millisecondsSinceEpoch.toString(),
    marca: 'Desconhecido',
    modelo: description,
    armazenamento: 'Não informado',
    specs: const ['Especificações não disponíveis'],
  );
}

Future<CelularSpec?> getOrCreateSpecs(String description, List<CelularSpec> baseList) async {
  final local = findPhoneByDescription(baseList, description);
  if (local != null) return local;
  final saved = findPhoneByDescription(await loadSavedPhones(), description);
  if (saved != null) return saved;
  final fetched = await fetchSpecsFromApi(description);
  if (fetched != null) await addSavedPhone(fetched);
  return fetched;
}
