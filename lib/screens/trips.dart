import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';

class TripsScreen extends StatefulWidget {
  const TripsScreen({super.key});

  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> {
  final sb = Supabase.instance.client;

  List<Map<String, dynamic>> bookings = [];
  List<Map<String, dynamic>> reservations = [];
  List<Map<String, dynamic>> orders = [];

  bool loading = true;
  String? error;
  int tab = 0;
  RealtimeChannel? realtime;

  @override
  void initState() {
    super.initState();
    load();

    final user = sb.auth.currentUser;
    if (user != null) {
      realtime = sb.channel('trips-live-' + user.id)
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'bookings',
          callback: (_) => load(),
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'reservations',
          callback: (_) => load(),
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          callback: (_) => load(),
        )
        ..subscribe();
    }
  }

  DateTime date(dynamic value) {
    return DateTime.tryParse(value?.toString() ?? '') ?? DateTime(2100);
  }

  Future<void> load() async {
    final user = sb.auth.currentUser;

    if (user == null) {
      if (mounted) setState(() => loading = false);
      return;
    }

    try {
      final bookingRows = await sb
          .from('bookings')
          .select('*, businesses(*), room_types(name)')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      final reservationRows = await sb
          .from('reservations')
          .select('*, businesses(*)')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      final orderRows = await sb
          .from('orders')
          .select('*, businesses(*)')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      if (!mounted) return;

      setState(() {
        bookings = List<Map<String, dynamic>>.from(bookingRows);
        reservations = List<Map<String, dynamic>>.from(reservationRows);
        orders = List<Map<String, dynamic>>.from(orderRows);
        loading = false;
        error = null;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        loading = false;
        error = 'Could not load your trips. Check your connection.';
      });
    }
  }

  List<Map<String, dynamic>> allItems() {
    final result = <Map<String, dynamic>>[];

    for (final booking in bookings) {
      result.add({
        'type': 'stay',
        'data': booking,
        'date': booking['check_in'],
      });
    }

    for (final reservation in reservations) {
      result.add({
        'type': 'reservation',
        'data': reservation,
        'date': reservation['reservation_date'],
      });
    }

    for (final order in orders) {
      result.add({
        'type': 'order',
        'data': order,
        'date': order['created_at'],
      });
    }

    result.sort(
      (a, b) => a['date'].toString().compareTo(b['date'].toString()),
    );

    return result;
  }

  bool cancelled(Map<String, dynamic> data) {
    return data['status']?.toString().toLowerCase() == 'cancelled';
  }

  bool past(Map<String, dynamic> data, String type, DateTime today) {
    if (cancelled(data)) return false;

    if (type == 'order') {
      return data['status']?.toString().toLowerCase() == 'delivered';
    }

    final target =
        type == 'stay' ? data['check_out'] : data['reservation_date'];

    return date(target).isBefore(today);
  }

