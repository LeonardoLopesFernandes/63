import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
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
      id: (json['id'] ?? json['slug'] ?? '').toString(),
      marca: _firstText(json, const ['marca', 'brand', 'manufacturer', 'vendor']),
      modelo: _firstText(json, const ['modelo', 'model', 'name', 'device']),
      armazenamento: _firstText(json, const ['armazenamento', 'storage', 'internalMemory', 'memory']),
      specs: _readSpecs(json),
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

/// Normaliza descrição p/ comparação (maiúsculas, sem acento, 1 espaço).
String _normalizeDesc(String s) {
  var out = s.toUpperCase().trim();
  const accents = {
    'Á': 'A', 'À': 'A', 'Â': 'A', 'Ã': 'A',
    'É': 'E', 'È': 'E', 'Ê': 'E',
    'Í': 'I', 'Ì': 'I', 'Î': 'I',
    'Ó': 'O', 'Ò': 'O', 'Ô': 'O', 'Õ': 'O',
    'Ú': 'U', 'Ù': 'U', 'Û': 'U',
    'Ç': 'C',
  };
  accents.forEach((k, v) => out = out.replaceAll(k, v));
  return out.replaceAll(RegExp(r'\s+'), ' ');
}

/// Encontra APENAS o aparelho idêntico ao da descrição selecionada:
/// a descrição precisa conter o modelo E o armazenamento igual.
/// Nunca retorna "parecido" — sem idêntico, a busca vai p/ internet.
CelularSpec? findExactPhone(List<CelularSpec> celulares, String description) {
  final search = _normalizeDesc(description);
  final wantedStorage = _extractStorageFromText(search);
  for (final phone in celulares) {
    final model = _normalizeDesc(phone.modelo);
    if (model.isEmpty || !search.contains(model)) continue;
    if (wantedStorage != 'Não informado' &&
        _normalizeDesc(phone.armazenamento) != wantedStorage) {
      continue;
    }
    return phone;
  }
  return null;
}

/// Limpa a descrição verbosa da 1ª API p/ a busca na MobileAPI.
/// Ex: "APARELHO CELULAR SMARTPHONE SAMSUNG GALAXY S23 5G 256GB PRETO"
///  -> "SAMSUNG GALAXY S23 5G".
String _cleanApiQuery(String description) {
  final upper = _normalizeDesc(description);
  const noise = {
    'APARELHO', 'APARELHO CELULAR', 'CELULAR', 'SMARTPHONE', 'TELEFONE',
    'CELL', 'MOBILE', 'MEMORIA', 'ARMAZENAMENTO', 'COR', 'PRETO', 'PRETA',
    'BRANCO', 'BRANCA', 'AZUL', 'VERDE', 'ROSA', 'CINZA', 'GRAFITE',
    'PRATA', 'DOURADO', 'DOURADA', 'BEGE', 'CREME', 'LILAS', 'ROXO',
    'AMARELO', 'VERMELHO', 'LARANJA', 'MARROM', 'TITANIO', 'TITANIUM',
    'NOVO', 'NOVA', 'ORIGINAL', 'LACRADO', 'GB', 'TB', 'RAM',
  };
  final tokens = upper
      .split(' ')
      .where((t) => t.length > 1)
      .where((t) => !noise.contains(t))
      .where((t) => !RegExp(r'^\d+(?:[.,]\d+)?\s?(GB|TB)$').hasMatch(t))
      .toList();
  if (tokens.isEmpty) return description.trim();
  // Mantém marca + modelo (primeiros tokens relevantes bastam).
  return tokens.take(6).join(' ');
}

