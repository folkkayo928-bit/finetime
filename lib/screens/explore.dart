import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../net.dart';
import '../theme.dart';
import 'business_profile.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});
  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final sb = Supabase.instance.client;
  String _filter = 'all';
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _places = [];
  RealtimeChannel? _realtime;

  @override
  void initState() {
    super.initState();
    _load();
    _subscribeToUpdates();
  }

  void _subscribeToUpdates() {
    _realtime = sb.channel('explore-live')
      ..onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'businesses', callback: (_) => _load())
      ..subscribe();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final rows = await Net.run(() {
        var query = sb
            .from('businesses')
            .select('*, cities(name)')
            .eq('is_published', true);
        if (_filter != 'all') {
          query = query.eq('category', _filter);
        }
        return query;
      });
      if (mounted) {
        setState(() {
          _places = List<Map<String, dynamic>>.from(rows);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() { _error = Net.friendly(e); _loading = false; });
      }
    }
  }

  @override
  void dispose() {
    if (_realtime != null) sb.removeChannel(_realtime!);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Explore Ethiopia'),
          actions: const [],
        ),
        body: Column(children: [
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: ['all', 'hotel', 'restaurant', 'cafe']
                  .map((c) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text(
                              c == 'all' ? 'All' : c[0].toUpperCase() + c.substring(1)),
                          selected: _filter == c,
                          selectedColor: FT.gold,
                          onSelected: (_) {
                            if (_filter == c) return; // no reload on same chip
                            setState(() => _filter = c);
                            _load();
                          },
                        ),
                      ))
                  .toList(),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(mainAxisSize: MainAxisSize.min, children: [
                              Text(_error!, textAlign: TextAlign.center),
                              const SizedBox(height: 12),
                              FilledButton(onPressed: _load, child: const Text('Retry')),
                            ])))
                    : _places.isEmpty
                        ? const Center(
                            child: Text('No places listed here yet.',
                                style: TextStyle(color: Colors.white54)))
                        : ListView(
                            children: _places
                                .map((b) => ListTile(
                                      title: Text(b['name'] ?? '',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600)),
                                      subtitle: Text(
                                          '${b['category'] ?? ''} · ${(b['cities'] as Map<String, dynamic>?)?['name'] ?? ''}'),
                                      trailing: const Icon(Icons.chevron_right,
                                          color: FT.gold),
                                      onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (_) =>
                                                  BusinessProfileScreen(
                                                      businessId: b['id']))),
                                    ))
                                .toList(),
                          ),
          ),
        ]),
      );
}