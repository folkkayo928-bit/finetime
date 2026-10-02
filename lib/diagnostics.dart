import 'dart:convert';
import 'dart:io';

/// Lightweight diagnostics to pinpoint exactly which layer fails:
/// DNS resolution → HTTPS connection → Supabase REST API → Supabase Auth.
/// Uses only the standard Dart networking stack; it does NOT replace
/// or alter the normal Supabase client networking.

class NetDiag {
  static const _url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://atewcbkuzrnfnmzsylze.supabase.co',
  );
  static String get host => Uri.tryParse(_url)?.host ?? '';

  static bool get configured => _url.isNotEmpty;

  static Future<List<String>> run() async {
    final out = <String>[];
    if (!configured) {
      out.add('CONFIG: SUPABASE_URL dart-define is EMPTY — build is misconfigured.');
      return out;
    }
    out.add('CONFIG: URL present, host=$host');

    // 1. DNS resolution
    final sw = Stopwatch()..start();
    try {
      final addrs = await InternetAddress.lookup(host)
          .timeout(const Duration(seconds: 10));
      out.add('DNS: OK (${addrs.length} address(es), ${sw.elapsedMilliseconds}ms)');
    } catch (e) {
      out.add('DNS: FAILED — $e');
      out.add('STOP: DNS is the failing layer. Nothing above it was tested.');
      return out;
    }

    // 2. HTTPS connection
    sw.reset();
    try {
      final client = HttpClient();
      final req = await client
          .getUrl(Uri.parse(_url))
          .timeout(const Duration(seconds: 10));
      final resp = await req.close().timeout(const Duration(seconds: 10));
      await resp.drain();
      client.close();
      out.add('HTTPS: OK (status ${resp.statusCode}, ${sw.elapsedMilliseconds}ms)');
    } catch (e) {
      out.add('HTTPS: FAILED — $e');
      out.add('STOP: TLS/socket layer is failing; DNS worked.');
      return out;
    }

    // 3. Supabase REST API
    try {
      final client = HttpClient();
      final key = const String.fromEnvironment(
        'SUPABASE_ANON_KEY',
        defaultValue: 'sb_publishable_CxfreIiozKEB-GcvNOCyhQ_RVnIgGVG',
      );
      final req = await client
          .getUrl(Uri.parse('$_url/rest/v1/'))
          .timeout(const Duration(seconds: 10));
      req.headers.set('apikey', key);
      final resp = await req.close().timeout(const Duration(seconds: 10));
      final body = await resp.transform(const Utf8Decoder()).join();
      client.close();
      out.add(resp.statusCode == 200
          ? 'API: OK (status 200) — REST reachable'
          : 'API: status ${resp.statusCode} — ${body.substring(0, body.length.clamp(0, 120))}');
    } catch (e) {
      out.add('API: FAILED — $e');
    }

    // 4. Supabase Auth endpoint
    try {
      final client = HttpClient();
      final key = const String.fromEnvironment(
        'SUPABASE_ANON_KEY',
        defaultValue: 'sb_publishable_CxfreIiozKEB-GcvNOCyhQ_RVnIgGVG',
      );
      final req = await client
          .getUrl(Uri.parse('$_url/auth/v1/settings'))
          .timeout(const Duration(seconds: 10));
      req.headers.set('apikey', key);
      final resp = await req.close().timeout(const Duration(seconds: 10));
      await resp.drain();
      client.close();
      out.add('AUTH: OK (status ${resp.statusCode}) — auth endpoint reachable');
    } catch (e) {
      out.add('AUTH: FAILED — $e');
    }

    return out;
  }
}
