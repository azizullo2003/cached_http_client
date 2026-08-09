import 'package:http/http.dart' as http;

/// A stored HTTP response together with the moment it was written to the cache.
///
/// Entries are immutable. Freshness is evaluated against a caller-supplied
/// [Duration] rather than being baked in, so the same entry can be reused by
/// caches configured with different time-to-live values.
class CacheEntry {
  /// Creates an entry from its individual parts.
  const CacheEntry({
    required this.statusCode,
    required this.body,
    required this.headers,
    required this.storedAt,
  });

  /// Captures [response] as a cache entry stamped at [storedAt] (defaults to
  /// the current time).
  factory CacheEntry.fromResponse(http.Response response,
      {DateTime? storedAt}) {
    return CacheEntry(
      statusCode: response.statusCode,
      body: response.body,
      headers: Map<String, String>.unmodifiable(response.headers),
      storedAt: storedAt ?? DateTime.now(),
    );
  }

  /// Restores an entry previously produced by [toJson].
  factory CacheEntry.fromJson(Map<String, dynamic> json) {
    return CacheEntry(
      statusCode: json['statusCode'] as int,
      body: json['body'] as String,
      headers: Map<String, String>.unmodifiable(
        (json['headers'] as Map).cast<String, String>(),
      ),
      storedAt: DateTime.parse(json['storedAt'] as String),
    );
  }

  /// The status code of the cached response.
  final int statusCode;

  /// The body of the cached response.
  final String body;

  /// The headers of the cached response.
  final Map<String, String> headers;

  /// When this entry was written to the cache.
  final DateTime storedAt;

  /// Whether this entry is still within [ttl].
  ///
  /// [now] exists so tests can evaluate freshness without waiting in real time.
  bool isFresh(Duration ttl, {DateTime? now}) {
    return (now ?? DateTime.now()).difference(storedAt) < ttl;
  }

  /// Rebuilds the cached response, preserving the original status code.
  http.Response toResponse() {
    return http.Response(body, statusCode, headers: headers);
  }

  /// Serialises this entry for persistent stores.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'statusCode': statusCode,
      'body': body,
      'headers': headers,
      'storedAt': storedAt.toIso8601String(),
    };
  }
}
