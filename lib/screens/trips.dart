import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TripsScreen extends StatefulWidget {
  const TripsScreen({super.key});
  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> {
  final sb = Supabase.instance.client;
  List<Map<String, dynamic>> _bookings = [];
  List<Map<String, dynamic>> _reservations = [];
  List<Map<String, dynamic>> _orders = [];
  bool _loading = true;
  String? _error;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  DateTime _date(String value) => DateTime.tryParse(value) ?? DateTime(2100);

  bool _bookingPast(Map<String, dynamic> b, DateTime today) =>
      b['status'] == 'cancelled' || _date('${b['check_out']}').isBefore(today);

  bool _reservationPast(Map<String, dynamic> r, DateTime today) =>
      r['status'] == 'cancelled' || _date('${r['reservation_date']}').isBefore(today);

  bool _orderPast(Map<String, dynamic> o) =>
      o['status'] == 'delivered' || o['status'] == 'cancelled';

  bool _isActiveBooking(Map<String, dynamic> b, DateTime today) {
    final start = _date('${b['check_in']}');
    final end = _date('${b['check_out']}');
    return b['status'] != 'cancelled' && !end.isBefore(today) && !start.isAfter(today);
  }

  bool _isActiveReservation(Map<String, dynamic> r, DateTime today) =>
      r['status'] != 'cancelled' &&
      _date('${r['reservation_date']}').isAtSameMomentAs(today);

  Future<void> _load() async {
    final u = sb.auth.currentUser;
    if (u == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        sb.from('bookings').select('*, businesses(name), room_types(name)').eq('user_id', u.id).order('created_at', ascending: false),
        sb.from('reservations').select('*, businesses(name)').eq('user_id', u.id).order('created_at', ascending: false),
        sb.from('orders').select('*, businesses(name)').eq('user_id', u.id).order('created_at', ascending: false),
      ]);
      if (mounted) setState(() {
        _bookings = List<Map<String, dynamic>>.from(results[0] as List);
        _reservations = List<Map<String, dynamic>>.from(results[1] as List);
        _orders = List<Map<String, dynamic>>.from(results[2] as List);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() {
        _error = 'Could not load your trips. Check your connection.';
        _loading = false;
      });
    }
  }

  List<Widget> _section(String title, IconData icon, List<Widget> rows) {
    if (rows.isEmpty) return const [];
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
        child: Row(children: [
          Icon(icon, size: 20, color: const Color(0xFFC9A227)),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        ]),
      ),
      ...rows,
    ];
  }

  List<Widget> _filtered() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final widgets = <Widget>[];

    bool includeBooking(Map<String, dynamic> b) {
      final start = _date('${b['check_in']}');
      final past = _bookingPast(b, today);
      final active = _isActiveBooking(b, today);
      if (_tab == 2) return past;
      if (_tab == 1) return active;
      return !past && !active && !start.isBefore(today);
    }

    bool includeReservation(Map<String, dynamic> r) {
      final d = _date('${r['reservation_date']}');
      final past = _reservationPast(r, today);
      final active = _isActiveReservation(r, today);
      if (_tab == 2) return past;
      if (_tab == 1) return active;
      return !past && !active && !d.isBefore(today);
    }

    bool includeOrder(Map<String, dynamic> o) {
      final past = _orderPast(o);
      if (_tab == 2) return past;
      if (_tab == 1) return !past;
      return false;
    }

    final bookingRows = _bookings.where(includeBooking).map((b) => ListTile(
      leading: const Icon(Icons.hotel),
      title: Text(b['businesses']?['name'] ?? ''),
      subtitle: Text(
        '${b['room_types']?['name'] != null ? b['room_types']['name'] : ''}'
        '${b['room_types']?['name'] != null ? ' · ' : ''}'
        '${b['check_in']} → ${b['check_out']} · ${b['guests']} guest${b['guests'] == 1 ? '' : 's'} · ${b['status']}',
      ),
      trailing: Text(b['reference'] ?? '', style: const TextStyle(fontSize: 11)),
    )).toList();

    final reservationRows = _reservations.where(includeReservation).map((r) => ListTile(
      leading: const Icon(Icons.restaurant),
      title: Text(r['businesses']?['name'] ?? ''),
      subtitle: Text('${r['reservation_date']} ${r['reservation_time']} · ${r['party_size']} guests · ${r['status']}'),
    )).toList();

    final orderRows = _orders.where(includeOrder).map((o) => ListTile(
      leading: const Icon(Icons.receipt_long),
      title: Text(o['businesses']?['name'] ?? ''),
      subtitle: Text('ETB ${o['total'] ?? '0'} · ${o['status']}'),
    )).toList();

    widgets.addAll(_section('Hotel stays', Icons.hotel, bookingRows));
    widgets.addAll(_section('Table reservations', Icons.restaurant, reservationRows));
    widgets.addAll(_section('Food orders', Icons.receipt_long, orderRows));

    if (widgets.isEmpty) {
      widgets.add(const Padding(
        padding: EdgeInsets.all(32),
        child: Column(children: [
          Icon(Icons.luggage_outlined, size: 56, color: Colors.white38),
          SizedBox(height: 12),
          Text('Nothing here yet.', style: TextStyle(fontWeight: FontWeight.w700)),
          SizedBox(height: 4),
          Text('Your stays, reservations and orders will appear here.',
              textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
        ]),
      ));
    }
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = sb.auth.currentUser != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Trips')),
      body: !signedIn
          ? const Center(child: Text('Sign in to see your trips.'))
          : _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(_error!),
                      const SizedBox(height: 12),
                      FilledButton(onPressed: _load, child: const Text('Retry')),
                    ]))
                  : Column(children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                        child: SegmentedButton<int>(
                          segments: const [
                            ButtonSegment(value: 0, label: Text('Upcoming')),
                            ButtonSegment(value: 1, label: Text('Active')),
                            ButtonSegment(value: 2, label: Text('Past')),
                          ],
                          selected: {_tab},
                          onSelectionChanged: (v) => setState(() => _tab = v.first),
                        ),
                      ),
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: _load,
                          child: ListView(children: _filtered()),
                        ),
                      ),
                    ]),
    );
  }
}
