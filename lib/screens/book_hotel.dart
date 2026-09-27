import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';

class BookHotelScreen extends StatefulWidget {
  final Map business;
  const BookHotelScreen({super.key, required this.business});
  @override
  State<BookHotelScreen> createState() => _BookHotelScreenState();
}

class _BookHotelScreenState extends State<BookHotelScreen> {
  final sb = Supabase.instance.client;
  List _rooms = [];
  String? _roomId;
  DateTime _in = DateTime.now().add(const Duration(days: 1));
  DateTime _out = DateTime.now().add(const Duration(days: 2));
  int _guests = 1;
  bool _saving = false;
  String? _error, _ref;

  @override
  void initState() {
    super.initState();
    sb.from('room_types').select().eq('business_id', widget.business['id']).then((r) => setState(() => _rooms = r));
  }

  Future<void> _submit() async {
    if (_roomId == null) return;
    setState(() { _saving = true; _error = null; });
    try {
      final user = sb.auth.currentUser;
      if (user == null) { setState(() => _error = 'Please sign in first (Me tab).'); return; }
      final row = await sb.from('bookings').insert({
        'user_id': user.id,
        'business_id': widget.business['id'],
        'room_type_id': _roomId,
        'check_in': _in.toIso8601String().substring(0, 10),
        'check_out': _out.toIso8601String().substring(0, 10),
        'guests': _guests,
      }).select('reference').single();
      setState(() => _ref = row['reference']);
    } catch (e) {
      setState(() => _error = 'Could not book — dates may be unavailable. Please adjust and retry.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Book Stay')),
    body: _ref != null
      ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.check_circle, color: FT.gold, size: 64),
          const SizedBox(height: 12),
          const Text('Booking requested!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          Text('Reference: $_ref — track it in Trips.'),
        ])))
      : ListView(padding: const EdgeInsets.all(16), children: [
          const Text('Room type', style: TextStyle(fontWeight: FontWeight.w700)),
          ..._rooms.map((r) => RadioListTile<String>(
            value: r['id'], groupValue: _roomId,
            title: Text(r['name']),
            subtitle: Text(r['public_price'] == null ? 'Price confirmed by hotel' : 'ETB ${r['public_price']}'),
            activeColor: FT.gold,
            onChanged: (v) => setState(() => _roomId = v))),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () async {
                final d = await showDatePicker(context: context, initialDate: _in, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                if (d != null) setState(() => _in = d);
              },
              child: Text('In: ${_in.toString().substring(0, 10)}'))),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton(
              onPressed: () async {
                final d = await showDatePicker(context: context, initialDate: _out, firstDate: _in, lastDate: DateTime.now().add(const Duration(days: 366)));
                if (d != null) setState(() => _out = d);
              },
              child: Text('Out: ${_out.toString().substring(0, 10)}'))),
          ]),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: _guests,
            decoration: const InputDecoration(labelText: 'Guests'),
            items: List.generate(6, (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}'))),
            onChanged: (v) => setState(() => _guests = v!)),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: const TextStyle(color: Colors.red))),
          const SizedBox(height: 20),
          FilledButton(onPressed: _saving ? null : _submit, child: Text(_saving ? 'Submitting…' : 'Request Booking')),
        ]));
}
