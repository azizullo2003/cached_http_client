import 'package:flutter/material.dart';
import 'package:cached_http_client/cached_http_client.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cached HTTP Client Example',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final CachedHttpClient _client =
      CachedHttpClient(cacheDuration: const Duration(minutes: 5));
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
        title: const Text('Cached HTTP Client Example'),
      ),
      body: Center(
        child: _loading
            ? const CircularProgressIndicator()
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Response:\n$_responseBody',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
      ),
    );
  }
}
