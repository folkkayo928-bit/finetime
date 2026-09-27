import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../dns_fix.dart';

/// Network resilience helpers: retries with backoff, timeouts,
/// and friendly errors for weak/unstable connections.
library;

class Net {
  /// Runs [fn] with a timeout and retries on failure.
  /// Retries help on weak mobile networks where DNS or TLS
  /// intermittently fails. Between attempts we refresh the
  /// DNS-over-HTTPS cache so a stale IP self-heals.
  static Future<T> run<T>(Future<T> Function() fn, {int attempts = 3}) async {
    Object? lastError;
    for (var i = 0; i < attempts; i++) {
      try {
        return await fn().timeout(const Duration(seconds: 25));
      } catch (e) {
        lastError = e;
        if (i < attempts - 1) {
          // Linear backoff: 2s, 4s — gives DNS/radio time to recover.
          await Future.delayed(Duration(seconds: 2 * (i + 1)));
          await DnsFix.resolve(); // refresh resolved IP before retry
        }
      }
    }
    throw lastError!;
  }

  /// Converts raw exceptions into user-friendly messages.
  static String friendly(Object e) {
    final s = e.toString();
    if (s.contains('Failed host lookup') ||
        s.contains('errno = 7') ||
        s.contains('Connection refused') ||
        s.contains('Connection reset') ||
        s.contains('timed out') ||
        s.contains('TimeoutException')) {
      return 'Weak or unstable internet connection.\n'
          'Check your connection (Wi-Fi or data) and try again.';
    }
    return 'Something went wrong. Please try again.';
  }
}
