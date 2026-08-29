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
