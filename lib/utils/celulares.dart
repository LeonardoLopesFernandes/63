import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

// ---------------------------------------------------------------------
// Modelo de celular
// ---------------------------------------------------------------------
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

  Map<String, dynamic> toJson() => {
        'id': id,
        'marca': marca,
        'modelo': modelo,
        'armazenamento': armazenamento,
        'specs': specs,
      };
}

// ---------------------------------------------------------------------
// Dados da papeleta (classe auxiliar apenas para compilar)
// ---------------------------------------------------------------------
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

// ---------------------------------------------------------------------
// Estado da papeleta (classe auxiliar apenas para compilar)
// ---------------------------------------------------------------------
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
  }) => PapeletaFormState(
        selectedPhone: selectedPhone ?? this.selectedPhone,
        priceText: priceText ?? this.priceText,
        discountText: discountText ?? this.discountText,
        ean: ean ?? this.ean,
        codSap: codSap ?? this.codSap,
        daSemana: daSemana ?? this.daSemana,
      );
}

// ---------------------------------------------------------------------
// Funções utilitárias de cálculo
// ---------------------------------------------------------------------
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
  final rev = s.split('').reversed.toList();
  final out = <String>[];
  for (var i = 0; i < rev.length; i++) {
    if (i != 0 && i % 3 == 0) out.add('.');
    out.add(rev[i]);
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

String fmtPrice(double value) => value.toStringAsFixed(2).replaceAll('.', ',');

String formatarMoeda(String valorStr) {
  final limpo = valorStr.replaceAll('.', '').replaceAll(',', '.').trim();
  final num = double.tryParse(limpo) ?? 0.0;
  return _brCurrency(num);
}

String _brCurrency(double numero) {
  final reais = numero.floor();
  final centavos = ((numero - reais) * 100).round();
  return '${_brInt(reais)},${centavos.toString().padLeft(2, '0')}';
}

// ---------------------------------------------------------------------
// Carregamento de celulares internos
// ---------------------------------------------------------------------
Future<List<CelularSpec>> loadCelulares() async {
  try {
    final str = await rootBundle.loadString('assets/celulares.json');
    final list = json.decode(str) as List;
    return list.map((e) => CelularSpec.fromJson(e as Map<String, dynamic>)).toList();
  } catch (_) {
    return [];
  }
}

// ---------------------------------------------------------------------
// Busca por descrição (local)
// ---------------------------------------------------------------------
CelularSpec? findPhoneByDescription(List<CelularSpec> celulares, String description) {
  final desc = description.toLowerCase().trim();
  CelularSpec? best;
  var bestScore = 0;
  for (final phone in celulares) {
    final searchStr = '${phone.marca} ${phone.modelo} ${phone.armazenamento}'.toLowerCase();
    final words = searchStr.split(' ').where((w) => w.length > 1);
    final score = words.where((w) => desc.contains(w)).length;
    if (score > bestScore) {
      bestScore = score;
      best = phone;
    }
  }
  return bestScore >= 1 ? best : null;
}

// ---------------------------------------------------------------------
// Persistência local (phones.json)
// ---------------------------------------------------------------------
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
  await file.writeAsString(json.encode(phones.map((p) => p.toJson()).toList()));
}

// ---------------------------------------------------------------------
// Consulta à MobileAPI.dev
// ---------------------------------------------------------------------
Future<CelularSpec?> fetchSpecsFromApi(String description) async {
  final query = Uri.encodeComponent(description);
  final url = 'https://api.mobileapi.dev/v1/devices?search=$query';
  try {
    final resp = await http.get(Uri.parse(url));
    if (resp.statusCode == 200) {
      final data = json.decode(resp.body);
      if (data['results'] is List) {
        final devs = data['results'] as List;
        if (devs.isNotEmpty) {
          final dev = devs[0] as Map<String, dynamic>;
          final specs = <String>[];
          if (dev['camera_front'] != null) {
            specs.add("Câmera frontal ${dev['camera_front']}MP");
          }
          if (dev['camera_back'] != null) {
            specs.add("Câmera traseira ${dev['camera_back']}MP");
          }
          if (dev['ram'] != null) {
            specs.add("RAM ${dev['ram']}GB");
          }
          if (dev['battery'] != null) {
            specs.add("Bateria ${dev['battery']}mAh");
          }
          if (dev['processor'] != null) {
            specs.add("Processador ${dev['processor']}");
          }
          return CelularSpec(
            id: dev['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
            marca: dev['brand']?.toString() ?? '',
            modelo: dev['model']?.toString() ?? description,
            armazenamento: dev['storage']?.toString() ?? 'Unknown',
            specs: specs,
          );
        }
      }
    }
  } catch (_) {}
  return null;
}

// ---------------------------------------------------------------------
// Interface pública usada pela UI
// ---------------------------------------------------------------------
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

// ---------------------------------------------------------------------
// Formatação de preço (útil em algumas telas)
// ---------------------------------------------------------------------
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