  List<Map<String, dynamic>> visibleItems() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return allItems().where((item) {
      final data = Map<String, dynamic>.from(item['data'] as Map);
      final type = item['type'].toString();

      if (tab == 2) return cancelled(data);
      if (tab == 1) return past(data, type, today);

      return !cancelled(data) && !past(data, type, today);
    }).toList();
  }

  String imageFor(Map<String, dynamic> business) {
    final candidates = [
      business['cover_url'],
      business['image_url'],
      business['cover_image_url'],
      business['hero_image_url'],
      business['photo_url'],
    ];

    for (final value in candidates) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }

    return 'https://images.unsplash.com/photo-1582719478250-c89cae4dc85b?auto=format&fit=crop&w=1200&q=80';
  }

  @override
  void dispose() {
    if (realtime != null) sb.removeChannel(realtime!);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visible = visibleItems();

    return Scaffold(
      backgroundColor: FT.obsidian,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: load,
          color: FT.gold,
          backgroundColor: FT.surface,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(30, 20, 30, 32),
            children: [
              const Text(
                'My trips',
                style: TextStyle(
                  color: FT.ivory,
                  fontSize: 38,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'serif',
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Your Ethiopian journey',
                style: TextStyle(color: FT.muted, fontSize: 14),
              ),
              const SizedBox(height: 24),
              _tabs(),
              const SizedBox(height: 28),
              if (sb.auth.currentUser == null)
                const _EmptyTrips(
                  'Sign in to see your trips.',
                  Icons.luggage_outlined,
                )
              else if (loading)
                const Padding(
                  padding: EdgeInsets.all(50),
                  child: Center(
                    child: CircularProgressIndicator(color: FT.gold),
                  ),
                )
              else if (error != null)
                _errorState()
              else if (visible.isEmpty)
                const _EmptyTrips(
                  'Your stays, reservations and orders will appear here.',
                  Icons.luggage_outlined,
                )
              else ...[
                _heroBooking(visible.first),
                const SizedBox(height: 32),
                const Text(
                  'Coming up',
                  style: TextStyle(
                    color: FT.ivory,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'serif',
                  ),
                ),
                const SizedBox(height: 15),
                ...visible.take(8).map(_timelineItem),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabs() {
    const labels = ['Upcoming', 'Past', 'Cancelled'];

    return Container(
      height: 54,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF111518),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF20272A)),
      ),
      child: Row(
        children: labels.asMap().entries.map((entry) {
          final selected = tab == entry.key;

          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => tab = entry.key),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? FT.gold : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  entry.value,
                  style: TextStyle(
                    color: selected ? const Color(0xFF171107) : FT.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _heroBooking(Map<String, dynamic> item) {
    final data = Map<String, dynamic>.from(item['data'] as Map);
    final rawBusiness = data['businesses'];
    final business = rawBusiness is Map
        ? Map<String, dynamic>.from(rawBusiness)
        : <String, dynamic>{};

    final dateText =
        (data['check_in'] ?? data['reservation_date'] ?? '').toString();

    final room = data['room_types'] is Map
        ? (data['room_types']['name'] ?? 'Stay').toString()
        : 'FineTime experience';

    final guests = (data['guests'] ?? data['party_size'] ?? 1).toString();

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111518),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF252A2D)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 265,
            width: double.infinity,
            child: Image.network(
              imageFor(business),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  Container(color: FT.surface),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dateText.length >= 10
                      ? dateText.substring(0, 10)
                      : dateText,
                  style: const TextStyle(
                    color: FT.gold,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  business['name'] ?? 'FineTime stay',
                  style: const TextStyle(
                    color: FT.ivory,
                    fontSize: 27,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'serif',
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  room + ' · ' + guests + ' guests',
                  style: const TextStyle(color: FT.muted),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Color(0xFF7DC49B),
                      size: 17,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      (data['status'] ?? 'Confirmed').toString(),
                      style: const TextStyle(
                        color: Color(0xFF7DC49B),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    const Text(
                      'View booking',
                      style: TextStyle(color: FT.gold),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _timelineItem(Map<String, dynamic> item) {
    final data = Map<String, dynamic>.from(item['data'] as Map);
    final rawBusiness = data['businesses'];
    final business = rawBusiness is Map
        ? Map<String, dynamic>.from(rawBusiness)
        : <String, dynamic>{};

    final dateText =
        (data['reservation_date'] ?? data['check_in'] ?? '').toString();

    final time = (data['reservation_time'] ?? '').toString();
    final location = (business['city'] ?? 'Ethiopia').toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 66,
            child: Text(
              dateText.length >= 10
                  ? dateText.substring(5, 10)
                  : dateText,
              style: const TextStyle(
                color: FT.gold,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Column(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: FT.gold,
                  shape: BoxShape.circle,
                ),
              ),
              Container(
                width: 1,
                height: 52,
                color: const Color(0xFF2A2C2D),
              ),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  business['name'] ?? 'FineTime experience',
                  style: const TextStyle(
                    color: FT.ivory,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'serif',
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  time.isEmpty ? location : time + ' · ' + location,
                  style: const TextStyle(
                    color: FT.muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorState() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text(
            error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: FT.muted),
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: load,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _EmptyTrips extends StatelessWidget {
  final String text;
  final IconData icon;

  const _EmptyTrips(this.text, this.icon);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 55),
      child: Column(
        children: [
          Icon(icon, color: FT.muted, size: 55),
          const SizedBox(height: 14),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: FT.muted),
          ),
        ],
      ),
    );
  }
}
