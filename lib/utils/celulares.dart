import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class CelularSpec {
  final String id;
  final String marca;
  final String modelo;
  final String armazenamento;
  final List<String> specs;

  CelularSpec({
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
      specs: (json['specs'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
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

  PapeletaData({
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
  CelularSpec? selectedPhone;
  String priceText;
  String discountText;
  String ean;
  String codSap;
  bool daSemana;

  PapeletaFormState({
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
    final str = await rootBundle.loadString('assets/celulares.json');
    final list = json.decode(str) as List;
    return list.map((e) => CelularSpec.fromJson(e as Map<String, dynamic>)).toList();
  } catch (_) {
    return [];
  }
}

double parsePrice(String str) {
  final digits = str.replaceAll(RegExp(r'[^0-9]'), '');
  final cents = int.tryParse(digits) ?? 0;
  return cents / 100.0;
}

String formatCurrencyInput(String digits) {
  if (digits.isEmpty) return '';
  final cents = int.tryParse(digits) ?? 0;
  final reais = cents ~/ 100;
  final centavos = cents % 100;
  final reaisStr = _brInt(reais);
  return 'R\$ $reaisStr,${centavos.toString().padLeft(2, '0')}';
}

String _brInt(int value) {
  final s = value.toString();
  final reversed = s.split('').reversed.toList();
  final out = <String>[];
  for (var i = 0; i < reversed.length; i++) {
    if (i != 0 && i % 3 == 0) out.add('.');
    out.add(reversed[i]);
  }
  return out.reversed.join('');
}

Pair<int, double> calcParcelas(double price, {bool daSemana = false}) {
  const minParcela = 49.99;
  final maxQty = daSemana ? 15 : 12;
  var qty = (price / minParcela).floor();
  if (qty > maxQty) qty = maxQty;
  if (qty < 1) qty = 1;
  return Pair(qty, price / qty);
}

class Pair<T1, T2> {
  final T1 first;
  final T2 second;
  Pair(this.first, this.second);
}

String fmtPrice(double value) {
  return value.toStringAsFixed(2).replaceAll('.', ',');
}

String formatarMoeda(String valorStr) {
  final limpo = valorStr.replaceAll('.', '').replaceAll(',', '.').trim();
  final numero = double.tryParse(limpo) ?? 0.0;
  return _brCurrency(numero);
}

String _brCurrency(double numero) {
  final reais = numero.floor();
  final centavos = ((numero - reais) * 100).round();
  final centavosStr = centavos.toString().padLeft(2, '0');
  return '${_brInt(reais)},$centavosStr';
}

CelularSpec? findPhoneByDescription(List<CelularSpec> celulares, String description) {
  final desc = description.toLowerCase().trim();
  CelularSpec? best;
  var bestScore = 0;
  for (final phone in celulares) {
    final searchStr = '${phone.marca} ${phone.modelo} ${phone.armazenamento}'.toLowerCase();
    final words = searchStr.split(' ').where((w) => w.length > 1).toList();
    final score = words.where((w) => desc.contains(w)).length;
    if (score > bestScore) {
      bestScore = score;
      best = phone;
}

// Persisted phones file helpers

Future<List<CelularSpec>> loadSavedPhones() async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/phones.json');
  if (!await file.exists()) return [];
  final str = await file.readAsString();
  final list = json.decode(str) as List;
  return list.map((e) => CelularSpec.fromJson(e as Map<String, dynamic>)).toList();
}

Future<void> addSavedPhone(CelularSpec phone) async {
  final phones = await loadSavedPhones();
  phones.add(phone);
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/phones.json');
  await file.writeAsString(json.encode(phones.map((p) => {
      return {
        'id': p.id,
        'marca': p.marca,
        'modelo': p.modelo,
        'armazenamento': p.armazenamento,
        'specs': p.specs,
      };
    }).toList()));
}

Future<CelularSpec?> fetchSpecsFromApi(String description) async {
  // Placeholder fake data; in production replace with real API call
  return CelularSpec(
    id: DateTime.now().millisecondsSinceEpoch.toString(),
    marca: "Desconhecido",
    modelo: description,
    armazenamento: "Unknown",
    specs: [
      'Câmera frontal 12MP',
      'Câmera traseira 48MP',
      'RAM 6GB',
      'Bateria 4000mAh',
      'Processador Snapdragon 720G',
    ],
  );
}

Future<CelularSpec?> getOrCreateSpecs(String description, List<CelularSpec> baseList) async {
  final local = findPhoneByDescription(baseList, description);
  if (local != null) return local;
  final saved = await loadSavedPhones();
  final localSaved = findPhoneByDescription(saved, description);
  if (localSaved != null) return localSaved;
  final fetched = await fetchSpecsFromApi(description);
  if (fetched == null) return null;
  await addSavedPhone(fetched);
  return fetched;
}

  }
  if (bestScore >= 1) return best;
  return null;
}

String parsePriceToDigits(String price) {
  final lastDot = price.lastIndexOf('.');
  final lastComma = price.lastIndexOf(',');
  final decIdx = lastDot > lastComma ? lastDot : lastComma;
  if (decIdx >= 0) {
    final integerPart = price.substring(0, decIdx).replaceAll(RegExp(r'[^0-9]'), '');
    var decimalPart = price.substring(decIdx + 1).replaceAll(RegExp(r'[^0-9]'), '');
    decimalPart = decimalPart.padRight(2, '0').substring(0, 2);
    return integerPart + decimalPart;
  }
  return price.replaceAll(RegExp(r'[^0-9]'), '') + '00';
}
