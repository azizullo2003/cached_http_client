import 'dart:collection';
import 'package:http/http.dart' as http;

abstract class CacheManager {
  Future<http.Response?> get(String key);
  Future<void> set(String key, http.Response response);
  Duration get cacheDuration;
}

class InMemoryCacheManager extends CacheManager {
  final _cache = HashMap<String, _CacheEntry>();
  final Duration _cacheDuration;

  InMemoryCacheManager({Duration? cacheDuration})
      : _cacheDuration = cacheDuration ?? const Duration(minutes: 5);

  @override
  Duration get cacheDuration => _cacheDuration;

  @override
  Future<http.Response?> get(String key) async {
    final entry = _cache[key];
    if (entry != null && _isValid(entry)) {
      return entry.response;
    }
    return null;
  }

  @override
  Future<void> set(String key, http.Response response) async {
    _cache[key] = _CacheEntry(response, DateTime.now());
  }

  bool _isValid(_CacheEntry entry) {
    return DateTime.now().difference(entry.timestamp) < _cacheDuration;
  }
}

class _CacheEntry {
  final http.Response response;
  final DateTime timestamp;

  _CacheEntry(this.response, this.timestamp);
}
