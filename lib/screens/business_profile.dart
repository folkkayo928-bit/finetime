import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart' as launcher;
import '../net.dart';
import '../theme.dart';
import 'book_hotel.dart';
import 'reserve_table.dart';
import 'order_food.dart';
import 'review.dart';

class BusinessProfileScreen extends StatefulWidget {
  final String businessId;
  const BusinessProfileScreen({super.key, required this.businessId});
  @override
  State<BusinessProfileScreen> createState() => _BusinessProfileScreenState();
}

class _BusinessProfileScreenState extends State<BusinessProfileScreen> {
  final sb = Supabase.instance.client;
  Map<String, dynamic>? b;
  List<Map<String, dynamic>> _rooms = [];
  List<Map<String, dynamic>> _menu = [];
  List<Map<String, dynamic>> _reviews = [];
  String? _error;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _load();
    _checkSaved();
  }

  Future<void> _checkSaved() async {
    final u = sb.auth.currentUser;
    if (u == null) return;
    try {
      final r = await sb.from('saved_places').select('business_id')
          .eq('user_id', u.id).eq('business_id', widget.businessId).maybeSingle();
      if (mounted) setState(() => _saved = r != null);
    } catch (_) {}
  }

  Future<void> _toggleSave() async {
    final u = sb.auth.currentUser;
    if (u == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sign in to save places.')));
      return;
    }
    try {
      if (_saved) {
        await sb.from('saved_places').delete()
            .eq('user_id', u.id).eq('business_id', widget.businessId);
      } else {
        await sb.from('saved_places')
            .insert({'user_id': u.id, 'business_id': widget.businessId});
      }
      if (mounted) setState(() => _saved = !_saved);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not update saved places.')));
      }
    }
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final results = await Net.run(() async {
        final r = await sb
            .from('businesses')
            .select('*, cities(name)')
            .eq('id', widget.businessId)
            .maybeSingle();
        if (r == null) return null;
        // Parallel queries — faster on weak networks.
        final rooms = await sb
            .from('room_types')
            .select()
            .eq('business_id', widget.businessId);
        final cats = await sb
            .from('menu_categories')
            .select('*, menu_items(*)')
            .eq('business_id', widget.businessId);
        return (r, rooms, cats);
      });
      if (results == null) {
        if (mounted) setState(() => _error = 'This business is not available.');
        return;
      }
      if (mounted) {
        setState(() {
          b = Map<String, dynamic>.from(results.$1);
          _rooms = List<Map<String, dynamic>>.from(results.$2);
          _menu = List<Map<String, dynamic>>.from(results.$3);
          _reviews = List<Map<String, dynamic>>.from(results.$4);
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = Net.friendly(e));
    }
  }

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await launcher.canLaunchUrl(uri)) {
      await launcher.launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final business = b;
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ]),
          ),
        ),
      );
    }
    if (business == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final isHotel = business['category'] == 'hotel';
    return Scaffold(
      appBar: AppBar(title: Text(business['name'] ?? ''), actions: [
        IconButton(
          icon: Icon(_saved ? Icons.favorite : Icons.favorite_border,
              color: _saved ? const Color(0xFFC6A664) : null),
          tooltip: _saved ? 'Remove from saved' : 'Save place',
          onPressed: _toggleSave,
        ),
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Expanded(
                  child: OutlinedButton.icon(
                onPressed: business['phone'] != null
                    ? () => _launch('tel:${business['phone']}')
                    : null,
                icon: const Icon(Icons.call, size: 18),
                label: const Text('Call'),
                style: OutlinedButton.styleFrom(foregroundColor: FT.charcoal),
              )),
              const SizedBox(width: 8),
              Expanded(
                  child: OutlinedButton.icon(
                onPressed: business['lat'] != null
                    ? () => _launch(
                        'https://maps.google.com/?q=${business['lat']},${business['lng']}')
                    : null,
                icon: const Icon(Icons.directions, size: 18),
                label: const Text('Directions'),
                style: OutlinedButton.styleFrom(foregroundColor: FT.charcoal),
              )),
              const SizedBox(width: 8),
              Expanded(
                  child: FilledButton(
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => isHotel
                            ? BookHotelScreen(
                                business: Map<String, dynamic>.from(business))
                            : ReserveTableScreen(
                                business: Map<String, dynamic>.from(business)))),
                child: Text(isHotel ? 'Book' : 'Reserve',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              )),
            ])),
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Container(
            height: 160,
            decoration: BoxDecoration(
                color: FT.gold.withValues(alpha: .25),
                borderRadius: BorderRadius.circular(16)),
            child: business['cover_url'] != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(business['cover_url'],
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Center(
                            child: Icon(Icons.image, size: 48, color: FT.charcoal))))
                : const Center(
                    child: Icon(Icons.image, size: 48, color: FT.charcoal))),
        const SizedBox(height: 14),
        Text(business['name'] ?? '',
            style: const TextStyle(
                fontSize: 22, fontWeight: FontWeight.w800, color: FT.ivory)),
        Text('${business['category'] ?? ''} · ${(business['cities'] as Map<String, dynamic>?)?['name'] ?? ''}',
            style: const TextStyle(color: Colors.white70)),
        if ((business['about'] ?? '').toString().isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(business['about'].toString(), style: const TextStyle(height: 1.4)),
        ],
        if (_rooms.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text('Rooms',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700, color: FT.ivory)),
          ..._rooms.map((r) => Card(
              child: ListTile(
            title: Text(r['name'] ?? ''),
            subtitle: Text(r['public_price'] == null
                ? 'Contact hotel for current rate'
                : 'ETB ${r['public_price']} / night'),
            trailing: const Icon(Icons.chevron_right),
          ))),
        ],
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Reviews', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            if (sb.auth.currentUser != null)
              TextButton(
                onPressed: () async {
                  final changed = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ReviewScreen(
                        businessId: business['id'],
                        businessName: business['name'] ?? '',
                      ),
                    ),
                  );
                  if (changed == true) _load();
                },
                child: const Text('Write review'),
              ),
          ],
        ),
        if (_reviews.isEmpty)
          const Text('No reviews yet.', style: TextStyle(color: Colors.white70))
        else
          ..._reviews.map((r) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Text('★ ${r['rating']}', style: const TextStyle(color: FT.gold, fontWeight: FontWeight.w800)),
            title: Text((r['body'] ?? '').toString().isEmpty ? 'Rated experience' : r['body'].toString()),
            subtitle: Text((r['created_at'] ?? '').toString().split('T').first, style: const TextStyle(color: Colors.white54)),
          )),
        if (_menu.isNotEmpty && !isHotel) ...[
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => OrderFoodScreen(
                  business: Map<String, dynamic>.from(business),
                  menuCategories: _menu,
                ),
              ),
            ),
            icon: const Icon(Icons.shopping_bag_outlined),
            label: const Text('Order from menu'),
          ),
        ],
        if (_menu.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text('Menu',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700, color: FT.ivory)),
          ..._menu.expand((c) =>
              ((c['menu_items'] ?? []) as List).map((i) => ListTile(
                    title: Text(i['name'] ?? ''),
                    subtitle: i['description'] != null
                        ? Text(i['description'].toString())
                        : null,
                    trailing: Text(i['price'] != null ? 'ETB ${i['price']}' : ''),
                  ))),
        ],
      ]),
    );
  }
}
