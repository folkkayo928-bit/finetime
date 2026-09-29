import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';
import 'business_profile.dart';
import 'explore.dart';
import 'search.dart';
import '../net.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});
  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final sb = Supabase.instance.client;
  List<Map<String, dynamic>> _featured = [];
  List<Map<String, dynamic>> _promos = [];
  RealtimeChannel? _realtime;

  @override
  void initState() {
    super.initState();
    _load();
    _subscribeToUpdates();
  }

  void _subscribeToUpdates() {
    _realtime = sb.channel('discover-live')
      ..onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'businesses', callback: (_) => _load())
      ..onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'promotions', callback: (_) => _load())
      ..subscribe();
  }

  Future<void> _load() async {
    try {
      final f = await Net.run(() => sb
          .from('businesses')
          .select()
          .eq('is_published', true)
          .limit(10));
      final p = await Net.run(() => sb
          .from('promotions')
          .select('*, businesses(name)')
          .order('starts_on', ascending: true));
      if (mounted) {
        setState(() {
          _featured = List<Map<String, dynamic>>.from(f);
          _promos = List<Map<String, dynamic>>.from(p);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _featured = [];
          _promos = [];
        });
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
        body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                Container(
                    color: FT.charcoal,
                    padding: EdgeInsets.only(
                        top: MediaQuery.of(context).padding.top + 12,
                        left: 20,
                        right: 20,
                        bottom: 20),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            const Text('F',
                                style: TextStyle(
                                    fontSize: 30,
                                    fontWeight: FontWeight.w800,
                                    color: FT.gold)),
                            const SizedBox(width: 8),
                            Text('FineTime',
                                style: Theme.of(context)
                                    .appBarTheme
                                    .titleTextStyle),
                          ]),
                          const SizedBox(height: 4),
                          const Text('Welcome to FineTime ✦',
                              style: TextStyle(
                                  color: FT.ivory,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          const Text('Discover. Dine. Stay.',
                              style: TextStyle(color: Colors.white54)),
                          const SizedBox(height: 14),
                          GestureDetector(
                              onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const SearchScreen())),
                              child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 13),
                                  decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius:
                                          BorderRadius.circular(12)),
                                  child: const Row(children: [
                                    Icon(Icons.search,
                                        color: Colors.black38),
                                    SizedBox(width: 8),
                                    Text(
                                        'Search hotels, restaurants, cafés…',
                                        style: TextStyle(
                                            color: Colors.black38)),
                                  ]))),
                        ])),
                const SizedBox(height: 16),
                Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: ['Hotels', 'Restaurants', 'Cafés']
                            .map((c) => Expanded(
                                child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4),
                                    child: FilledButton(
                                        onPressed: () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                builder: (_) =>
                                                    const ExploreScreen())),
                                        child: Text(c,
                                            style: const TextStyle(
                                                fontSize: 13,
                                                color: FT.charcoal,
                                                fontWeight:
                                                    FontWeight.w700))))))
                            .toList())),
                if (_promos.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Text('Promotions',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: FT.ivory))),
                  SizedBox(
                      height: 110,
                      child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding:
                              const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _promos.length,
                          itemBuilder: (_, i) => Container(
                              width: 260,
                              margin: const EdgeInsets.all(8),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                  color: FT.charcoal,
                                  borderRadius:
                                      BorderRadius.circular(14)),
                              child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    FT.badge(
                                        _promos[i]['badge'] ?? 'FEATURED'),
                                    const SizedBox(height: 8),
                                    Text(_promos[i]['title'] ?? '',
                                        style: const TextStyle(
                                            color: FT.ivory,
                                            fontWeight: FontWeight.w700),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                    Text(
                                        _promos[i]['businesses']?['name'] ??
                                            '',
                                        style: const TextStyle(
                                            color: Colors.white54,
                                            fontSize: 12)),
                                  ])))),
                ],
                const SizedBox(height: 8),
                const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Text('Featured places',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: FT.ivory))),
                ..._featured.map((b) => _businessCard(context, b)),
              ]),
        ),
      );
}

Widget _businessCard(BuildContext context, Map<String, dynamic> b) =>
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Card(
          child: ListTile(
              leading: Container(
                  width: 56,
                  height: 56,
                  color: FT.gold.withValues(alpha: .3),
                  child: b['cover_url'] != null
                      ? Image.network(b['cover_url'], fit: BoxFit.cover)
                      : const Icon(Icons.store, color: FT.ivory)),
              title: Text(b['name'] ?? '',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text((b['category'] ?? '').toString().toUpperCase(),
                  style: const TextStyle(
                      fontSize: 11, letterSpacing: 1)),
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => BusinessProfileScreen(
                          businessId: b['id']))))));