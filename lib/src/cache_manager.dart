import 'dart:collection';

import 'package:http/http.dart' as http;

import 'cache_entry.dart';

/// Storage backend for cached responses.
///
/// Implement this to plug in your own store (Hive, sqflite, a remote cache).
/// The client only ever calls [get], [set], [remove] and [clear], so a backend
/// is free to decide how entries are serialised and evicted.
abstract class CacheManager {
  /// How long a stored response stays fresh.
  Duration get cacheDuration;

  /// Returns the cached response for [key], or `null` when absent or stale.
  ///
  /// Implementations must not return an expired entry.
  Future<http.Response?> get(String key);

  /// Stores [response] under [key].
  Future<void> set(String key, http.Response response);

  /// Drops the entry for [key], if any.
  Future<void> remove(String key);

  /// Drops every entry.
  Future<void> clear();
}

/// Process-local cache with a bounded size and least-recently-used eviction.
///
/// Entries are dropped when they expire, and the oldest entry is evicted once
/// [maxEntries] is reached, so a long-lived client cannot grow without bound.
class InMemoryCacheManager implements CacheManager {
  /// Creates an in-memory cache.
  ///
  /// [cacheDuration] defaults to five minutes and [maxEntries] to 100.
  InMemoryCacheManager({
    Duration? cacheDuration,
    this.maxEntries = defaultMaxEntries,
  })  : assert(maxEntries > 0, 'maxEntries must be greater than zero'),
        _cacheDuration = cacheDuration ?? defaultCacheDuration;

  /// Time-to-live applied when the caller does not supply one.
  static const Duration defaultCacheDuration = Duration(minutes: 5);

  /// Entry ceiling applied when the caller does not supply one.
  static const int defaultMaxEntries = 100;

  /// Maximum number of entries retained before the oldest is evicted.
  final int maxEntries;

  final Duration _cacheDuration;

  // Insertion-ordered, so the first key is always the least recently used.
  final LinkedHashMap<String, CacheEntry> _entries =
      LinkedHashMap<String, CacheEntry>();

  @override
  Duration get cacheDuration => _cacheDuration;

  /// Number of entries currently held.
  int get length => _entries.length;

  @override
  Future<http.Response?> get(String key) async {
    final entry = _entries[key];
    if (entry == null) return null;

    if (!entry.isFresh(_cacheDuration)) {
      _entries.remove(key);
      return null;
    }

    // Re-insert so this key becomes the most recently used.
    _entries
      ..remove(key)
      ..[key] = entry;
    return entry.toResponse();
  }

  @override
  Future<void> set(String key, http.Response response) async {
    if (_entries.length >= maxEntries && !_entries.containsKey(key)) {
      _entries.remove(_entries.keys.first);
    }
    _entries[key] = CacheEntry.fromResponse(response);
  }

  @override
  Future<void> remove(String key) async {
    _entries.remove(key);
  }

  @override
  Future<void> clear() async {
    _entries.clear();
  }
}
