import 'package:http/http.dart' as http;
import 'cache_manager.dart';

class CachedHttpClient {
  final http.Client _client;
  final CacheManager _cacheManager;

  CachedHttpClient({
    http.Client? client,
    CacheManager? cacheManager,
    Duration? cacheDuration,
  })  : _client = client ?? http.Client(),
        _cacheManager =
            cacheManager ?? InMemoryCacheManager(cacheDuration: cacheDuration);

  Future<http.Response> get(String url, {Map<String, String>? headers}) async {
    final cacheKey = _generateCacheKey(url, headers);
    final cachedResponse = await _cacheManager.get(cacheKey);

    if (cachedResponse != null) {
      return cachedResponse;
    }

    final response = await _client.get(Uri.parse(url), headers: headers);
    await _cacheManager.set(cacheKey, response);
    return response;
  }

  Future<http.Response> post(String url,
      {Map<String, String>? headers, Object? body}) async {
    final cacheKey = _generateCacheKey(url, headers, body);
    final cachedResponse = await _cacheManager.get(cacheKey);

    if (cachedResponse != null) {
      return cachedResponse;
    }

    final response =
        await _client.post(Uri.parse(url), headers: headers, body: body);
    await _cacheManager.set(cacheKey, response);
    return response;
  }

  Future<http.Response> put(String url,
      {Map<String, String>? headers, Object? body}) async {
    final cacheKey = _generateCacheKey(url, headers, body);
    final cachedResponse = await _cacheManager.get(cacheKey);

    if (cachedResponse != null) {
      return cachedResponse;
    }

    final response =
        await _client.put(Uri.parse(url), headers: headers, body: body);
    await _cacheManager.set(cacheKey, response);
    return response;
  }

  Future<http.Response> delete(String url,
      {Map<String, String>? headers}) async {
    final cacheKey = _generateCacheKey(url, headers);
    final cachedResponse = await _cacheManager.get(cacheKey);

    if (cachedResponse != null) {
      return cachedResponse;
    }

    final response = await _client.delete(Uri.parse(url), headers: headers);
    await _cacheManager.set(cacheKey, response);
    return response;
  }

  Future<http.Response> patch(String url,
      {Map<String, String>? headers, Object? body}) async {
    final cacheKey = _generateCacheKey(url, headers, body);
    final cachedResponse = await _cacheManager.get(cacheKey);

    if (cachedResponse != null) {
      return cachedResponse;
    }

    final response =
        await _client.patch(Uri.parse(url), headers: headers, body: body);
    await _cacheManager.set(cacheKey, response);
    return response;
  }

  String _generateCacheKey(String url, Map<String, String>? headers,
      [Object? body]) {
    final buffer = StringBuffer(url);
    headers?.forEach((key, value) {
      buffer.write('$key:$value');
    });
    if (body != null) {
      buffer.write(body.toString());
    }
    return buffer.toString();
  }
}
