import 'package:starpath/core/api_client.dart';
import 'package:starpath/features/profile/domain/currency_model.dart';

class CurrencyRepository {
  final _api = ApiClient();

  Future<CurrencyAccount> getBalance() async {
    final response = await _api.dio.get('/wallet/balance');
    return CurrencyAccount.fromJson(response.data['data']);
  }

  Future<List<CurrencyTransaction>> getTransactions({String? cursor}) async {
    final params = <String, dynamic>{};
    if (cursor != null) params['cursor'] = cursor;

    final response = await _api.dio.get('/wallet/transactions',
        queryParameters: params);
    final data = response.data['data'] as List;
    return data.map((e) => CurrencyTransaction.fromJson(e)).toList();
  }

  Future<int> dailyCheckIn() async {
    final response = await _api.dio.post('/wallet/check-in');
    return response.data['data']['reward'] as int;
  }
}
