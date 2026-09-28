/// Network resilience helpers: retries with backoff, timeouts,
/// and friendly, accurate error messages.

class Net {
  /// Runs [fn] with a timeout and retries on failure.
  static Future<T> run<T>(Future<T> Function() fn, {int attempts = 3}) async {
    Object? lastError;
    for (var i = 0; i < attempts; i++) {
      try {
        return await fn().timeout(const Duration(seconds: 25));
      } catch (e) {
        lastError = e;
        if (i < attempts - 1) {
          await Future.delayed(Duration(seconds: 2 * (i + 1)));
        }
      }
    }
    throw lastError!;
  }

  /// Converts raw exceptions into user-friendly messages.
  /// No blanket "weak internet" claim — the message reflects
  /// the actual failure class.
  static String friendly(Object e) {
    final s = e.toString();
    if (s.contains('Failed host lookup') || s.contains('errno = 7')) {
      return 'Could not reach the FineTime server (DNS lookup failed).\n'
          'Please try again — if this persists, reinstall the app.';
    }
    if (s.contains('Connection refused') ||
        s.contains('Connection reset') ||
        s.contains('timed out') ||
        s.contains('TimeoutException')) {
      return 'Could not reach the FineTime server.\n'
          'Please try again in a moment.';
    }
    return 'Something went wrong. Please try again.';
  }
}
