<!--
This README describes the package. If you publish this package to pub.dev,
this README's contents appear on the landing page for your package.

For information about how to write a good package README, see the guide for
[writing package pages](https://dart.dev/guides/libraries/writing-package-pages).

For general information about developing packages, see the Dart guide for
[creating packages](https://dart.dev/guides/libraries/create-library-packages)
and the Flutter guide for
[developing packages and plugins](https://flutter.dev/developing-packages).
-->

# cached_http_client

A Flutter package for making HTTP requests with automatic caching.

## Features

- Automatic Caching: Cache responses for identical requests to reduce network usage and improve performance.
- Customizable Cache Duration: Configure how long responses are stored in the cache.
- Offline Support: Retrieve cached responses when the device is offline.
- Pluggable Storage Options: Choose between in-memory or file-based storage for caching.
- Middleware support for custom request/response handling.

## Installation

To use cached_http_client in your Flutter project, add the following to your `pubspec.yaml`
file:

```yaml
dependencies:
  cached_http_client: ^0.0.1
```

Then, run:

`flutter pub get`

## Usage

## Basic Example

Here's a simple example demonstrating how to use the CachedHttpClient to make HTTP requests with caching.

- lib/main.dart

```dart
import 'package:flutter/material.dart';
import 'package:cached_http_client/cached_http_client.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cached HTTP Client Example',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final CachedHttpClient _client = CachedHttpClient(cacheDuration: Duration(minutes: 5));
  String _responseBody = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _loading = true;
    });

    const url = 'https://jsonplaceholder.typicode.com/todos/1';
    try {
      final response = await _client.get(url);
      setState(() {
        _responseBody = response.body;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _responseBody = 'Failed to load data';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Cached HTTP Client Example'),
      ),
      body: Center(
        child: _loading
            ? CircularProgressIndicator()
            : SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Response:\n$_responseBody',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
        );
    }
}
```


## Custom Cache Duration

You can specify the cache duration when creating an instance of `CachedHttpClient`:

```dart
final client = CachedHttpClient(cacheDuration: Duration(hours: 1));
```

## Custom Storage Options

For using custom storage options, implement a custom `CacheManager` and pass it to `CachedHttpClient`:

```dart
final client = CachedHttpClient(cacheManager: MyCustomCacheManager());
```

## Middleware Support

To add middleware for custom handling, pass a list of middleware to `CachedHttpClient`:

```dart
final client = CachedHttpClient(
  cacheDuration: Duration(hours: 1),
  middleware: [myMiddleware],
);
```