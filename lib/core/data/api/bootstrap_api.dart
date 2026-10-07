import 'package:dio/dio.dart';
import '../../network/api_client.dart';
import '../contracts/bootstrap_repository.dart';
import '../models/bootstrap.dart';

class BootstrapApi implements BootstrapRepository {
  BootstrapApi(this._api);
  final ApiClient _api;

  @override
  Future<Bootstrap> bootstrap() async {
    try {
      final r = await _api.dio.get('/v1/bootstrap', options: Options(extra: {'etag': true}));
      return Bootstrap.fromJson(((r.data as Map)['data'] as Map).cast<String, dynamic>());
    } catch (e) {
      throw ApiClient.map(e);
    }
  }
}
