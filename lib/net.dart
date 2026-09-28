// Network resilience helpers: timeouts, retry (opt-in per call),
// and friendly, accurate error messages.
///
// Auth calls pass retry: false — retrying signup/sign-in multiplies
// requests against Supabase rate limits and can trigger
// "over_request_rate_limit" errors.

class Net {
  static Future<T> run<T>(Future<T> Function() fn,
      {int attempts = 3, bool retry = true}) async {
    Object? lastError;
    final n = retry ? attempts : 1;
    for (var i = 0; i < n; i++) {
      try {
        return await fn().timeout(const Duration(seconds: 25));
      } catch (e) {
        if (!retry) rethrow;
        lastError = e;
        if (i < n - 1) {
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
    final s = e.toString().toLowerCase();
    if (s.contains('already registered') ||
        s.contains('user already exists') ||
        s.contains('email address') && s.contains('invalid')) {
      return 'This email already has an account.\nUse "Sign in" below instead.';
    }
    if (s.contains('rate') ||
        s.contains('limit') ||
        s.contains('too many') ||
        s.contains('over_request')) {
      return 'Too many attempts right now.\nPlease wait a few minutes and try again.';
    }
    if (s.contains('email not confirmed')) {
      return 'Please confirm your email first\n(check your inbox for the FineTime link).';
    }
    if (s.contains('invalid login credentials')) {
      return 'Wrong email or password. Please try again.';
    }
    if (s.contains('failed host lookup') || s.contains('errno = 7')) {
      return 'Could not reach the FineTime server (DNS lookup failed).\n'
          'Please try again — if this persists, reinstall the app.';
    }
    if (s.contains('connection refused') ||
        s.contains('connection reset') ||
        s.contains('timed out') ||
        s.contains('timeoutexception')) {
      return 'Could not reach the FineTime server.\n'
          'Please try again in a moment.';
    }
    return 'Something went wrong. Please try again.';
  }
}
