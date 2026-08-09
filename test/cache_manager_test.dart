import 'dart:convert';
import 'dart:io';

import 'package:cached_http_client/cached_http_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

http.Response _response(String body, {int status = 200}) {
  return http.Response(body, status, headers: {'content-type': 'text/plain'});
}

void main() {
  group('CacheEntry', () {
    test('survives a JSON round-trip with status and headers intact', () {
      final entry = CacheEntry.fromResponse(_response('hello', status: 201));

      final restored = CacheEntry.fromJson(
        jsonDecode(jsonEncode(entry.toJson())) as Map<String, dynamic>,
      );

      expect(restored.statusCode, 201);
      expect(restored.body, 'hello');
      expect(restored.headers['content-type'], 'text/plain');
      expect(
        restored.storedAt.toIso8601String(),
        entry.storedAt.toIso8601String(),
      );
    });

    test('freshness is evaluated against the supplied clock', () {
      final storedAt = DateTime(2026, 1, 1, 12);
      final entry = CacheEntry.fromResponse(_response('x'), storedAt: storedAt);

      expect(
        entry.isFresh(
          const Duration(minutes: 5),
          now: storedAt.add(const Duration(minutes: 4)),
        ),
        isTrue,
      );
      expect(
        entry.isFresh(
          const Duration(minutes: 5),
          now: storedAt.add(const Duration(minutes: 6)),
        ),
        isFalse,
      );
    });
  });

  group('InMemoryCacheManager', () {
    test('returns null once an entry has expired', () async {
      final cache = InMemoryCacheManager(cacheDuration: Duration.zero);
      await cache.set('k', _response('v'));

      expect(await cache.get('k'), isNull);
    });

    test('drops the expired entry rather than keeping it around', () async {
      final cache = InMemoryCacheManager(cacheDuration: Duration.zero);
      await cache.set('k', _response('v'));

      await cache.get('k');

      expect(cache.length, 0);
    });

    test('evicts the least recently used entry at capacity', () async {
      final cache = InMemoryCacheManager(maxEntries: 2);
      await cache.set('a', _response('1'));
      await cache.set('b', _response('2'));

      // Touch 'a' so 'b' becomes the least recently used.
      await cache.get('a');
      await cache.set('c', _response('3'));

      expect(cache.length, 2);
      expect(await cache.get('a'), isNotNull);
      expect(await cache.get('b'), isNull, reason: 'b was the LRU entry');
      expect(await cache.get('c'), isNotNull);
    });

    test('overwriting an existing key does not evict another entry', () async {
      final cache = InMemoryCacheManager(maxEntries: 2);
      await cache.set('a', _response('1'));
      await cache.set('b', _response('2'));

      await cache.set('a', _response('1-updated'));

      expect(cache.length, 2);
      expect((await cache.get('b'))!.body, '2');
    });

    test('remove and clear drop entries', () async {
      final cache = InMemoryCacheManager();
      await cache.set('a', _response('1'));
      await cache.set('b', _response('2'));

      await cache.remove('a');
      expect(await cache.get('a'), isNull);
      expect(cache.length, 1);

      await cache.clear();
      expect(cache.length, 0);
    });
  });

  group('FileCacheManager', () {
    late Directory directory;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('chc_test_');
    });

    tearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    test('round-trips a response through disk', () async {
      final cache = FileCacheManager(directory: directory);
      await cache.set(
          'https://example.com/a?x=1', _response('disk', status: 202));

      final restored = await cache.get('https://example.com/a?x=1');

      expect(restored, isNotNull);
      expect(restored!.body, 'disk');
      expect(restored.statusCode, 202,
          reason: 'status must not be forced to 200');
    });

    test('stores keys containing path separators safely', () async {
      final cache = FileCacheManager(directory: directory);
      const key = 'https://example.com/deep/path?q=a/b:c';

      await cache.set(key, _response('ok'));

      expect((await cache.get(key))!.body, 'ok');
      // One flat file, no nested directories created from the URL.
      expect(directory.listSync().whereType<File>().length, 1);
    });

    test('deletes the file when the entry has expired', () async {
      final cache = FileCacheManager(
        directory: directory,
        cacheDuration: Duration.zero,
      );
      await cache.set('k', _response('v'));

      expect(await cache.get('k'), isNull);
      expect(directory.listSync().whereType<File>(), isEmpty);
    });

    test('treats a corrupted file as a miss instead of throwing', () async {
      final cache = FileCacheManager(directory: directory);
      await cache.set('k', _response('v'));
      final file = directory.listSync().whereType<File>().single;
      await file.writeAsString('{not json');

      expect(await cache.get('k'), isNull);
    });

    test('clear removes every cache file', () async {
      final cache = FileCacheManager(directory: directory);
      await cache.set('a', _response('1'));
      await cache.set('b', _response('2'));

      await cache.clear();

      expect(directory.listSync().whereType<File>(), isEmpty);
    });
  });
}
