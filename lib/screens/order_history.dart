import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  final sb = Supabase.instance.client;

  List<Map<String, dynamic>> orders = [];
  List<Map<String, dynamic>> reservations = [];
  List<Map<String, dynamic>> bookings = [];

  bool loading = true;
  String? error;
  int tab = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = sb.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => loading = false);
      return;
    }

    try {
      final results = await Future.wait([
        sb.from('orders').select('*, businesses(name,cover_url)').eq('user_id', user.id).order('created_at', ascending: false),
        sb.from('reservations').select('*, businesses(name,cover_url)').eq('user_id', user.id).order('created_at', ascending: false),
        sb.from('bookings').select('*, businesses(name,cover_url), room_types(name)').eq('user_id', user.id).order('created_at', ascending: false),
      ]);

      if (!mounted) return;
      setState(() {
        orders = List<Map<String, dynamic>>.from(results[0] as List);
        reservations = List<Map<String, dynamic>>.from(results[1] as List);
        bookings = List<Map<String, dynamic>>.from(results[2] as List);
        loading = false;
        error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = 'Could not load your history. Check your connection.';
      });
    }
  }

  String _status(dynamic value) {
    final raw = value?.toString().trim() ?? 'requested';
    if (raw.isEmpty) return 'Requested';
    return raw[0].toUpperCase() + raw.substring(1);
  }

  String _date(dynamic value) {
    final raw = value?.toString() ?? '';
    return raw.length >= 10 ? raw.substring(0, 10) : raw;
  }

  String _businessName(Map<String, dynamic> row) {
    final value = row['businesses'];
    if (value is Map) return (value['name'] ?? 'FineTime place').toString();
    return 'FineTime place';
  }

  Widget _image(Map<String, dynamic> row) {
    final value = row['businesses'];
    final business = value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
    final url = (business['cover_url'] ?? '').toString().trim();

    if (url.isEmpty) {
      return Container(
        width: 76,
        height: 76,
        color: FT.surface,
        child: const Icon(Icons.place_outlined, color: FT.muted),
      );
    }

    return Image.network(
      url,
      width: 76,
      height: 76,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: FT.surface,
        child: const Icon(Icons.place_outlined, color: FT.muted),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = tab == 0 ? orders : tab == 1 ? reservations : bookings;

    return Scaffold(
      backgroundColor: FT.obsidian,
      appBar: AppBar(title: const Text('Order history')),
      body: RefreshIndicator(
        onRefresh: _load,
        color: FT.gold,
        backgroundColor: FT.surface,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 36),
          children: [
            const Text(
              'Everything you have arranged',
              style: TextStyle(
                color: FT.ivory,
                fontSize: 27,
                fontWeight: FontWeight.w800,
                fontFamily: 'serif',
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Food orders, dining reservations and hotel stays are kept here.',
              style: TextStyle(color: FT.muted, height: 1.4),
            ),
            const SizedBox(height: 20),
            _tabs(),
            const SizedBox(height: 18),
            if (loading)
              const Padding(
                padding: EdgeInsets.all(50),
                child: Center(child: CircularProgressIndicator(color: FT.gold)),
              )
            else if (error != null)
              _error()
            else if (current.isEmpty)
              _empty()
            else
              ...current.map(_card),
          ],
        ),
      ),
    );
  }

  Widget _tabs() {
    const labels = ['Food orders', 'Dining', 'Stays'];

    return Container(
      height: 52,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF111518),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFF252A2D)),
      ),
      child: Row(
        children: List.generate(labels.length, (index) {
          final selected = tab == index;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => tab = index),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? FT.gold : Colors.transparent,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Text(
                  labels[index],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected ? const Color(0xFF171107) : FT.muted,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _card(Map<String, dynamic> row) {
    final isOrder = tab == 0;
    final isDining = tab == 1;
    final status = _status(row['status']);
    final date = _date(isOrder ? row['created_at'] : isDining ? row['reservation_date'] : row['check_in']);

    final detail = isOrder
        ? 'ETB ' + (row['total'] ?? 0).toString() + ' · ' + status
        : isDining
            ? date + ' · ' + (row['reservation_time'] ?? '').toString()
            : date + ' · ' + (row['room_types'] is Map ? (row['room_types']['name'] ?? 'Stay') : 'Stay');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF111518),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF252A2D)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: _image(row),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _businessName(row),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: FT.ivory,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'serif',
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    detail,
                    style: const TextStyle(color: FT.cream, fontSize: 12),
                  ),
                  if (!isOrder)
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text(
                        _status(row['status']),
                        style: TextStyle(
                          color: row['status']?.toString() == 'cancelled'
                              ? const Color(0xFFE58B80)
                              : const Color(0xFF7DC49B),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _empty() => const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            Icon(Icons.receipt_long_outlined, color: FT.muted, size: 55),
            SizedBox(height: 14),
            Text(
              'Nothing here yet.',
              style: TextStyle(color: FT.cream, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 6),
            Text(
              'Your FineTime activity will appear in this history.',
              textAlign: TextAlign.center,
              style: TextStyle(color: FT.muted),
            ),
          ],
        ),
      );

  Widget _error() => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: FT.muted),
            ),
            const SizedBox(height: 10),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
}
