import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Makes the app independent of the phone's DNS resolver.
///
/// 1. At startup we resolve the Supabase host via DNS-over-HTTPS (DoH)
///    at the literal IP 1.1.1.1 (Cloudflare) — contacting a literal IP
///    requires no DNS at all, so this works even when the device's
///    DNS resolver is broken, filtered or misconfigured.
/// 2. An HttpOverrides HttpClient connects to the Supabase host
///    directly at the resolved IP; other hosts use normal DNS.
///    TLS still validates against the original hostname.

class DnsFix {
  static String? _targetHost;
  static List<InternetAddress> _ips = [];
  static DateTime _resolvedAt = DateTime.fromMillisecondsSinceEpoch(0);
  static const _ttl = Duration(minutes: 30);

  static bool get _fresh =>
      _ips.isNotEmpty && DateTime.now().difference(_resolvedAt) < _ttl;

  /// Call once before Supabase.initialize().
  static Future<void> prepare({required String supabaseUrl}) async {
    final host = Uri.tryParse(supabaseUrl)?.host;
    if (host == null || host.isEmpty) return;
    _targetHost = host;
    await resolve();
    HttpOverrides.global = _FixedDnsOverrides(host, _currentIps);
  }

  static List<InternetAddress> _currentIps() => _fresh ? _ips : const [];

  /// Resolve (or refresh) the target host's A records via DoH at 1.1.1.1.
  static Future<void> resolve() async {
    final host = _targetHost;
    if (host == null) return;
    try {
      final resp = await http
          .get(
            Uri.parse('https://1.1.1.1/dns-query?name=$host&type=A'),
            headers: {'accept': 'application/dns-json'},
          )
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return;
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final answers = (data['Answer'] as List?) ?? const [];
      final ips = answers
          .whereType<Map<String, dynamic>>()
          .where((a) => a['type'] == 1) // A records only
          .map((a) => InternetAddress(a['data'].toString()))
          .toList();
      if (ips.isNotEmpty) {
        _ips = ips;
        _resolvedAt = DateTime.now();
      }
    } catch (_) {
      // DoH unreachable — leave any previous cache in place;
      // the OS resolver remains the fallback path.
    }
  }
}

class _FixedDnsOverrides extends HttpOverrides {
  final String host;
  final List<InternetAddress> Function() ips;
  _FixedDnsOverrides(this.host, this.ips);

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    // The connection factory must always return a ConnectionTask:
    // - Supabase host with a fresh DoH-resolved IP → connect to that IP.
    // - Anything else (or no IP yet) → normal DNS via the hostname.
    client.connectionFactory = (Uri uri, String? proxyHost, int? proxyPort) {
      if (uri.host == host) {
        final addresses = ips();
        if (addresses.isNotEmpty) {
          final port = uri.port != 0 ? uri.port : 443;
          return Socket.startConnect(addresses.first, port);
        }
      }
      final port = uri.port != 0 ? uri.port : (uri.scheme == 'https' ? 443 : 80);
      return Socket.startConnect(uri.host, port);
    };
    return client;
  }
}
