import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:get/get.dart';
import '../config/env.dart';

/// Network state (spec §10): link status from the OS, then a real reachability check (`GET /healthz`, 3 s).
class ConnectivityService extends GetxService {
  ConnectivityService({Connectivity? connectivity, Dio? probe}) : _c = connectivity ?? Connectivity(), _probe = probe ?? Dio(BaseOptions(baseUrl: Env.apiBaseUrl, connectTimeout: const Duration(seconds: 3), receiveTimeout: const Duration(seconds: 3)));
  final Connectivity _c;
  final Dio _probe;
  StreamSubscription<List<ConnectivityResult>>? _sub;

  final online = true.obs;

  @override
  void onInit() {
    super.onInit();
    _sub = _c.onConnectivityChanged.listen((r) async => online.value = r.any((x) => x != ConnectivityResult.none) && await reachable());
  }

  Future<bool> reachable() async {
    try {
      final r = await _probe.get('/healthz');
      return (r.statusCode ?? 500) < 500;
    } catch (_) {
      return false;
    }
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }
}
