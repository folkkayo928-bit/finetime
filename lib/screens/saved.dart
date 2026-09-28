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
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final u = sb.auth.currentUser;
    if (u == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    setState(() => _error = null);
    try {
      final r = await sb
          .from('saved_places')
          .select('*, businesses(*)')
          .eq('user_id', u.id)
          .order('created_at', ascending: false);
      if (mounted) setState(() { _saved = r; _loading = false; });
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Could not load saved places. Check your connection.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _unsave(Map s) async {
    await sb.from('saved_places').delete()
        .eq('user_id', sb.auth.currentUser!.id)
        .eq('business_id', s['business_id']);
    if (mounted) setState(() => _saved.remove(s));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Saved')),
    body: sb.auth.currentUser == null
      ? const Center(child: Text('Sign in to save places.'))
      : _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(_error!),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ]))
          : _saved.isEmpty
            ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.favorite_border, size: 56, color: Colors.black26),
                SizedBox(height: 12),
                Text('Your saved places will appear here.'),
              ]))
            : RefreshIndicator(
              onRefresh: _load,
              child: ListView(children: _saved.map((s) {
                final biz = s['businesses'];
                return ListTile(
                  leading: Icon(_iconFor(biz?['category']), color: const Color(0xFFC6A664)),
                  title: Text(biz?['name'] ?? ''),
                  subtitle: Text(biz?['category'] ?? ''),
                  trailing: IconButton(
                    icon: const Icon(Icons.favorite, color: Color(0xFFC6A664)),
                    tooltip: 'Remove from saved',
                    onPressed: () => _unsave(s)),
                  onTap: () {},
                );
              }).toList()),
            ),
  );

  IconData _iconFor(String? category) {
    switch (category) {
      case 'hotel': return Icons.hotel;
      case 'restaurant': return Icons.restaurant;
      case 'cafe': return Icons.local_cafe;
      default: return Icons.place;
    }
  }
}
