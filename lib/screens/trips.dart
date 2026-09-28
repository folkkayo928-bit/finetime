import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TripsScreen extends StatefulWidget {
  const TripsScreen({super.key});
  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> {
  final sb = Supabase.instance.client;
  List _bookings = [], _reservations = [], _orders = [];
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
      final b = await sb
          .from('bookings')
          .select('*, businesses(name), room_types(name)')
          .eq('user_id', u.id)
          .order('created_at', ascending: false);
      final r = await sb
          .from('reservations')
          .select('*, businesses(name)')
          .eq('user_id', u.id)
          .order('created_at', ascending: false);
      final o = await sb
          .from('orders')
          .select('*, businesses(name)')
          .eq('user_id', u.id)
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _bookings = b;
          _reservations = r;
          _orders = o;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Could not load your trips. Check your connection.';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Trips')),
    body: sb.auth.currentUser == null
      ? const Center(child: Text('Sign in to see your trips.'))
      : _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(_error!),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ]))
          : RefreshIndicator(
            onRefresh: _load,
            child: ListView(children: [
              const Padding(padding: EdgeInsets.all(16), child: Text('Hotel stays', style: TextStyle(fontWeight: FontWeight.w700))),
              ..._bookings.map((b) => ListTile(
                leading: const Icon(Icons.hotel),
                title: Text(b['businesses']?['name'] ?? ''),
                subtitle: Text(
                  '${b['room_types']?['name'] != null ? b['room_types']['name'] + ' · ' : ''}'
                  '${b['check_in']} → ${b['check_out']} · ${b['guests']} guest${b['guests'] == 1 ? '' : 's'} · ${b['status']}'),
                trailing: Text(b['reference'] ?? '', style: const TextStyle(fontSize: 11)))),
              const Padding(padding: EdgeInsets.all(16), child: Text('Food orders', style: TextStyle(fontWeight: FontWeight.w700))),
              ..._orders.map((o) => ListTile(
                leading: const Icon(Icons.receipt_long),
                title: Text(o['businesses']?['name'] ?? ''),
                subtitle: Text('ETB ${o['total'] ?? '0'} · ${o['status']}'),
              )),
              $anchor
              ..._reservations.map((r) => ListTile(
                leading: const Icon(Icons.restaurant),
                title: Text(r['businesses']?['name'] ?? ''),
                subtitle: Text('${r['reservation_date']} ${r['reservation_time']} · ${r['party_size']} guests · ${r['status']}'))),
              if (_bookings.isEmpty && _reservations.isEmpty && _orders.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Column(children: [
                    Icon(Icons.luggage_outlined, size: 56, color: Colors.white38),
                    SizedBox(height: 12),
                    Text('No trips yet.', style: TextStyle(fontWeight: FontWeight.w700)),
                    SizedBox(height: 4),
                    Text('Book a hotel or reserve a table and it will show up here.',
                        textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
                  ]),
                ),
            ])));
}
