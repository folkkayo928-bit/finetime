import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';

class BookHotelScreen extends StatefulWidget {
  final Map<String, dynamic> business;
  const BookHotelScreen({super.key, required this.business});
  @override
  State<BookHotelScreen> createState() => _BookHotelScreenState();
}

class _BookHotelScreenState extends State<BookHotelScreen> {
  final sb = Supabase.instance.client;
  List<Map<String, dynamic>> _rooms = [];
  String? _roomId;
  DateTime _in = DateTime.now().add(const Duration(days: 1));
  DateTime _out = DateTime.now().add(const Duration(days: 2));
  int _guests = 1;
  bool _loading = true, _saving = false;
  String? _error, _ref;

  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  Future<void> _loadRooms() async {
    try {
      final r = await sb
          .from('room_types')
          .select()
          .eq('business_id', widget.business['id']);
      if (mounted) {
        setState(() {
          _rooms = List<Map<String, dynamic>>.from(r);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Ensures the signed-in user has a profiles row.
  /// bookings.user_id references profiles(id); without this row every
  /// insert fails with a foreign-key violation that used to be masked
  /// as "dates may be unavailable".
  Future<void> _ensureProfile() async {
    final u = sb.auth.currentUser;
    if (u == null) return;
    final p = await sb
        .from('profiles')
        .select('id')
        .eq('id', u.id)
        .maybeSingle();
    if (p == null) {
      await sb.from('profiles').upsert({
        'id': u.id,
        'full_name': u.userMetadata?['full_name'] ?? u.email?.split('@').first ?? 'Guest',
      });
    }
  }

  Map<String, dynamic>? get _selectedRoom => _rooms
      .where((r) => r['id'] == _roomId)
      .cast<Map<String, dynamic>?>()
      .firstOrNull;

  int get _nights => _out.difference(_in).inDays;

  double? get _total {
    final room = _selectedRoom;
    final price = room?['public_price'];
    if (price == null || _nights <= 0) return null;
    return (num.tryParse(price.toString()) ?? 0) * _nights;
  }

  Future<void> _submit() async {
    if (_roomId == null) {
      setState(() => _error = 'Please choose a room type.');
      return;
    }
    if (_nights < 1) {
      setState(() => _error =
          'Check-out must be at least one night after check-in.');
      return;
    }
    final cap = _selectedRoom?['capacity'];
    if (cap is int && _guests > cap) {
      setState(() => _error = 'This room fits up to $cap guests.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final user = sb.auth.currentUser;
      if (user == null) {
        setState(() => _error = 'Please sign in first (Me tab).');
        return;
      }
      final result = await sb.rpc('request_hotel_booking', params: {
        'p_business_id': widget.business['id'],
        'p_room_type_id': _roomId,
        'p_check_in': _in.toIso8601String().substring(0, 10),
        'p_check_out': _out.toIso8601String().substring(0, 10),
        'p_guests': _guests,
      });
      final rows = List<Map<String, dynamic>>.from(result as List);
      if (rows.isEmpty) throw Exception('The hotel could not accept this request.');
      setState(() => _ref = rows.first['reference'] as String);
    } catch (e) {
      // Show the real reason so failures are diagnosable.
      setState(() => _error = 'Could not book: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar:
            AppBar(title: Text('Book · ${widget.business['name'] ?? 'Hotel'}')),
        body: _ref != null
            ? Center(
                child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle,
                              color: FT.gold, size: 64),
                          const SizedBox(height: 12),
                          const Text('Booking requested!',
                              style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          Text('Reference: $_ref'),
                          const Text('Track it in the Trips tab.'),
                        ])))
            : _loading
                ? const Center(child: CircularProgressIndicator())
                : _rooms.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.hotel_outlined,
                                    size: 48, color: Colors.white54),
                                const SizedBox(height: 12),
                                const Text(
                                    'No rooms listed yet for this hotel.'),
                                const Text(
                                    'Price will be confirmed by the hotel directly.',
                                    style: TextStyle(
                                        color: Colors.white70)),
                              ]),
                        ))
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                        const Text('Room type',
                            style: TextStyle(
                                fontWeight: FontWeight.w700)),
                        ..._rooms.map((r) => ListTile(
                              title: Text(r['name'] ?? ''),
                              subtitle: Text(r['public_price'] == null
                                  ? 'Price confirmed by hotel'
                                  : 'ETB ${r['public_price']} / night'),
                              trailing: _roomId == r['id']
                                  ? const Icon(
                                      Icons.radio_button_checked,
                                      color: FT.gold)
                                  : const Icon(
                                      Icons.radio_button_unchecked,
                                      color: Colors.white54),
                              onTap: () => setState(
                                  () => _roomId = r['id'] as String),
                            )),
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(
                              child: OutlinedButton(
                            onPressed: () async {
                              final d = await showDatePicker(
                                  context: context,
                                  initialDate: _in,
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now()
                                      .add(const Duration(days: 365)));
                              if (d != null) {
                                setState(() {
                                  _in = d;
                                  if (!_out.isAfter(_in)) {
                                    _out = _in.add(
                                        const Duration(days: 1));
                                  }
                                });
                              }
                            },
                            child: Text('In: ${_fmtDate(_in)}'),
                          )),
                          const SizedBox(width: 8),
                          Expanded(
                              child: OutlinedButton(
                            onPressed: () async {
                              final d = await showDatePicker(
                                  context: context,
                                  initialDate: _out.isAfter(_in)
                                      ? _out
                                      : _in.add(
                                          const Duration(days: 1)),
                                  firstDate:
                                      _in.add(const Duration(days: 1)),
                                  lastDate: DateTime.now()
                                      .add(const Duration(days: 366)));
                              if (d != null) setState(() => _out = d);
                            },
                            child: Text('Out: ${_fmtDate(_out)}'),
                          )),
                        ]),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int>(
                          initialValue: _guests,
                          decoration: const InputDecoration(
                              labelText: 'Guests'),
                          items: List.generate(
                              6,
                              (i) => DropdownMenuItem(
                                  value: i + 1,
                                  child: Text('${i + 1}'))),
                          onChanged: (v) =>
                              setState(() => _guests = v!),
                        ),
                        if (_total != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: FT.ivory,
                              borderRadius:
                                  BorderRadius.circular(12),
                            ),
                            child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      '${_selectedRoom?['name'] ?? ''} · $_nights night${_nights == 1 ? '' : 's'} · $_guests guest${_guests == 1 ? '' : 's'}'),
                                  const SizedBox(height: 4),
                                  Text(
                                      'ETB ${_total!.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight:
                                              FontWeight.w800,
                                          color: FT.charcoal)),
                                  const SizedBox(height: 4),
                                  const Text(
                                      'Pay at the hotel. No online payment needed.',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.white70)),
                                ]),
                          ),
                        ],
                        if (_error != null)
                          Padding(
                              padding:
                                  const EdgeInsets.only(top: 12),
                              child: Text(_error!,
                                  style: const TextStyle(
                                      color: Colors.red))),
                        const SizedBox(height: 20),
                        FilledButton(
                            onPressed: _saving ? null : _submit,
                            child: Text(_saving
                                ? 'Submitting…'
                                : 'Request Booking')),
                      ]));
}
