## 1.0.0

First stable release. This version fixes correctness bugs in 0.0.x and contains
breaking changes — read the migration notes below before upgrading.

### Fixed

- **`POST`, `PUT`, `PATCH` and `DELETE` are no longer cached.** Previously every
  method was cached, so a repeated `POST` could return a stored response instead
  of creating a resource, and a repeated `DELETE` could report success without
  reaching the server.
- **Error responses are no longer cached.** A `500` used to be stored and
  replayed for the whole cache duration, so a brief outage looked like a
  sustained one.
- **Cache keys can no longer collide.** Keys were a bare concatenation of URL,
  header names and values, so `{'ab': 'c'}` and `{'a': 'bc'}` produced the same
  key. Keys are now separated, lower-cased, sorted and hashed.
- **Cache keys no longer depend on header ordering.** Two identical requests
  built from differently ordered maps produced different keys and each missed
  the other's entry.
- **File caching now works.** `FileCacheStorage` was never wired into the
  client, so the "file-based storage" advertised in 0.0.2 was unreachable. It is
  replaced by `FileCacheManager`, which the client accepts directly.
- **Cached status codes are preserved.** The file backend rebuilt every response
  as `200`, discarding the original status.
- **Cache filenames are hashed.** Raw URLs were used as filenames, so any key
  containing `/` or `:` wrote to an unintended path or failed.
- **The file backend honours its configured duration.** It previously ignored
  the caller's value and hard-coded five minutes.
- **`CacheManager` and `InMemoryCacheManager` are exported.** The library barrel
  exported neither, so the `cacheManager:` parameter could not be used from
  outside the package.
- **Corrupted cache files no longer throw.** They are treated as a miss and
  deleted.

### Added

- `close()` to release the underlying `http.Client`. A client passed to the
  constructor stays owned by the caller and is left open.
- `clearCache()` and `invalidate(url)` for explicit invalidation.
- `head()` support.
- Bounded memory cache: `InMemoryCacheManager` holds at most `maxEntries`
  (default 100) and evicts the least recently used entry. Expired entries are
  removed on read instead of being retained forever.
- `CacheEntry`, a serialisable response record with an injectable clock for
  freshness checks.
- `CachedHttpClient.cacheKeyFor`, exposed so key behaviour can be tested.
- A test suite covering cache hits, expiry, method safety, status-code rules,
  key canonicalisation, eviction and the file backend. Tests use a mock
  transport and no longer depend on network access or real delays.
- GitHub Actions CI running format, analyze and test.

### Changed

- **Breaking:** `CacheManager` gains `remove` and `clear`. Custom
  implementations must add both.
- **Breaking:** `CacheStorage` and `FileCacheStorage` are removed. Use
  `FileCacheManager`.
- **Breaking:** passing both `cacheManager` and `cacheDuration` now asserts, as
  the duration was silently ignored. Set the duration on the manager.
- `crypto` added as a dependency for cache-key and filename hashing.

## 0.0.2

- **Added**: Support for custom cache storage options. You can now choose between in-memory and file-based storage for cached responses.
- **Enhanced**: Improved error handling with more descriptive error messages for failed requests.
- **Fixed**: Bug where cache expiration was not correctly applied in some edge cases.
- **Updated**: Documentation to include new features and usage examples.
- **Optimized**: Performance improvements in cache management and request handling.

## 0.0.1

- Initial release with basic HTTP request caching functionality.
