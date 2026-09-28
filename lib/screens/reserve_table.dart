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
  final _phone = TextEditingController();
  bool _loadingPhone = true;
  bool _saving = false;
  String? _error, _done;
  DateTime? _lastTap;

  @override
  void initState() {
    super.initState();
    _loadSavedPhone();
  }

  Future<void> _loadSavedPhone() async {
    final user = sb.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _loadingPhone = false);
      return;
    }
    try {
      final profile = await sb
          .from('profiles')
          .select('phone')
          .eq('id', user.id)
          .maybeSingle();
      final phone = profile?['phone']?.toString().trim();
      if (mounted) {
        if (phone != null && phone.isNotEmpty && _phone.text.isEmpty) {
          _phone.text = phone;
        }
        setState(() => _loadingPhone = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingPhone = false);
    }
  }

  @override
  void dispose() {
    _request.dispose();
    _phone.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _saving == false &&
      (_lastTap == null ||
          DateTime.now().difference(_lastTap!) > const Duration(seconds: 2));

  void _onSubmitPressed() {
    if (!_canSubmit) return; // swallow rapid re-taps
    _lastTap = DateTime.now();
    _submit();
  }

  Future<void> _submit() async {
    if (_phone.text.trim().isEmpty) {
      setState(() => _error = 'Please add a phone number so the restaurant can confirm.');
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
      final prof =
          await sb.from('profiles').select('full_name').eq('id', user.id).single();
      await sb.from('reservations').insert({
        'user_id': user.id,
        'business_id': widget.business['id'],
        'reservation_date': _date.toIso8601String().substring(0, 10),
        'reservation_time':
            '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}:00',
        'party_size': _party,
        'contact_phone': _phone.text.trim(),
        'special_request': _request.text.isEmpty ? null : _request.text,
      });
      setState(() => _done =
          'Reservation requested, ${prof['full_name']}.\n\n'
          '${_date.toString().substring(0, 10)} at ${_time.format(context)} · $_party guests\n'
          'Track it in the Trips tab.');
    } catch (e) {
      setState(() => _error = 'Could not submit reservation. Please retry.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('Reserve · ${widget.business['name']}')),
        body: _done != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.check_circle, color: Color(0xFFC6A664), size: 64),
                    const SizedBox(height: 12),
                    Text(_done!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                  ]),
                ))
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
                  child: Text('Date: ${_fmtDate(_date)}'),
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
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                        labelText: 'Your phone number',
                        hintText: '+251 9.. .. .. ..',
                        suffixIcon: _loadingPhone
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                              )
                            : null)),
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
                    onPressed: _onSubmitPressed,
                    child: Text(
                        _saving ? 'Submitting…' : 'Request Reservation')),
              ]),
      );
}
