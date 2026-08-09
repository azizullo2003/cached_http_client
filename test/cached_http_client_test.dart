import 'package:cached_http_client/cached_http_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A mock transport that counts requests, so tests can assert on cache hits
/// instead of timing them.
class _RecordingClient {
  _RecordingClient({
    this.statusCode = 200,
    String Function(int callCount)? bodyBuilder,
  }) : _bodyBuilder = bodyBuilder ?? ((count) => 'body-$count');

  final int statusCode;
  final String Function(int) _bodyBuilder;
  final List<http.Request> requests = <http.Request>[];

  int get callCount => requests.length;

  MockClient get client => MockClient((request) async {
        requests.add(request);
        return http.Response(_bodyBuilder(callCount), statusCode);
      });
}

void main() {
  group('caching of safe methods', () {
    test('a second GET within the TTL is served from the cache', () async {
      final transport = _RecordingClient();
      final client = CachedHttpClient(
        client: transport.client,
        cacheDuration: const Duration(minutes: 5),
      );

      final first = await client.get('https://example.com/feed');
      final second = await client.get('https://example.com/feed');

      expect(transport.callCount, 1,
          reason: 'second call must not hit network');
      expect(second.body, first.body);
      expect(second.statusCode, 200);
    });

    test('an expired entry triggers a fresh request', () async {
      final transport = _RecordingClient();
      final client = CachedHttpClient(
        client: transport.client,
        // Already elapsed by the time the second call runs.
        cacheDuration: Duration.zero,
      );

      await client.get('https://example.com/feed');
      final second = await client.get('https://example.com/feed');

      expect(transport.callCount, 2);
      expect(second.body, 'body-2');
    });

    test('HEAD is cached like GET', () async {
      final transport = _RecordingClient();
      final client = CachedHttpClient(client: transport.client);

      await client.head('https://example.com/feed');
      await client.head('https://example.com/feed');

      expect(transport.callCount, 1);
    });

    test('different URLs do not share an entry', () async {
      final transport = _RecordingClient();
      final client = CachedHttpClient(client: transport.client);

      await client.get('https://example.com/a');
      await client.get('https://example.com/b');

      expect(transport.callCount, 2);
    });

    test('different header values do not share an entry', () async {
      final transport = _RecordingClient();
      final client = CachedHttpClient(client: transport.client);

      await client.get('https://example.com/f', headers: {'Auth': 'alice'});
      await client.get('https://example.com/f', headers: {'Auth': 'bob'});

      expect(transport.callCount, 2, reason: 'per-user responses must not mix');
    });
  });

  group('unsafe methods are never cached', () {
    for (final method in <String>['POST', 'PUT', 'PATCH', 'DELETE']) {
      test('$method always reaches the network', () async {
        final transport = _RecordingClient();
        final client = CachedHttpClient(client: transport.client);
        const url = 'https://example.com/orders';

        switch (method) {
          case 'POST':
            await client.post(url, body: 'x');
            await client.post(url, body: 'x');
          case 'PUT':
            await client.put(url, body: 'x');
            await client.put(url, body: 'x');
          case 'PATCH':
            await client.patch(url, body: 'x');
            await client.patch(url, body: 'x');
          case 'DELETE':
            await client.delete(url);
            await client.delete(url);
        }

        expect(
          transport.callCount,
          2,
          reason: 'replaying a cached $method would repeat a state change',
        );
      });
    }
  });

  group('response storage rules', () {
    test('non-2xx responses are not cached', () async {
      final transport = _RecordingClient(statusCode: 500);
      final client = CachedHttpClient(client: transport.client);

      await client.get('https://example.com/feed');
      await client.get('https://example.com/feed');

      expect(transport.callCount, 2, reason: 'an outage must not be pinned');
    });

    test('the original status code survives a cache round-trip', () async {
      final transport = _RecordingClient(statusCode: 201);
      final client = CachedHttpClient(client: transport.client);

      await client.get('https://example.com/feed');
      final cached = await client.get('https://example.com/feed');

      expect(transport.callCount, 1);
      expect(cached.statusCode, 201);
    });
  });

  group('cache key', () {
    test('is stable regardless of header insertion order', () {
      final a = CachedHttpClient.cacheKeyFor(
        'GET',
        'https://example.com',
        <String, String>{'a': '1', 'b': '2'},
      );
      final b = CachedHttpClient.cacheKeyFor(
        'GET',
        'https://example.com',
        <String, String>{'b': '2', 'a': '1'},
      );

      expect(a, b);
    });

    test('treats header names case-insensitively', () {
      final a = CachedHttpClient.cacheKeyFor(
        'GET',
        'https://example.com',
        <String, String>{'Accept': 'json'},
      );
      final b = CachedHttpClient.cacheKeyFor(
        'GET',
        'https://example.com',
        <String, String>{'accept': 'json'},
      );

      expect(a, b);
    });

    test('does not collide when a boundary shifts between name and value', () {
      // The pre-1.0 key was a bare concatenation, so these two produced the
      // same string and one request could serve the other's response.
      final a = CachedHttpClient.cacheKeyFor(
        'GET',
        'https://example.com',
        <String, String>{'ab': 'c'},
      );
      final b = CachedHttpClient.cacheKeyFor(
        'GET',
        'https://example.com',
        <String, String>{'a': 'bc'},
      );

      expect(a, isNot(b));
    });

    test('distinguishes methods on the same URL', () {
      expect(
        CachedHttpClient.cacheKeyFor('GET', 'https://example.com', null),
        isNot(
            CachedHttpClient.cacheKeyFor('HEAD', 'https://example.com', null)),
      );
    });
  });

  group('cache control', () {
    test('clearCache forces the next request back to the network', () async {
      final transport = _RecordingClient();
      final client = CachedHttpClient(client: transport.client);

      await client.get('https://example.com/feed');
      await client.clearCache();
      await client.get('https://example.com/feed');

      expect(transport.callCount, 2);
    });

    test('invalidate drops only the targeted entry', () async {
      final transport = _RecordingClient();
      final client = CachedHttpClient(client: transport.client);

      await client.get('https://example.com/a');
      await client.get('https://example.com/b');
      await client.invalidate('https://example.com/a');

      await client.get('https://example.com/a'); // refetched
      await client.get('https://example.com/b'); // still cached

      expect(transport.callCount, 3);
    });
  });

  group('client ownership', () {
    test('an injected client is left open by close', () async {
      final transport = _RecordingClient();
      final client = CachedHttpClient(client: transport.client);

      client.close();

      // Closing a MockClient makes further calls throw; this must still work.
      await expectLater(client.get('https://example.com/feed'), completes);
    });
  });
}
