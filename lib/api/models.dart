double? _parseDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) {
    final s = v.trim().replaceAll(RegExp(r'[^0-9,.-]'), '');
    if (s.isEmpty) return null;
    final normalized = s.contains(',') && s.lastIndexOf(',') > s.lastIndexOf('.')
        ? s.replaceAll('.', '').replaceAll(',', '.')
        : s.replaceAll(',', '');
    return double.tryParse(normalized);
  }
  if (v is Map) {
    for (final key in ['value', 'price', 'amount', 'valor', 'preco']) {
      final r = _parseDouble(v[key]);
      if (r != null) return r;
    }
  }
  return null;
}

int? _parseInt(dynamic v) {
  final d = _parseDouble(v);
  if (d == null) return null;
  return d.round();
}

bool? _parseBool(dynamic v) {
  if (v == null) return null;
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) {
    final s = v.toLowerCase().trim();
    if (s == 'true' || s == '1' || s == 'yes' || s == 'sim') return true;
    if (s == 'false' || s == '0' || s == 'no' || s == 'nao') return false;
  }
  return null;
}

String _parsePriceString(dynamic v) {
  if (v == null) return '';
  if (v is num) return v.toString();
  if (v is String) return v;
  if (v is Map) {
    final d = _parseDouble(v);
    if (d != null) return d.toString();
    for (final key in ['value', 'price', 'amount', 'valor', 'preco']) {
      final inner = v[key];
      if (inner is num || inner is String) return inner.toString();
    }
  }
  return '';
}

class PriceSign {
  final String id;
  final String sap;
  final String department;
  final String ean;
  final String description;
  final String startDate;
  final String endDate;
  final String duration;
  final String price;
  final String movement;
  final String status;
  final bool checkbox;
  final int quantity;
  final PapeletaPrintingData? printingData;

  PriceSign({
    required this.id,
    required this.sap,
    required this.department,
    required this.ean,
    required this.description,
    required this.startDate,
    required this.endDate,
    required this.duration,
    required this.price,
    required this.movement,
    required this.status,
    this.checkbox = false,
    this.quantity = 1,
    this.printingData,
  });

  factory PriceSign.fromJson(Map<String, dynamic> json) {
    return PriceSign(
      id: (json['id'] ?? '').toString(),
      sap: (json['sap'] ?? '').toString(),
      department: (json['department'] ?? '').toString(),
      ean: (json['ean'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      startDate: (json['startDate'] ?? '').toString(),
      endDate: (json['endDate'] ?? '').toString(),
      duration: (json['duration'] ?? '').toString(),
      price: _parsePriceString(json['price']),
      movement: (json['movement'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      checkbox: _parseBool(json['checkbox']) ?? false,
      quantity: _parseInt(json['quantity']) ?? 1,
      printingData: json['_printingData'] is Map
          ? PapeletaPrintingData.fromJson(Map<String, dynamic>.from(json['_printingData'] as Map))
          : null,
    );
  }
}

class PapeletaPrintingData {
  final String? template;
  final String productName;
  final double price;
  final double? promotionPrice;
  final int? takeAndWinQuantity;
  final double? takeAndWinPrice;
  final int? takeAndWinPercent;
  final double? installmentPrice;
  final int? installmentQuantity;
  final String codSap;
  final String ean;
  final String referenceDate;
  final String? size;
  final int? quantity;
  final String unit;

  PapeletaPrintingData({
    this.template,
    required this.productName,
    required this.price,
    this.promotionPrice,
    this.takeAndWinQuantity,
    this.takeAndWinPrice,
    this.takeAndWinPercent,
    this.installmentPrice,
    this.installmentQuantity,
    required this.codSap,
    required this.ean,
    required this.referenceDate,
    this.size,
    this.quantity,
    required this.unit,
  });

  factory PapeletaPrintingData.fromJson(Map<String, dynamic> json) {
    return PapeletaPrintingData(
      template: json['template'] is String ? json['template'] as String : null,
      productName: (json['productName'] ?? '').toString(),
      price: _parseDouble(json['price']) ?? 0.0,
      promotionPrice: _parseDouble(json['promotionPrice']),
      takeAndWinQuantity: _parseInt(json['takeAndWinQuantity']),
      takeAndWinPrice: _parseDouble(json['takeAndWinPrice']),
      takeAndWinPercent: _parseInt(json['takeAndWinPercent']),
      installmentPrice: _parseDouble(json['installmentPrice']),
      installmentQuantity: _parseInt(json['installmentQuantity']),
      codSap: (json['codSap'] ?? '').toString(),
      ean: (json['ean'] ?? '').toString(),
      referenceDate: (json['referenceDate'] ?? '').toString(),
      size: json['size'] is String ? json['size'] as String : null,
      quantity: _parseInt(json['quantity']),
      unit: (json['unit'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (template != null) 'template': template,
      'productName': productName,
      'price': price,
      if (promotionPrice != null) 'promotionPrice': promotionPrice,
      if (takeAndWinQuantity != null) 'takeAndWinQuantity': takeAndWinQuantity,
      if (takeAndWinPrice != null) 'takeAndWinPrice': takeAndWinPrice,
      if (takeAndWinPercent != null) 'takeAndWinPercent': takeAndWinPercent,
      if (installmentPrice != null) 'installmentPrice': installmentPrice,
      if (installmentQuantity != null) 'installmentQuantity': installmentQuantity,
      'codSap': codSap,
      'ean': ean,
      'referenceDate': referenceDate,
      if (size != null) 'size': size,
      if (quantity != null) 'quantity': quantity,
      'unit': unit,
    };
  }
}

class PapeletaStandaloneResponse {
  final List<PriceSign> items;

  PapeletaStandaloneResponse({required this.items});

  factory PapeletaStandaloneResponse.fromJson(Map<String, dynamic> json) {
    final list = (json['items'] as List?) ?? [];
    return PapeletaStandaloneResponse(
      items: list
          .whereType<Map>()
          .map((e) => PriceSign.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

class SendPriceSignRequest {
  final List<PapeletaPrintingData> products;

  SendPriceSignRequest({required this.products});

  Map<String, dynamic> toJson() => {'products': products.map((e) => e.toJson()).toList()};
}
