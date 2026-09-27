import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});
  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  final sb = Supabase.instance.client;
  List _saved = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final u = sb.auth.currentUser;
    if (u == null) return;
    final r = await sb.from('saved_places').select('*, businesses(*)').eq('user_id', u.id);
    if (mounted) setState(() => _saved = r);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Saved')),
    body: sb.auth.currentUser == null
      ? const Center(child: Text('Sign in to save places.'))
      : _saved.isEmpty
        ? const Center(child: Text('No saved places yet.'))
        : ListView(children: _saved.map((s) => ListTile(
            title: Text(s['businesses']?['name'] ?? ''),
            subtitle: Text(s['businesses']?['category'] ?? ''),
            trailing: const Icon(Icons.favorite, color: Color(0xFFC6A664)))).toList()));
}
