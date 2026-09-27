import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  List<Map<String, dynamic>> _places = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    var query = sb
        .from('businesses')
        .select('*, cities(name)')
        .eq('is_published', true);
    if (_filter != 'all') {
      query = query.eq('category', _filter);
    }
    final rows = await query;
    if (mounted) {
      setState(() {
        _places = List<Map<String, dynamic>>.from(rows);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Explore Ethiopia')),
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
                : _places.isEmpty
                    ? const Center(
                        child: Text('No places listed here yet.',
                            style: TextStyle(color: Colors.black38)))
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
