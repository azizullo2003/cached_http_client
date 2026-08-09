# cached_http_client

[![pub package](https://img.shields.io/pub/v/cached_http_client.svg)](https://pub.dev/packages/cached_http_client)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

An HTTP client for Flutter that serves repeated `GET` and `HEAD` requests from a
local cache — in memory by default, on disk if you want it to survive restarts.

It wraps `package:http` rather than replacing it, so an existing `http.Client`
(including a mocked one) can be handed straight in.

## Install

```yaml
dependencies:
  cached_http_client: ^1.0.0
```

## Usage

```dart
import 'package:cached_http_client/cached_http_client.dart';

final client = CachedHttpClient(cacheDuration: const Duration(minutes: 10));

// First call goes to the network, the second is served from cache.
final response = await client.get('https://api.example.com/feed');

client.close();
```

### Persisting across restarts

```dart
final client = CachedHttpClient(
  cacheManager: await FileCacheManager.create(
    cacheDuration: const Duration(hours: 6),
  ),
);
```

### Invalidating

```dart
await client.invalidate('https://api.example.com/feed'); // one entry
await client.clearCache();                               // everything
```

### Your own backend

Implement `CacheManager` to store entries wherever you like — Hive, sqflite, a
shared cache:

```dart
class HiveCacheManager implements CacheManager {
  @override
  Duration get cacheDuration => const Duration(hours: 1);

  @override
  Future<http.Response?> get(String key) async { /* ... */ }

  @override
  Future<void> set(String key, http.Response response) async { /* ... */ }

  @override
  Future<void> remove(String key) async { /* ... */ }

  @override
  Future<void> clear() async { /* ... */ }
}
```

## What is and isn't cached

| | Cached |
|---|---|
| `GET`, `HEAD` | yes |
| `POST`, `PUT`, `PATCH`, `DELETE` | no — replaying a stored response would repeat a state change |
| 2xx responses | yes |
| 3xx, 4xx, 5xx | no — an outage must not be pinned for the rest of the TTL |

Cache keys are built from the method, URL and headers. Header names are
lower-cased and sorted, so two logically identical requests share an entry
regardless of map ordering, and the parts are separated before hashing so
`{'ab': 'c'}` and `{'a': 'bc'}` cannot collide.

Requests with different `Authorization` headers get different entries, so one
user's response is never served to another.

## When not to use this

- **You need HTTP cache semantics.** This ignores `Cache-Control`, `ETag` and
  `Last-Modified` and applies a single TTL you choose. If you need conditional
  requests and revalidation, use a package built on the HTTP caching spec.
- **You need offline-first reads.** A stale entry is discarded, not served. There
  is no stale-while-revalidate.
- **Your responses are large binaries.** Bodies are held as strings.

## Memory behaviour

`InMemoryCacheManager` keeps at most 100 entries by default and evicts the
least recently used one at capacity; expired entries are dropped on read.
Adjust with `InMemoryCacheManager(maxEntries: 500)`.

## Contributing

```bash
flutter pub get
flutter analyze
flutter test
```

## License

MIT — see [LICENSE](LICENSE).
