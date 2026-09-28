import 'package:flutter/material.dart';
import '../diagnostics.dart';

/// Temporary diagnostics screen. Shows exactly which network layer fails.
/// Remove after the root cause is confirmed.

class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key});
  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  List<String>? _lines;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() => _busy = true);
    final lines = await NetDiag.run();
    if (mounted) setState(() { _lines = lines; _busy = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Network Diagnostics')),
      body: _busy || _lines == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final l in _lines!)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: SelectableText(l,
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
                  ),
                const SizedBox(height: 12),
                OutlinedButton(onPressed: _run, child: const Text('Run again')),
              ],
            ),
    );
  }
}
