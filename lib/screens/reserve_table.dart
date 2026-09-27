import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReserveTableScreen extends StatefulWidget {
  final Map<String, dynamic> business;
  const ReserveTableScreen({super.key, required this.business});
  @override
  State<ReserveTableScreen> createState() => _ReserveTableScreenState();
}

class _ReserveTableScreenState extends State<ReserveTableScreen> {
  final sb = Supabase.instance.client;
  TimeOfDay _time = const TimeOfDay(hour: 19, minute: 0);
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  int _party = 2;
  final _request = TextEditingController();
  bool _saving = false;
  String? _error, _done;

  Future<void> _submit() async {
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
      final prof =
          await sb.from('profiles').select('full_name').eq('id', user.id).single();
      await sb.from('reservations').insert({
        'user_id': user.id,
        'business_id': widget.business['id'],
        'reservation_date': _date.toIso8601String().substring(0, 10),
        'reservation_time':
            '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}:00',
        'party_size': _party,
        'special_request': _request.text.isEmpty ? null : _request.text,
      });
      setState(() =>
          _done = 'Reservation requested, ${prof['full_name']}. Track it in Trips.');
    } catch (e) {
      setState(() => _error = 'Could not submit reservation. Please retry.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('Reserve · ${widget.business['name']}')),
        body: _done != null
            ? Center(
                child: Text(_done!,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)))
            : ListView(padding: const EdgeInsets.all(16), children: [
                OutlinedButton(
                  onPressed: () async {
                    final d = await showDatePicker(
                        context: context,
                        initialDate: _date,
                        firstDate: DateTime.now(),
                        lastDate:
                            DateTime.now().add(const Duration(days: 180)));
                    if (d != null) setState(() => _date = d);
                  },
                  child: Text('Date: ${_date.toString().substring(0, 10)}'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () async {
                    final t =
                        await showTimePicker(context: context, initialTime: _time);
                    if (t != null) setState(() => _time = t);
                  },
                  child: Text('Time: ${_time.format(context)}'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  initialValue: _party,
                  decoration:
                      const InputDecoration(labelText: 'Party size'),
                  items: List.generate(
                      10,
                      (i) => DropdownMenuItem(
                          value: i + 1, child: Text('${i + 1} guests'))),
                  onChanged: (v) => setState(() => _party = v!),
                ),
                const SizedBox(height: 8),
                TextField(
                    controller: _request,
                    decoration: const InputDecoration(
                        labelText: 'Special request (optional)'),
                    maxLines: 2),
                if (_error != null)
                  Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(_error!,
                          style: const TextStyle(color: Colors.red))),
                const SizedBox(height: 16),
                FilledButton(
                    onPressed: _saving ? null : _submit,
                    child: Text(_saving ? 'Submitting…' : 'Request Reservation')),
              ]),
      );
}
