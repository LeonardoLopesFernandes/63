import 'package:dio/dio.dart';
import 'package:papeleta63/api/client.dart';
import 'package:papeleta63/api/models.dart';

/// GET web/price-sign/store/{storeId}/standalone
Future<PapeletaStandaloneResponse> getPriceSignStandalone({
  required String storeId,
  required String type,
  String? ean,
  String? sapId,
  String? description,
  required String startDate,
}) async {
  final response = await apiClient.get(
    'web/price-sign/store/$storeId/standalone',
    queryParameters: {
      'type': type,
      if (ean != null && ean.isNotEmpty) 'ean': ean,
      if (sapId != null && sapId.isNotEmpty) 'sapId': sapId,
      if (description != null && description.isNotEmpty) 'description': description,
      'startDate': startDate,
    },
  );
  if (response.statusCode == 200) {
    return PapeletaStandaloneResponse.fromJson(response.data as Map<String, dynamic>);
  }
  throw DioException(
    requestOptions: response.requestOptions,
    response: response,
    message: 'HTTP ${response.statusCode}',
  );
}

/// GET web/price-tag/store/{storeId}/single-label-printing (busca por descrição)
Future<PapeletaStandaloneResponse> getSingleLabelPrinting({
  required String storeId,
  required String description,
  required String startDate,
}) async {
  final response = await apiClient.get(
    'web/price-tag/store/$storeId/single-label-printing',
    queryParameters: {
      'description': description,
      'startDate': startDate,
    },
  );
  if (response.statusCode == 200) {
    final data = response.data;
    List<dynamic> list;
    if (data is List) {
      list = data;
    } else if (data is Map) {
      list = data['items'] as List? ??
          data['content'] as List? ??
          data['data'] as List? ??
          data['results'] as List? ??
          data['value'] as List? ??
          data['labels'] as List? ??
          data['products'] as List? ??
          [];
    } else {
      list = [];
    }
    return PapeletaStandaloneResponse(
      items: list.map((e) => PriceSign.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
  throw DioException(
    requestOptions: response.requestOptions,
    response: response,
    message: 'HTTP ${response.statusCode}',
  );
}

/// POST web/price-sign/store/{storeId}/send
Future<void> sendPriceSigns({
  required String storeId,
  required SendPriceSignRequest request,
}) async {
  final response = await apiClient.post(
    'web/price-sign/store/$storeId/send',
    data: request.toJson(),
  );
  if (response.statusCode != 200 && response.statusCode != 201) {
    throw DioException(
      requestOptions: response.requestOptions,
      response: response,
      message: 'HTTP ${response.statusCode}',
    );
  }
}