/// Detecta a fabricante pela descrição p/ filtrar a busca (manufacturer).
String? _detectManufacturer(String description) {
  final u = _normalizeDesc(description);
  if (u.contains('SAMSUNG') || u.contains('GALAXY')) return 'Samsung';
  if (u.contains('MOTOROLA') || u.contains(' MOTO ') || u.startsWith('MOTO ')) {
    return 'Motorola';
  }
  if (u.contains('APPLE') || u.contains('IPHONE')) return 'Apple';
  if (u.contains('XIAOMI') || u.contains('REDMI') || u.contains('POCO')) {
    return 'Xiaomi';
  }
  return null;
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

/// API Key da MobileAPI.dev. Pode ser sobrescrita via
/// `flutter build apk --dart-define=MOBILE_API_KEY=xxx`.
/// defaultValue embutido para funcionar sem flags extras.
const String mobileApiKey = String.fromEnvironment(
  'MOBILE_API_KEY',
  defaultValue: '18f7405527592c6822f4257c5515ad98f2ddad81',
);

/// Carrega lista completa (assets + já buscados via API e salvos).
Future<List<CelularSpec>> loadAllCelulares() async {
  final base = await loadCelulares();
  final saved = await loadSavedPhones();
  for (final s in saved) {
    final exists = base.any((b) =>
        b.modelo.toLowerCase() == s.modelo.toLowerCase() &&
        b.armazenamento.toLowerCase() == s.armazenamento.toLowerCase());
    if (!exists) base.add(s);
  }
  return base;
}

final Dio _mobileApi = Dio(BaseOptions(
  baseUrl: 'https://api.mobileapi.dev/',
  connectTimeout: const Duration(seconds: 15),
  receiveTimeout: const Duration(seconds: 15),
  headers: {'Accept': 'application/json'},
));

/// Busca specs na MobileAPI.dev para a descrição EXATA selecionada no
/// diálogo da 1ª API. A descrição verbosa é limpa antes de enviar
/// (`GET /devices/search/?name=<modelo limpo>&manufacturer=<marca>`).
/// Se a MobileAPI falhar (cota/rate-limit/sem resultado), cai para a
/// API gratuita do GSMArena (sem key) como fallback.
Future<CelularSpec?> fetchSpecsFromApi(String description) async {
  if (description.trim().isEmpty) return null;
  final viaMobile = await _fetchFromMobileApi(description);
  if (viaMobile != null &&
      viaMobile.specs.length >= 3 &&
      viaMobile.specs.any((s) => s != 'Especificações não disponíveis')) {
    return viaMobile;
  }
  final viaGsm = await _fetchFromGsmFallback(description);
  return viaGsm ?? viaMobile;
}

Future<CelularSpec?> _fetchFromMobileApi(String description) async {
  if (description.trim().isEmpty) return null;
  final query = _cleanApiQuery(description);
  final manufacturer = _detectManufacturer(description);
  if (query.isEmpty) return null;

  try {
    final response = await _mobileApi.get(
      'devices/search/',
      queryParameters: {
        'name': query,
        'limit': 5,
        if (manufacturer case final m) 'manufacturer': m,
        if (mobileApiKey.isNotEmpty) 'key': mobileApiKey,
      },
      options: Options(
        headers: {
          if (mobileApiKey.isNotEmpty) 'Authorization': 'Token $mobileApiKey',
        },
      ),
    );

    final candidates = _deviceMaps(response.data);
    if (candidates.isEmpty) return null;

    final best = _pickBest(candidates, query);

    // Trava: se o melhor resultado não tem nenhum token em comum com o
    // que foi selecionado, não adiciona aparelho errado ao catálogo.
    final bestName = _normalizeDesc(_firstText(best, const [
      'name', 'model', 'modelo', 'device', 'title',
    ]));
    final queryTokens = query.split(' ').where((t) => t.length > 2).toList();
    if (queryTokens.isNotEmpty &&
        !queryTokens.any(bestName.contains)) {
      return null;
    }

    // Detalhe completo /devices/{id}/ (traz CPU octa, frontal, RAM por
    // variante...). Plano Free limita ritmo: em 429 espera e tenta 1x.
    Map<String, dynamic> device = best;
    final detailId = best['id'];
    if (detailId != null) {
      device = await _fetchDetail(detailId, fallback: best);
    }

    return _buildSpec(device, description);
  } on DioException {
    return null;
  } catch (_) {
    return null;
  }
}

/// Busca o detalhe com 1 retry em caso de 429 (rate-limit do plano Free).
Future<Map<String, dynamic>> _fetchDetail(
    dynamic detailId, {required Map<String, dynamic> fallback}) async {
  Future<Map<String, dynamic>?> once() async {
    try {
      final detail = await _mobileApi.get(
        'devices/$detailId/',
        queryParameters: {
          if (mobileApiKey.isNotEmpty) 'key': mobileApiKey,
        },
        options: Options(
          headers: {
            if (mobileApiKey.isNotEmpty) 'Authorization': 'Token $mobileApiKey',
          },
        ),
      );
      if (detail.data is Map) {
        return Map<String, dynamic>.from(detail.data as Map);
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 429) rethrow;
    } catch (_) {}
    return null;
  }

  try {
    final first = await once();
    if (first != null) return first;
  } on DioException catch (e) {
    if (e.response?.statusCode == 429) {
      await Future.delayed(const Duration(seconds: 12));
      try {
        final second = await once();
        if (second != null) return second;
      } catch (_) {}
    }
  } catch (_) {}
  return fallback;
}

/// Base da API gratuita (GSMArena, sem key). Pode apontar p/ deploy próprio:
/// `flutter build apk --dart-define=GSM_API_URL=https://seu-deploy.vercel.app/`.
const String gsmArenaBaseUrl = String.fromEnvironment(
  'GSM_API_URL',
  defaultValue: 'https://mobile-specs-api-sandy.vercel.app/',
);

final Dio _gsmApi = Dio(BaseOptions(
  baseUrl: gsmArenaBaseUrl,
  connectTimeout: const Duration(seconds: 30),
  receiveTimeout: const Duration(seconds: 30),
  headers: {'Accept': 'application/json'},
));

/// Fallback gratuito: tabela completa do GSMArena via `/phone?name=`
/// (processador octa, frontal, bateria, RAM da variante...).
Future<CelularSpec?> _fetchFromGsmFallback(String description) async {
  final query = _cleanApiQuery(description);
  if (query.isEmpty) return null;
  try {
    final resp = await _gsmApi.get(
      'phone',
      queryParameters: {'name': query},
    );
    final data = resp.data;
    if (data is! Map || data['status'] != true) return null;
    final infoRaw = data['data'];
    if (infoRaw is! Map) return null;
    final info = Map<String, dynamic>.from(infoRaw);

    // Confere se o pareado é mesmo o selecionado (anti-cruzamento).
    final matched = _normalizeDesc(
        '${data['matched'] ?? ''} ${info['model'] ?? ''}');
    final tokens = query.split(' ').where((t) => t.length > 2).toList();
    if (tokens.isNotEmpty && !tokens.any(matched.contains)) return null;

    final model = (info['model'] ?? '').toString().trim();
    if (model.isEmpty) return null;
    final specs = _specsFromGsmTable(info, description);
    return CelularSpec(
      id: 'gsm-${DateTime.now().millisecondsSinceEpoch}',
      marca: _guessBrand(model),
      modelo: model.toUpperCase(),
      armazenamento: _extractStorageFromText(description),
      specs: specs.isEmpty ? ['Especificações não disponíveis'] : specs,
    );
  } catch (_) {
    return null;
  }
}

/// Extrai as 5 specs da tabela do GSMArena (chaves de câmera variam:
/// Single/Dual/Triple/Quad; valores podem conter HTML).
List<String> _specsFromGsmTable(
    Map<String, dynamic> info, String description) {
  final out = <String>[];
  final tablesRaw = info['specifications'];
  final tables =
      tablesRaw is Map ? Map<String, dynamic>.from(tablesRaw) : {};

  String tableValue(String table, List<String> preferKeys) {
    final t = tables[table];
    if (t is! Map) return '';
    final m = Map<String, dynamic>.from(t);
    for (final k in preferKeys) {
      final v = _stripHtml((m[k] ?? '').toString());
      if (v.isNotEmpty) return v;
    }
    return '';
  }

  String firstMpValue(String table) {
    final t = tables[table];
    if (t is! Map) return '';
    for (final v in Map<String, dynamic>.from(t).values) {
      final s = _stripHtml((v ?? '').toString());
      if (s.toUpperCase().contains('MP')) return s;
    }
    return '';
  }

  // 1. Câmera principal.
  final mainMps = _mpList(firstMpValue('Main Camera')).take(3).toList();
  if (mainMps.isNotEmpty) {
    out.add('câmera ${mainMps.map((m) => '$m Mp').join(' + ')}');
  }

  // 2. Frontal (chave "Selfie camera").
  var front = firstMpValue('Selfie camera');
  if (front.isEmpty) front = firstMpValue('Selfie Camera');
  final frontMps = _mpList(front);
  if (frontMps.isNotEmpty) out.add('câmera frontal ${frontMps.first}MP');

  // 3. RAM da variante selecionada.
  var mem = tableValue('Memory', const ['Internal']);
  if (mem.isEmpty) mem = _stripHtml((info['storage'] ?? '').toString());
  final ram = _ramForVariant(mem, _extractStorageFromText(description));
  if (ram.isNotEmpty) out.add(ram);

  // 4. Bateria.
  var bat = '';
  final bt = tables['Battery'];
  if (bt is Map) {
    for (final v in Map<String, dynamic>.from(bt).values) {
      final s = _stripHtml((v ?? '').toString());
      if (RegExp(r'\d{3,5}\s?MAH').hasMatch(s.toUpperCase())) {
        bat = s;
        break;
      }
    }
  }
  final batMatch = RegExp(r'(\d{3,5})\s?MAH').firstMatch(bat.toUpperCase());
  if (batMatch != null) out.add('bateria ${batMatch.group(1)} mAh');

  // 5. Processador.
  final cpu = _cpuLine(_stripHtml(tableValue('Platform', const ['CPU'])));
  if (cpu.isNotEmpty) {
    out.add(cpu);
  } else {
    final chip =
        _stripHtml(tableValue('Platform', const ['Chipset'])).split('(').first.trim();
    if (chip.isNotEmpty && chip.length <= 60) out.add('processador $chip');
  }

  // Ordem fixa: câmera, câmera frontal, bateria, RAM, processador.
  final ordered = <String>[];
  final want = ['câmera ', 'câmera frontal ', 'bateria ', 'GB de RAM', 'processador '];
  for (final prefix in want) {
    final found = out.firstWhere(
      (s) => s.startsWith(prefix),
      orElse: () => '',
    );
    if (found.isNotEmpty) ordered.add(found);
  }
  return ordered;
}

/// Remove tags HTML e entidades (ex: "&amp;", "<sup>").
String _stripHtml(String s) {
  var out = s.replaceAll(RegExp(r'<[^>]*>'), ' ');
  const entities = {
    '&amp;': '&',
    '&nbsp;': ' ',
    '&quot;': '"',
    '&#39;': "'",
    '&lt;': '<',
    '&gt;': '>',
  };
  entities.forEach((k, v) => out = out.replaceAll(k, v));
  return out.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Monta um [CelularSpec] no padrão do app (5 linhas: câmera, frontal,
/// RAM, bateria, processador) a partir do JSON da MobileAPI.
CelularSpec? _buildSpec(Map<String, dynamic> device, String fallbackQuery) {
  final brand = _firstText(device, const [
    'manufacturer_name',
    'manufacturer',
    'brand',
    'marca',
    'vendor',
    'company',
  ]);
  var name = _firstText(device, const [
    'name',
    'model',
    'modelo',
    'device',
    'title',
  ]);
  if (name.isEmpty) name = fallbackQuery;

  final storage = _extractStorage(device, fallbackQuery);

  final specs = _buildAppSpecs(device, storage);
  if (brand.isEmpty && name.isEmpty) return null;

  final rawId = _firstText(device, const ['id', 'slug', 'uid']);
  return CelularSpec(
    id: rawId.isEmpty
        ? 'api-${DateTime.now().millisecondsSinceEpoch}'
        : 'api-$rawId',
    marca: brand.isEmpty ? _guessBrand(name) : brand,
    modelo: name.toUpperCase(),
    armazenamento: storage.isEmpty ? _extractStorageFromText(fallbackQuery) : storage,
    specs: specs.isEmpty ? ['Especificações não disponíveis'] : specs,
  );
}

/// Extrai armazenamento priorizando a descrição SELECIONADA na 1ª API
/// (é a variante real do aparelho, ex: "S23 256GB"), e só depois os
/// campos genéricos vindos da MobileAPI.
String _extractStorage(Map<String, dynamic> device, String fallback) {
  final fromSelection =
      _extractStorageFromText('$fallback ${_stringify(device['name'])}');
  if (fromSelection != 'Não informado') return fromSelection;
  for (final key in const [
    'internal_storage',
    'internalStorage',
    'storage',
    'memory',
    'memory_internal',
    'variant',
    'armazenamento',
  ]) {
    final v = device[key];
    final text = _stringify(v);
    if (text.isNotEmpty) {
      final found = _extractStorageFromText(text);
      if (found.isNotEmpty && found != 'Não informado') return found;
    }
  }
  return 'Não informado';
}

String _extractStorageFromText(String text) {
  final upper = text.toUpperCase();
  final tb = RegExp(r'(\d+(?:[.,]\d+)?)\s?TB').firstMatch(upper);
  if (tb != null) {
    final num = tb.group(1)!.replaceAll(',', '.');
    final gb = (double.tryParse(num) ?? 0) * 1024;
    return '${gb.toInt()}GB';
  }
  final matches = RegExp(r'(\d{2,4})\s?GB').allMatches(upper).toList();
  if (matches.isEmpty) return 'Não informado';
  // Prefere o maior valor (armazenamento em vez de RAM quando vier junto).
  var best = 0;
  for (final m in matches) {
    final v = int.tryParse(m.group(1)!) ?? 0;
    if (v > best) best = v;
  }
  return '${best}GB';
}

/// Gera as specs no padrão do app a partir do schema real da MobileAPI:
/// `main_camera.modules` (ex: "50 MP, f/1.8...10 MP..."), `selfie_camera.modules`,
/// `memory.internal` ("128GB 8GB RAM, 256GB 8GB RAM..."), `battery.type`
/// ("Li-Ion 3900 mAh") e `platform.cpu` ("Octa-core (1x3.36 GHz...)").
/// Quando só há o item da busca, usa `camera`, `battery_capacity` e `hardware`.
List<String> _buildAppSpecs(Map<String, dynamic> device, String selectedStorage) {
  final out = <String>[];

  // 1. Câmera principal (até 3 módulos).
  var mainRaw = _subText(device, 'main_camera', const ['modules']);
  if (mainRaw.isEmpty) {
    mainRaw = _firstText(device, const ['camera', 'mainCamera', 'rear_camera']);
  }
  final mainMps = _mpList(mainRaw).take(3).toList();
  if (mainMps.isNotEmpty) {
    out.add('câmera ${mainMps.map((m) => '$m Mp').join(' + ')}');
  }

  // 2. Câmera frontal.
  var frontRaw = _subText(device, 'selfie_camera', const ['modules']);
  if (frontRaw.isEmpty) {
    frontRaw = _firstText(device, const ['selfieCamera', 'front_camera', 'camera_front']);
  }
  final frontMps = _mpList(frontRaw);
  if (frontMps.isNotEmpty) {
    out.add('câmera frontal ${frontMps.first}MP');
  }

  // 3. RAM da variante selecionada (ex: "256GB 8GB RAM" -> "8 GB de RAM").
  var memRaw = _subText(device, 'memory', const ['internal']);
  if (memRaw.isEmpty) memRaw = _firstText(device, const ['hardware', 'ram']);
  final ramLine = _ramForVariant(memRaw, selectedStorage);
  if (ramLine.isNotEmpty) out.add(ramLine);

  // 4. Bateria.
  var batRaw = _subText(device, 'battery', const ['type']);
  if (batRaw.isEmpty) {
    batRaw = _firstText(device, const ['battery_capacity', 'battery']);
  }
  final batMatch = RegExp(r'(\d{3,5})\s?MAH').firstMatch(batRaw.toUpperCase());
  if (batMatch != null) out.add('bateria ${batMatch.group(1)} mAh');

  // 5. Processador (núcleos + clock máx, ex: "Octa-core (1x3.36 GHz...)"
  // -> "processador 8 Core 3.36 GHZ").
  final cpuRaw = _subText(device, 'platform', const ['cpu']);
  final cpuLine = _cpuLine(cpuRaw);
  if (cpuLine.isNotEmpty) {
    out.add(cpuLine);
  } else {
    var chip = _subText(device, 'platform', const ['chipset']);
    if (chip.isEmpty) chip = _chipFromHardware(_firstText(device, const ['hardware']));
    chip = chip.split('(').first.trim();
    if (chip.isNotEmpty && chip.length <= 60) out.add('processador $chip');
  }

  // Ordem fixa exigida pelo app: câmera, câmera frontal, bateria, RAM, processador.
  final ordered = <String>[];
  final want = ['câmera ', 'câmera frontal ', 'bateria ', 'GB de RAM', 'processador '];
  for (final prefix in want) {
    final found = out.firstWhere(
      (s) => s.startsWith(prefix),
      orElse: () => '',
    );
    if (found.isNotEmpty) ordered.add(found);
  }
  return ordered;
}

/// Lê texto de um sub-objeto (ex: device['platform']['cpu']).
String _subText(Map<String, dynamic> data, String parent, List<String> keys) {
  final value = data[parent];
  if (value is Map) {
    return _firstText(Map<String, dynamic>.from(value), keys);
  }
  return '';
}

/// Todos os "NN MP" do texto (ex: ["50", "10", "12"]).
List<String> _mpList(String raw) {
  return RegExp(r'(\d+(?:[.,]\d+)?)\s?MP')
      .allMatches(raw.toUpperCase())
      .map((m) => m.group(1)!.replaceAll(',', '.'))
      .toList();
}

/// RAM da variante (ex: texto "128GB 8GB RAM, 256GB 12GB RAM" + variante
/// "256GB" -> "12 GB de RAM"). Sem variante, usa o primeiro "NGB RAM".
String _ramForVariant(String raw, String storage) {
  final upper = raw.toUpperCase();
  if (upper.isEmpty) return '';
  final storageDigits = RegExp(r'(\d+)').firstMatch(storage)?.group(1);
  if (storageDigits != null) {
    final m = RegExp('${storageDigits}GB\\s*(\\d{1,2})GB RAM').firstMatch(upper);
    if (m != null) return '${m.group(1)} GB de RAM';
  }
  final m = RegExp(r'(\d{1,2})GB RAM').firstMatch(upper);
  if (m != null) return '${m.group(1)} GB de RAM';
  return '';
}

/// "Octa-core (1x3.36 GHz Cortex-X3 & ...)" -> "processador 8 Core 3.36 GHZ".
String _cpuLine(String raw) {
  final upper = raw.toUpperCase();
  if (upper.trim().isEmpty) return '';
  const cores = {
    'DUAL-CORE': 2, 'DUAL CORE': 2,
    'QUAD-CORE': 4, 'QUAD CORE': 4,
    'HEXA-CORE': 6, 'HEXA CORE': 6,
    'OCTA-CORE': 8, 'OCTA CORE': 8,
    'DECA-CORE': 10, 'DECA CORE': 10,
  };
  int? coreCount;
  for (final entry in cores.entries) {
    if (upper.contains(entry.key)) {
      coreCount = entry.value;
      break;
    }
  }
  double best = 0;
  for (final m in RegExp(r'(\d(?:[.,]\d+)?)\s?GHZ').allMatches(upper)) {
    final v = double.tryParse(m.group(1)!.replaceAll(',', '.')) ?? 0;
    if (v > best) best = v;
  }
  if (coreCount != null && best > 0) {
    return 'processador $coreCount Core ${_trimGhz(best)} GHZ';
  }
  if (coreCount != null) return 'processador $coreCount Core';
  return '';
}

String _trimGhz(double v) =>
    v == v.roundToDouble() ? '${v.toInt()}' : '$v';

/// Chipset a partir do "hardware" da busca (ex: "8GB RAM, Snapdragon 8 Gen 2").
String _chipFromHardware(String hardware) {
  final parts = hardware.split(',');
  for (final p in parts) {
    final t = p.trim();
    if (t.isEmpty) continue;
    if (RegExp(r'\dGB RAM', caseSensitive: false).hasMatch(t)) continue;
    return t;
  }
  return '';
}

String _guessBrand(String name) {
  final u = name.toUpperCase();
  if (u.contains('GALAXY') || u.contains('SAMSUNG')) return 'Samsung';
  if (u.contains('MOTO') || u.contains('MOTOROLA') || u.contains('EDGE')) {
    return 'Motorola';
  }
  if (u.contains('IPHONE') || u.contains('APPLE')) return 'Apple';
  if (u.contains('XIAOMI') || u.contains('REDMI') || u.contains('POCO')) {
    return 'Xiaomi';
  }
  return 'Desconhecido';
}

/// Escolhe o melhor candidato priorizando match_certainty / exatidão.
Map<String, dynamic> _pickBest(
    List<Map<String, dynamic>> candidates, String query) {
  Map<String, dynamic> best = candidates.first;
  var bestScore = -1.0;
  final q = query.toLowerCase();
  for (final c in candidates) {
    var score = 0.0;
    final cert = c['match_certainty'] ?? c['matchCertainty'] ?? c['score'];
    if (cert is num) score += cert.toDouble();
    final name = _firstText(c, const ['name', 'model']).toLowerCase();
    if (name.isNotEmpty && q.contains(name.split(' ').last)) score += 10;
    if ((c['match_type'] ?? c['matchType']) == 'exact_model') score += 50;
    if (score > bestScore) {
      bestScore = score;
      best = c;
    }
  }
  return best;
}

List<Map<String, dynamic>> _deviceMaps(dynamic data) {
  if (data is List) {
    return data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }
  if (data is Map) {
    for (final key in const ['devices', 'items', 'results', 'data', 'content', 'value']) {
      final nested = _deviceMaps(data[key]);
      if (nested.isNotEmpty) return nested;
    }
    return [Map<String, dynamic>.from(data)];
  }
  return [];
}

String _firstText(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
    if (value is num) return value.toString();
  }
  return '';
}

List<String> _readSpecs(Map<String, dynamic> data) {
  final output = <String>[];
  final specs = data['specs'] ?? data['specifications'];
  if (specs is List) {
    output.addAll(specs.map((e) => e.toString()).where((e) => e.trim().isNotEmpty));
  } else if (specs is Map) {
    specs.forEach((key, value) {
      if (value != null && value.toString().trim().isNotEmpty) {
        output.add('$key: $value');
      }
    });
  }
  for (final entry in <String, String>{
    'RAM': _firstText(data, const ['ram', 'memoryRam']),
    'Tela': _nestedText(data, 'display', const ['size', 'screenSize']),
    'Câmera': _nestedText(data, 'camera', const ['main', 'primary']),
    'Bateria': _nestedText(data, 'battery', const ['capacity', 'size']),
    'Processador': _nestedText(data, 'processor', const ['chipset', 'cpu']),
  }.entries) {
    if (entry.value.isNotEmpty) output.add('${entry.key}: ${entry.value}');
  }
  return output.toSet().toList();
}

String _nestedText(Map<String, dynamic> data, String parent, List<String> keys) {
  final value = data[parent];
  if (value is Map) return _firstText(Map<String, dynamic>.from(value), keys);
  return value is String ? value : '';
}

String _stringify(dynamic value) {
  if (value == null) return '';
  if (value is String) return value;
  if (value is num) return value.toString();
  if (value is List) {
    return value.map(_stringify).where((s) => s.isNotEmpty).join(', ');
  }
  if (value is Map) {
    return Map<String, dynamic>.from(value)
        .values
        .map(_stringify)
        .where((s) => s.isNotEmpty)
        .join(', ');
  }
  return value.toString();
}

/// Fluxo da seleção no diálogo da 1ª API:
/// 1. Se a descrição IDÊNTICA já está no catálogo (assets ou já buscada),
///    usa ela; 2. Senão busca as specs corretas na MobileAPI.dev para
/// AQUELE aparelho, adiciona como nova entrada no catálogo e retorna.
/// Nunca escolhe um modelo "semelhante" — sem idêntico, vai p/ internet.
Future<CelularSpec?> getOrCreateSpecs(String description, List<CelularSpec> baseList) async {
  final local = findExactPhone(baseList, description);
  if (local != null) return local;
  final saved = findExactPhone(await loadSavedPhones(), description);
  if (saved != null) return saved;
  final fetched = await fetchSpecsFromApi(description);
  if (fetched != null) await addSavedPhone(fetched);
  return fetched;
}
