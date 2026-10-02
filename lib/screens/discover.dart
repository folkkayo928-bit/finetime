import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart' as launcher;
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
  List<Map<String, dynamic>> _modules = [];
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
      ..onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'site_modules', callback: (_) => _load())
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
          .eq('status', 'active')
          .order('starts_on', ascending: true));
      final m = await Net.run(() => sb
          .from('site_modules')
          .select('id,placement,title,body,cta_label,cta_url,image_url,sort_order')
          .inFilter('placement', ['app_home', 'all'])
          .eq('is_enabled', true)
          .order('sort_order', ascending: true));
      if (mounted) {
        setState(() {
          _featured = List<Map<String, dynamic>>.from(f);
          _promos = List<Map<String, dynamic>>.from(p);
          _modules = List<Map<String, dynamic>>.from(m);
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

  Future<void> _openModuleUrl(String value) async {
    try {
      final uri = Uri.tryParse(value);
      if (uri == null) return;
      if (uri.scheme != 'http' && uri.scheme != 'https') return;
      await launcher.launchUrl(uri, mode: launcher.LaunchMode.externalApplication);
    } catch (_) {}
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
                    color: FT.obsidian,
                    padding: EdgeInsets.only(
                        top: MediaQuery.of(context).padding.top + 16,
                        left: 20,
                        right: 20,
                        bottom: 22),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: FT.gold.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: FT.gold.withValues(alpha: 0.4), width: 0.8),
                                      ),
                                      child: const Text('FT',
                                          style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w900,
                                              color: FT.gold,
                                              letterSpacing: 1.0)),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text('FINETIME.CC',
                                        style: TextStyle(
                                            color: FT.ivory,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 3.0)),
                                  ]),
                                  const SizedBox(height: 6),
                                  const Text('ETHIOPIA, BEAUTIFULLY CURATED',
                                      style: TextStyle(
                                          color: FT.gold,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 2.0)),
                                ],
                              ),
                              IconButton(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const SearchScreen()),
                                ),
                                icon: const Icon(Icons.search, color: FT.gold, size: 24),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Text('Exceptional stays.\nUnforgettable tables.',
                              style: TextStyle(
                                  color: FT.ivory,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'serif',
                                  height: 1.2)),
                          const SizedBox(height: 16),
                          GestureDetector(
                              onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const SearchScreen())),
                              child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 14),
                                  decoration: BoxDecoration(
                                      color: FT.surfaceSubtle,
                                      borderRadius:
                                          BorderRadius.circular(24),
                                      border: Border.all(
                                          color: const Color(0xFF332C24),
                                          width: 1)),
                                  child: const Row(children: [
                                    Icon(Icons.search,
                                        color: FT.gold, size: 20),
                                    SizedBox(width: 10),
                                    Text(
                                        'Search hotels, restaurants, cafés…',
                                        style: TextStyle(
                                            color: FT.muted,
                                            fontSize: 14)),
                                  ]))),
                        ])),
                const SizedBox(height: 14),
                Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: ['Hotels', 'Restaurants', 'Cafés']
                            .map((c) => Expanded(
                                child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4),
                                    child: OutlinedButton(
                                        onPressed: () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                builder: (_) =>
                                                    const ExploreScreen())),
                                        style: OutlinedButton.styleFrom(
                                          backgroundColor: FT.surface,
                                          side: const BorderSide(color: Color(0xFF332C24)),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                        ),
                                        child: Text(c,
                                            style: const TextStyle(
                                                fontSize: 13,
                                                color: FT.ivory,
                                                fontWeight:
                                                    FontWeight.w700))))))
                            .toList())),
                if (_modules.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Text('FineTime updates',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: FT.ivory))),
                  ..._modules.map((m) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        child: Card(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            if ((m['image_url'] ?? '').toString().isNotEmpty)
                              ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(12)), child: Image.network(m['image_url'], height: 150, width: double.infinity, fit: BoxFit.cover)),
                            Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(m['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                                if ((m['body'] ?? '').toString().isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(m['body'] ?? '', style: const TextStyle(color: Colors.white70)),
                                ],
                                if ((m['cta_url'] ?? '').toString().isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  Align(alignment: Alignment.centerLeft, child: FilledButton(onPressed: () => _openModuleUrl(m['cta_url'].toString()), child: Text(m['cta_label'] ?? 'Learn more'))),
                                ],
                              ]),
                            ),
                          ]),
                        ),
                      )),
                ],
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