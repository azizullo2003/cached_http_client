import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'cache_storage.dart';

class FileCacheStorage extends CacheStorage {
  final Directory _cacheDir;

  FileCacheStorage._(this._cacheDir);

  static Future<FileCacheStorage> create() async {
    final directory = await getTemporaryDirectory();
    return FileCacheStorage._(directory);
  }

  @override
  Future<http.Response?> get(String key) async {
    final file = File('${_cacheDir.path}/$key');
    if (await file.exists()) {
      final content = await file.readAsString();
      final json = jsonDecode(content);
      final headers = Map<String, String>.from(json['headers']);
      final body = json['body'];
      final cacheTime = DateTime.parse(json['cache-time']);
      return _isValid(cacheTime)
          ? http.Response(body, 200, headers: headers)
          : null;
    }
    return null;
  }

  @override
  Future<void> set(String key, http.Response response) async {
    final cacheHeaders = {
      'cache-time': DateTime.now().toIso8601String(),
    };
    final file = File('${_cacheDir.path}/$key');
    await file.writeAsString(jsonEncode({
      'headers': response.headers,
      'body': response.body,
      'cache-time': cacheHeaders['cache-time'],
    }));
  }

  bool _isValid(DateTime cacheTime) {
    // Define cache validity based on the desired duration
    const cacheDuration = Duration(minutes: 5); // Example duration
    return DateTime.now().difference(cacheTime) < cacheDuration;
  }
}
