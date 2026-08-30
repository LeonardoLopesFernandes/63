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
      price: (json['price'] is Map<String, dynamic>
          ? (json['price'] as Map<String, dynamic>)['value']?.toString() ?? ''
          : (json['price'] ?? '').toString()),
      movement: (json['movement'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      checkbox: json['checkbox'] as bool? ?? false,
      quantity: json['quantity'] as int? ?? 1,
      printingData: json['_printingData'] == null
          ? null
          : PapeletaPrintingData.fromJson(json['_printingData'] as Map<String, dynamic>),
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
      template: json['template'] as String?,
      productName: (json['productName'] ?? '').toString(),
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      promotionPrice: (json['promotionPrice'] as num?)?.toDouble(),
      takeAndWinQuantity: json['takeAndWinQuantity'] as int?,
      takeAndWinPrice: (json['takeAndWinPrice'] as num?)?.toDouble(),
      takeAndWinPercent: json['takeAndWinPercent'] as int?,
      installmentPrice: (json['installmentPrice'] as num?)?.toDouble(),
      installmentQuantity: json['installmentQuantity'] as int?,
      codSap: (json['codSap'] ?? '').toString(),
      ean: (json['ean'] ?? '').toString(),
      referenceDate: (json['referenceDate'] ?? '').toString(),
      size: json['size'] as String?,
      quantity: json['quantity'] as int?,
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
      items: list.map((e) => PriceSign.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

class SendPriceSignRequest {
  final List<PapeletaPrintingData> products;

  SendPriceSignRequest({required this.products});

  Map<String, dynamic> toJson() => {'products': products.map((e) => e.toJson()).toList()};
}
