import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'theme.dart';

const currentFineTimeVersion =
    String.fromEnvironment('APP_VERSION', defaultValue: '0.1.0');

class FineTimeUpdateGate extends StatefulWidget {
  final Widget child;
  const FineTimeUpdateGate({super.key, required this.child});

  @override
  State<FineTimeUpdateGate> createState() => _FineTimeUpdateGateState();
}

class _FineTimeUpdateGateState extends State<FineTimeUpdateGate> {
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  Future<void> _check() async {
    if (_checked || kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    _checked = true;
    try {
      await Future<void>.delayed(const Duration(seconds: 2));
      final response = await http
          .get(
            Uri.parse(
              'https://api.github.com/repos/folkkayo928-bit/finetime/releases/latest',
            ),
            headers: const {
              'Accept': 'application/vnd.github+json',
              'User-Agent': 'FineTime-App',
            },
          )
          .timeout(const Duration(seconds: 6));

      if (response.statusCode != 200 || !mounted) return;
      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) return;

      final tag = (data['tag_name'] ?? '').toString();
      final latest = tag.replaceFirst(RegExp(r'^v'), '');
      final pageUrl = (data['html_url'] ?? '').toString();
      if (latest.isEmpty || pageUrl.isEmpty) return;
      if (_compareVersions(latest, currentFineTimeVersion) <= 0) return;

      final asset = (data['assets'] is List ? data['assets'] as List : const [])
          .whereType<Map>()
          .cast<Map<String, dynamic>>()
          .firstWhere(
            (item) => (item['name'] ?? '').toString().toLowerCase() == 'finetime.apk',
            orElse: () => <String, dynamic>{},
          );
      final downloadUrl = (asset['browser_download_url'] ?? pageUrl).toString();

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: FT.surface,
          title: const Text('FineTime update available'),
          content: Text(
            'A newer version ($latest) is ready. Your version is $currentFineTimeVersion.\n\n'
            'Open the FineTime release to download the update. Android will ask you to confirm the installation.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Later'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                final uri = Uri.tryParse(downloadUrl);
                if (uri != null) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              child: const Text('Get update'),
            ),
          ],
        ),
      );
    } catch (_) {
      // Update checks are non-critical and must never block app startup.
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

int _compareVersions(String a, String b) {
  List<int> parts(String value) {
    return value
        .split('.')
        .map((part) => int.tryParse(RegExp(r'^\d+').stringMatch(part) ?? '0') ?? 0)
        .toList();
  }

  final av = parts(a);
  final bv = parts(b);
  final length = av.length > bv.length ? av.length : bv.length;
  for (var i = 0; i < length; i++) {
    final ai = i < av.length ? av[i] : 0;
    final bi = i < bv.length ? bv[i] : 0;
    if (ai != bi) return ai.compareTo(bi);
  }
  return 0;
}