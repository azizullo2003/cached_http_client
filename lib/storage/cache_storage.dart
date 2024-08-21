import 'package:http/http.dart' as http;

abstract class CacheStorage {
  Future<http.Response?> get(String key);
  Future<void> set(String key, http.Response response);
}
