import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Makes the app independent of the phone's DNS resolver.
///
/// How it works:
/// 1. At startup we resolve the Supabase host via DNS-over-HTTPS (DoH)
///    at the literal IP 1.1.1.1 (Cloudflare) — contacting a literal IP
///    requires no DNS at all, so this works even when the device's
///    DNS resolver is broken, filtered or misconfigured.
/// 2. We register an HttpOverrides connection factory: whenever the app
///    connects to the Supabase host, the TCP connection is opened
///    directly to the resolved IP. HttpClient then upgrades the socket
///    to TLS using the original hostname from the URL, so certificate
///    validation and SNI remain correct and secure.
///
/// Normal DNS still works as a path: if resolution via DoH fails, the
/// override stays inactive and the OS resolver is used as before.
library;

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
  Future<ConnectionTask<Socket>>? connectionFactory(
      Uri uri, String? proxyHost, int? proxyPort) {
    // Only intercept the Supabase host; everything else uses default DNS.
    if (uri.host != host) return null;
    final addresses = ips();
    if (addresses.isEmpty) return null; // fall back to OS resolver
    final port = uri.port != 0 ? uri.port : 443;
    return Socket.startConnect(addresses.first, port);
  }
}
