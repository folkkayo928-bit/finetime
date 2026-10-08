import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';
import '../net.dart';

class ReserveTableScreen extends StatefulWidget {
  final Map<String, dynamic> business;
  const ReserveTableScreen({super.key, required this.business});

  @override
  State<ReserveTableScreen> createState() => _ReserveTableScreenState();
}

class _ReserveTableScreenState extends State<ReserveTableScreen> {
  final sb = Supabase.instance.client;
  final DateFormat _dateDisplayFmt = DateFormat('EEE, MMM d');

  TimeOfDay _time = const TimeOfDay(hour: 19, minute: 0);
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  int _party = 2;
  final _request = TextEditingController();
  final _phone = TextEditingController();
  bool _loadingPhone = true;
  bool _saving = false;
  String? _error, _done;
  String? _savedName;
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
          .select('phone, full_name')
          .eq('id', user.id)
          .maybeSingle();
      final phone = profile?['phone']?.toString().trim();
      final name = profile?['full_name']?.toString().trim();
      if (mounted) {
        if (phone != null && phone.isNotEmpty && _phone.text.isEmpty) {
          _phone.text = phone;
        }
        if (name != null && name.isNotEmpty) {
          _savedName = name;
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
    if (!_canSubmit) return;
    _lastTap = DateTime.now();
    _submit();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 180)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: FT.gold,
            onPrimary: FT.charcoal,
            surface: Color(0xFF1A1713),
            onSurface: FT.ivory,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: FT.gold,
            onPrimary: FT.charcoal,
            surface: Color(0xFF1A1713),
            onSurface: FT.ivory,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _time = picked);
    }
  }

  Future<void> _submit() async {
    if (_phone.text.trim().isEmpty) {
      setState(() => _error = 'Please enter a contact phone number.');
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
      final token = await Net.userAccessToken(sb);
      if (token == null || token.isEmpty) {
        throw Exception('Your FineTime session has expired. Please sign in again.');
      }
      final prof =
          await sb.from('profiles').select('full_name').eq('id', user.id).single();
      final guestName = (prof['full_name'] ?? _savedName ?? 'Guest').toString();

      await sb.functions.invoke(
        'request-restaurant-reservation',
        headers: {'Authorization': 'Bearer $token'},
        body: {
          'business_id': widget.business['id'],
          'reservation_date': _date.toIso8601String().substring(0, 10),
          'reservation_time':
              '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}:00',
          'party_size': _party,
          'contact_phone': _phone.text.trim(),
          'special_request': _request.text.isEmpty ? null : _request.text,
        },
      );
      setState(() => _done = guestName);
    } catch (e) {
      setState(() => _error = 'Could not submit reservation. Please check your connection and retry.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final restaurantName = widget.business['name']?.toString() ?? 'Restaurant';

    return Scaffold(
      backgroundColor: const Color(0xFF0C0A06),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C0A06),
        elevation: 0,
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reserve · $restaurantName',
              style: const TextStyle(
                color: FT.ivory,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Text(
              'Direct table reservation',
              style: TextStyle(
                color: Color(0xFF8E8982),
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
      body: _done != null
          ? _buildSuccessView(restaurantName)
          : _buildReservationForm(restaurantName),
    );
  }

  Widget _buildSuccessView(String restaurantName) {
    final guestName = _done ?? 'Guest';

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: const Color(0xFF14110C),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF2C261F)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: FT.gold.withValues(alpha: 0.15),
                  border: Border.all(color: FT.gold.withValues(alpha: 0.5), width: 1.5),
                ),
                child: const Icon(Icons.check_rounded, color: FT.gold, size: 36),
              ),
              const SizedBox(height: 20),
              const Text(
                'Reservation Requested',
                style: TextStyle(
                  color: FT.ivory,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'serif',
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Reserved for $guestName',
                style: const TextStyle(
                  color: FT.gold,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 22),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1914),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF2E271F)),
                ),
                child: Column(
                  children: [
                    Text(
                      restaurantName,
                      style: const TextStyle(
                        color: FT.ivory,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Container(height: 1, color: const Color(0xFF2A241C)),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            const Text(
                              'DATE',
                              style: TextStyle(color: Color(0xFF8E8982), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _dateDisplayFmt.format(_date),
                              style: const TextStyle(color: FT.ivory, fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        Container(width: 1, height: 28, color: const Color(0xFF2A241C)),
                        Column(
                          children: [
                            const Text(
                              'TIME',
                              style: TextStyle(color: Color(0xFF8E8982), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _time.format(context),
                              style: const TextStyle(color: FT.goldLight, fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        Container(width: 1, height: 28, color: const Color(0xFF2A241C)),
                        Column(
                          children: [
                            const Text(
                              'PARTY',
                              style: TextStyle(color: Color(0xFF8E8982), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$_party Guests',
                              style: const TextStyle(color: FT.ivory, fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'The host team will confirm your table shortly. You can monitor your booking anytime in the Trips tab.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF9E988F),
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 26),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: FT.gold,
                    foregroundColor: const Color(0xFF0C0A06),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReservationForm(String restaurantName) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 40),
      children: [
        // 1. DATE & TIME DUAL LUXURY SELECTOR
        const Text(
          'Reservation Schedule',
          style: TextStyle(
            color: FT.ivory,
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 10),

        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF13110E),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF25211B)),
          ),
          child: Row(
            children: [
              // Date Card
              Expanded(
                child: InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1713),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF2E271F)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.calendar_today_outlined, size: 13, color: FT.gold),
                            SizedBox(width: 6),
                            Text(
                              'DATE',
                              style: TextStyle(
                                color: Color(0xFF8E8982),
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _dateDisplayFmt.format(_date),
                          style: const TextStyle(
                            color: FT.ivory,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 10),

              // Time Card
              Expanded(
                child: InkWell(
                  onTap: _pickTime,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1713),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF2E271F)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.access_time_rounded, size: 13, color: FT.gold),
                            SizedBox(width: 6),
                            Text(
                              'TIME',
                              style: TextStyle(
                                color: Color(0xFF8E8982),
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _time.format(context),
                          style: const TextStyle(
                            color: FT.goldLight,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // 2. PARTY SIZE SECTION (TACTILE LUXURY PILLS)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Party Size',
              style: TextStyle(
                color: FT.ivory,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF221D17),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$_party ${_party == 1 ? 'Guest' : 'Guests'}',
                style: const TextStyle(
                  color: FT.goldLight,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(8, (index) {
              final count = index + 1;
              final isSelected = _party == count;
              return Padding(
                padding: EdgeInsets.only(right: index == 7 ? 0 : 8),
                child: InkWell(
                  onTap: () => setState(() => _party = count),
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF201B13) : const Color(0xFF13110E),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? FT.gold : const Color(0xFF25211B),
                        width: isSelected ? 1.5 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: FT.gold.withValues(alpha: 0.15),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              )
                            ]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      count == 8 ? '8+' : '$count',
                      style: TextStyle(
                        color: isSelected ? FT.goldLight : const Color(0xFF9E988F),
                        fontSize: 15,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),

        const SizedBox(height: 22),

        // 3. CONTACT PHONE NUMBER
        const Text(
          'Contact Phone',
          style: TextStyle(
            color: FT.ivory,
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 10),

        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF13110E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF25211B)),
          ),
          child: TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            style: const TextStyle(color: FT.ivory, fontSize: 15, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: '+251 9.. .. .. ..',
              hintStyle: const TextStyle(color: Color(0xFF6B665F), fontSize: 14),
              prefixIcon: const Icon(Icons.phone_outlined, color: FT.gold, size: 20),
              suffixIcon: _loadingPhone
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: FT.gold),
                      ),
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),

        const SizedBox(height: 20),

        // 4. SPECIAL REQUEST
        const Text(
          'Special Request (Optional)',
          style: TextStyle(
            color: FT.ivory,
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 10),

        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF13110E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF25211B)),
          ),
          child: TextField(
            controller: _request,
            maxLines: 3,
            style: const TextStyle(color: FT.ivory, fontSize: 14),
            decoration: const InputDecoration(
              hintText: 'e.g. Window table, quiet seating, anniversary celebration…',
              hintStyle: TextStyle(color: Color(0xFF6B665F), fontSize: 13),
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(16),
            ),
          ),
        ),

        const SizedBox(height: 20),

        // 5. REASSURANCE & DETAILS CARD
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF15120E),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: FT.gold.withValues(alpha: 0.35),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      restaurantName,
                      style: const TextStyle(
                        color: FT.ivory,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Text(
                    'Table Hold',
                    style: TextStyle(
                      color: FT.goldLight,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(height: 1, color: const Color(0xFF25211B)),
              const SizedBox(height: 12),
              const Row(
                children: [
                  Icon(Icons.check_circle_outline_rounded, size: 15, color: FT.gold),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No reservation fee · Pay for orders at the venue',
                      style: TextStyle(
                        color: Color(0xFFD4CEC4),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Row(
                children: [
                  Icon(Icons.schedule_rounded, size: 15, color: FT.gold),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tables are typically confirmed within 15–30 minutes',
                      style: TextStyle(
                        color: Color(0xFF9E988F),
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Error message if any
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF2A1515),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF5A2222)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Color(0xFFEF5350), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Color(0xFFFF8A80), fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),

        const SizedBox(height: 26),

        // 6. REQUEST RESERVATION BUTTON
        SizedBox(
          width: double.infinity,
          height: 54,
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE3A82D), Color(0xFFEEB843)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: FT.gold.withValues(alpha: 0.28),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _saving ? null : _onSubmitPressed,
                borderRadius: BorderRadius.circular(16),
                child: Center(
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Color(0xFF0C0A06),
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Request Reservation',
                              style: TextStyle(
                                color: Color(0xFF0C0A06),
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 18,
                              color: Color(0xFF0C0A06),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
