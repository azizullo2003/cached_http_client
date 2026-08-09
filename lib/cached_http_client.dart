/// An HTTP client for Flutter that caches safe requests locally.
///
/// See [CachedHttpClient] to get started, [InMemoryCacheManager] for the
/// default process-local store, and [FileCacheManager] for a store that
/// survives app restarts.
library;

export 'src/cache_entry.dart';
export 'src/cache_manager.dart';
export 'src/cached_http_client.dart';
export 'src/file_cache_manager.dart';
