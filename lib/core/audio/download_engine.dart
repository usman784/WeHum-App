import 'dart:io';
import 'package:dio/dio.dart';

class DownloadCancelled implements Exception {}

class NotEnoughSpace implements Exception {
  NotEnoughSpace(this.needed);
  final int needed;
}

/// Wi-Fi only is on and the phone is on mobile data (Reminders & sounds → Wi-Fi only).
class WifiRequired implements Exception {}

/// Resumable file download (spec §10): `Range` from the bytes already on disk, progress callbacks, cancel.
abstract class DownloadEngine {
  /// Downloads [url] into [path] (appending when [resumeFrom] > 0). Returns the total size.
  Future<int> download(String url, String path, {int resumeFrom = 0, void Function(int received, int total)? onProgress, CancelToken? cancel});
}

class DioDownloadEngine implements DownloadEngine {
  DioDownloadEngine([Dio? dio]) : _dio = dio ?? Dio(BaseOptions(connectTimeout: const Duration(seconds: 15), receiveTimeout: const Duration(minutes: 5)));
  final Dio _dio;

  @override
  Future<int> download(String url, String path, {int resumeFrom = 0, void Function(int received, int total)? onProgress, CancelToken? cancel}) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    final res = await _dio.get<ResponseBody>(url, cancelToken: cancel, options: Options(responseType: ResponseType.stream, headers: {if (resumeFrom > 0) 'Range': 'bytes=$resumeFrom-'}, validateStatus: (s) => s == 200 || s == 206));
    final resumed = res.statusCode == 206;
    final len = int.tryParse(res.headers.value(Headers.contentLengthHeader) ?? '') ?? 0;
    final total = resumed ? resumeFrom + len : len;
    var received = resumed ? resumeFrom : 0;
    final sink = file.openWrite(mode: resumed ? FileMode.append : FileMode.write);
    try {
      await for (final chunk in res.data!.stream) {
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(received, total);
      }
    } finally {
      await sink.flush();
      await sink.close();
    }
    return received;
  }
}

/// Free space probe (spec §10 "Low storage"): checked before a download starts.
abstract class StorageProbe {
  Future<int?> freeBytes();
}

class NoStorageProbe implements StorageProbe {
  const NoStorageProbe();
  @override
  Future<int?> freeBytes() async => null;
}
