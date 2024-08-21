import 'package:flutter_test/flutter_test.dart';
import 'package:cached_http_client/cached_http_client.dart';

void main() {
  test('should cache response with expiration and measure response time',
      () async {
    const cacheDuration =
        Duration(seconds: 5); // Short cache duration for testing
    final client = CachedHttpClient(cacheDuration: cacheDuration);
    const url = 'https://jsonplaceholder.typicode.com/todos/1';

    final stopwatch = Stopwatch();

    // Measure time for the first request
    stopwatch.start();
    final response1 = await client.get(url);
    stopwatch.stop();
    final firstRequestTime = stopwatch.elapsedMilliseconds;
    print('First request time: $firstRequestTime ms');
    expect(response1.statusCode, 200);

    // Wait for cache to expire
    await Future.delayed(const Duration(seconds: 4)); // Ensure cache expires

    stopwatch.reset(); // Reset stopwatch for the second request
    stopwatch.start();
    final response2 = await client.get(url);
    stopwatch.stop();
    final secondRequestTime = stopwatch.elapsedMilliseconds;
    print('Second request time: $secondRequestTime ms');

    expect(response2.statusCode, 200); // Check if the response is still valid

    // Output times for analysis
    print(
        'Response times:\nFirst request: $firstRequestTime ms\nSecond request: $secondRequestTime ms');
  });
}
