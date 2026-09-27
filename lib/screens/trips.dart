import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TripsScreen extends StatefulWidget {
  const TripsScreen({super.key});
  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> {
  final sb = Supabase.instance.client;
  List _bookings = [], _reservations = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final u = sb.auth.currentUser;
    if (u == null) return;
    final b = await sb.from('bookings').select('*, businesses(name), room_types(name)').eq('user_id', u.id).order('created_at', ascending: false);
    final r = await sb.from('reservations').select('*, businesses(name)').eq('user_id', u.id).order('created_at', ascending: false);
    if (mounted) setState(() { _bookings = b; _reservations = r; });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Trips')),
    body: sb.auth.currentUser == null
      ? const Center(child: Text('Sign in to see your trips.'))
      : RefreshIndicator(
        onRefresh: _load,
        child: ListView(children: [
          const Padding(padding: EdgeInsets.all(16), child: Text('Hotel stays', style: TextStyle(fontWeight: FontWeight.w700))),
          ..._bookings.map((b) => ListTile(
            leading: const Icon(Icons.hotel),
            title: Text(b['businesses']?['name'] ?? ''),
            subtitle: Text('${b['check_in']} → ${b['check_out']} · ${b['status']}'),
            trailing: Text(b['reference'] ?? '', style: const TextStyle(fontSize: 11)))),
          const Padding(padding: EdgeInsets.all(16), child: Text('Table reservations', style: TextStyle(fontWeight: FontWeight.w700))),
          ..._reservations.map((r) => ListTile(
            leading: const Icon(Icons.restaurant),
            title: Text(r['businesses']?['name'] ?? ''),
            subtitle: Text('${r['reservation_date']} ${r['reservation_time']} · ${r['party_size']} guests · ${r['status']}'))),
        ])));
}
