import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'cache_entry.dart';
import 'cache_manager.dart';

/// Cache that survives app restarts by writing entries to disk as JSON.
///
/// Cache keys are hashed before being used as filenames, so a key containing
/// `/`, `:` or any other path-significant character is stored safely. Expired
/// files are deleted lazily, the first time they are read.
class FileCacheManager implements CacheManager {
  /// Creates a cache backed by [directory].
  ///
  /// The directory must already exist. Prefer [create] outside of tests.
  FileCacheManager({
    required this.directory,
    Duration? cacheDuration,
  }) : _cacheDuration =
            cacheDuration ?? InMemoryCacheManager.defaultCacheDuration;

  /// Creates a cache under the platform temporary directory.
  ///
  /// The directory is created if missing. [subdirectory] keeps entries away
  /// from other files the host app may store in the same location.
  static Future<FileCacheManager> create({
    Duration? cacheDuration,
    String subdirectory = 'cached_http_client',
  }) async {
    final temporary = await getTemporaryDirectory();
    final directory = Directory('${temporary.path}/$subdirectory');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return FileCacheManager(
      directory: directory,
      cacheDuration: cacheDuration,
    );
  }

  /// Where cache files are written.
  final Directory directory;

  final Duration _cacheDuration;

  @override
  Duration get cacheDuration => _cacheDuration;

  @override
  Future<http.Response?> get(String key) async {
    final file = _fileFor(key);
    if (!await file.exists()) return null;

    final CacheEntry entry;
    try {
      entry = CacheEntry.fromJson(
        jsonDecode(await file.readAsString()) as Map<String, dynamic>,
      );
    } on Object {
      // A truncated or hand-edited file is treated as a miss, not a crash.
      await file.delete();
      return null;
    }

    if (!entry.isFresh(_cacheDuration)) {
      await file.delete();
      return null;
    }
    return entry.toResponse();
  }

  @override
  Future<void> set(String key, http.Response response) async {
    final entry = CacheEntry.fromResponse(response);
    await _fileFor(key).writeAsString(jsonEncode(entry.toJson()));
  }

  @override
  Future<void> remove(String key) async {
    final file = _fileFor(key);
    if (await file.exists()) {
      await file.delete();
    }
  }

  @override
  Future<void> clear() async {
    if (!await directory.exists()) return;
    await for (final entity in directory.list()) {
      if (entity is File && entity.path.endsWith(_extension)) {
        await entity.delete();
      }
    }
  }

  static const String _extension = '.cache.json';

  File _fileFor(String key) {
    final name = sha256.convert(utf8.encode(key)).toString();
    return File('${directory.path}/$name$_extension');
  }
}
