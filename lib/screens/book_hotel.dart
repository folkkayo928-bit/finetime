import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';
import '../net.dart';

class BookHotelScreen extends StatefulWidget {
  final Map<String, dynamic> business;
  const BookHotelScreen({super.key, required this.business});

  @override
  State<BookHotelScreen> createState() => _BookHotelScreenState();
}

class _BookHotelScreenState extends State<BookHotelScreen> {
  final sb = Supabase.instance.client;
  final NumberFormat _currencyFmt = NumberFormat('#,###');
  final DateFormat _dateDisplayFmt = DateFormat('EEE, MMM d');

  List<Map<String, dynamic>> _rooms = [];
  String? _roomId;
  DateTime _in = DateTime.now().add(const Duration(days: 1));
  DateTime _out = DateTime.now().add(const Duration(days: 2));
  int _guests = 1;
  bool _loading = true, _saving = false;
  String? _error, _ref;
  final Map<String, bool> _availability = {};
  bool _checkingAvailability = false;

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
          // Auto-select first available room if none selected
          if (_rooms.isNotEmpty && _roomId == null) {
            _roomId = _rooms.first['id']?.toString();
          }
        });
        await _refreshAvailability();
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refreshAvailability() async {
    if (_rooms.isEmpty || !_out.isAfter(_in)) return;
    setState(() => _checkingAvailability = true);
    try {
      final ids = _rooms.map((r) => r['id']).whereType<String>().toList();
      final rows = await sb
          .from('room_inventory')
          .select('room_type_id,available_rooms,blocked,inventory_date')
          .inFilter('room_type_id', ids)
          .gte('inventory_date', _fmtDate(_in))
          .lt('inventory_date', _fmtDate(_out));
      final next = <String, bool>{};
      for (final room in _rooms) {
        final id = room['id']?.toString();
        if (id == null) continue;
        final inventory = List<Map<String, dynamic>>.from(
            (rows as List).where((x) => x['room_type_id']?.toString() == id));
        if (inventory.isEmpty) {
          next[id] = (num.tryParse(room['total_rooms']?.toString() ?? '0') ?? 0) > 0;
        } else {
          next[id] = inventory.every((x) =>
              x['blocked'] != true &&
              (num.tryParse(x['available_rooms']?.toString() ?? '0') ?? 0) > 0);
        }
      }
      if (mounted) {
        setState(() {
          _availability
            ..clear()
            ..addAll(next);
          if (_roomId != null && _availability[_roomId] == false) {
            _roomId = null;
          }
        });
      }
    } catch (_) {
      // Advisory only; RPC is authoritative
    } finally {
      if (mounted) setState(() => _checkingAvailability = false);
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
    return ((num.tryParse(price.toString()) ?? 0) * _nights).toDouble();
  }

  Future<void> _pickCheckIn() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _in,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
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
      setState(() {
        _in = picked;
        if (!_out.isAfter(_in)) {
          _out = _in.add(const Duration(days: 1));
        }
      });
      _refreshAvailability();
    }
  }

  Future<void> _pickCheckOut() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _out.isAfter(_in) ? _out : _in.add(const Duration(days: 1)),
      firstDate: _in.add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 366)),
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
      setState(() => _out = picked);
      _refreshAvailability();
    }
  }

  Future<void> _submit() async {
    if (_roomId == null) {
      setState(() => _error = 'Please select a room type.');
      return;
    }
    if (_nights < 1) {
      setState(() => _error = 'Check-out must be at least one night after check-in.');
      return;
    }
    final cap = _selectedRoom?['capacity'];
    if (cap is int && _guests > cap) {
      setState(() => _error = 'This room accommodates up to $cap guests.');
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
      final response = await sb.functions.invoke(
        'request-hotel-booking',
        headers: {'Authorization': 'Bearer $token'},
        body: {
          'business_id': widget.business['id'],
          'room_type_id': _roomId,
          'check_in': _in.toIso8601String().substring(0, 10),
          'check_out': _out.toIso8601String().substring(0, 10),
          'guests': _guests,
        },
      );
      final data = response.data;
      String? ref;
      if (data is List && data.isNotEmpty) {
        final first = data.first;
        if (first is Map) ref = first['reference']?.toString();
      } else if (data is Map) {
        ref = data['reference']?.toString();
      }
      if (ref == null || ref.isEmpty) {
        throw Exception('The hotel could not accept this request.');
      }
      setState(() => _ref = ref);
    } catch (e) {
      setState(() => _error = e.toString().contains('FunctionsHttpException')
          ? 'Could not complete booking right now. Please try again.'
          : 'Could not book: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final hotelName = widget.business['name']?.toString() ?? 'Hotel';

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
              'Book · $hotelName',
              style: const TextStyle(
                color: FT.ivory,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Text(
              'Direct hotel reservation',
              style: TextStyle(
                color: Color(0xFF8E8982),
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
      body: _ref != null
          ? _buildSuccessView(hotelName)
          : _loading
              ? const Center(child: CircularProgressIndicator(color: FT.gold))
              : _rooms.isEmpty
                  ? _buildEmptyRoomsView()
                  : _buildBookingForm(),
    );
  }

  Widget _buildEmptyRoomsView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1713),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF2C261F)),
              ),
              child: const Icon(Icons.hotel_outlined, size: 36, color: FT.gold),
            ),
            const SizedBox(height: 18),
            const Text(
              'No rooms currently listed',
              style: TextStyle(
                color: FT.ivory,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Rooms are being updated by the property. You can call the hotel directly from their profile page.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF8E8982), fontSize: 13, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessView(String hotelName) {
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
                'Booking Requested',
                style: TextStyle(
                  color: FT.ivory,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'serif',
                ),
              ),
              const SizedBox(height: 6),
              Text(
                hotelName,
                style: const TextStyle(
                  color: FT.gold,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1914),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF2E271F)),
                ),
                child: Column(
                  children: [
                    const Text(
                      'BOOKING REFERENCE',
                      style: TextStyle(
                        color: Color(0xFF8E8982),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _ref ?? '',
                      style: const TextStyle(
                        color: FT.ivory,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Your request has been received by the property. You can view updates and details in your Trips tab.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF9E988F),
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 28),
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

  Widget _buildBookingForm() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 40),
      children: [
        // 1. ROOM TYPE SECTION
        const Text(
          'Select Room Type',
          style: TextStyle(
            color: FT.ivory,
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 12),

        ..._rooms.map((r) {
          final isSelected = _roomId == r['id'];
          final isAvailable = _availability[r['id']?.toString()] != false;
          final price = num.tryParse(r['public_price']?.toString() ?? '');
          final capacity = r['capacity'];

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              onTap: isAvailable ? () => setState(() => _roomId = r['id'] as String) : null,
              borderRadius: BorderRadius.circular(16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF1B1710)
                      : const Color(0xFF13110E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? FT.gold
                        : const Color(0xFF25211B),
                    width: isSelected ? 1.5 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: FT.gold.withValues(alpha: 0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          )
                        ]
                      : null,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  r['name']?.toString() ?? 'Room',
                                  style: TextStyle(
                                    color: isSelected ? FT.ivory : const Color(0xFFE2DDD5),
                                    fontSize: 16,
                                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (capacity != null) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF221D17),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.person_outline_rounded,
                                          size: 11, color: Color(0xFF9E988F)),
                                      const SizedBox(width: 3),
                                      Text(
                                        '$capacity',
                                        style: const TextStyle(
                                          color: Color(0xFF9E988F),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 5),
                          if (_checkingAvailability)
                            const Text(
                              'Checking live availability…',
                              style: TextStyle(color: Color(0xFF8E8982), fontSize: 12),
                            )
                          else if (!isAvailable)
                            const Text(
                              'Unavailable for chosen dates',
                              style: TextStyle(color: Color(0xFFD9534F), fontSize: 12, fontWeight: FontWeight.w600),
                            )
                          else if (price != null)
                            Row(
                              children: [
                                Text(
                                  'ETB ${_currencyFmt.format(price)}',
                                  style: const TextStyle(
                                    color: FT.goldLight,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const Text(
                                  ' / night',
                                  style: TextStyle(color: Color(0xFF8E8982), fontSize: 12),
                                ),
                              ],
                            )
                          else
                            const Text(
                              'Rate confirmed upon request',
                              style: TextStyle(color: Color(0xFF8E8982), fontSize: 12),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? FT.gold : const Color(0xFF4A443A),
                          width: isSelected ? 6 : 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),

        const SizedBox(height: 18),

        // 2. STAY DATES SELECTOR (ELEGANT DUAL-PILL CARD)
        const Text(
          'Dates of Stay',
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
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF25211B)),
          ),
          child: Row(
            children: [
              // Check-in
              Expanded(
                child: InkWell(
                  onTap: _pickCheckIn,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1713),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF2E271F)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.calendar_today_outlined, size: 12, color: FT.gold),
                            SizedBox(width: 6),
                            Text(
                              'CHECK-IN',
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
                          _dateDisplayFmt.format(_in),
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

              // Duration Badge
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF221D17),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF2E271F)),
                  ),
                  child: Text(
                    '$_nights n',
                    style: const TextStyle(
                      color: FT.goldLight,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),

              // Check-out
              Expanded(
                child: InkWell(
                  onTap: _pickCheckOut,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1713),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF2E271F)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.event_available_outlined, size: 12, color: FT.gold),
                            SizedBox(width: 6),
                            Text(
                              'CHECK-OUT',
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
                          _dateDisplayFmt.format(_out),
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
            ],
          ),
        ),

        const SizedBox(height: 18),

        // 3. GUESTS SELECTION
        const Text(
          'Guests',
          style: TextStyle(
            color: FT.ivory,
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 10),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF13110E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF25211B)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _guests,
              isExpanded: true,
              dropdownColor: const Color(0xFF1C1813),
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: FT.gold),
              items: List.generate(
                6,
                (i) => DropdownMenuItem(
                  value: i + 1,
                  child: Row(
                    children: [
                      const Icon(Icons.person_outline_rounded, size: 18, color: Color(0xFF8E8982)),
                      const SizedBox(width: 10),
                      Text(
                        '${i + 1} Guest${i == 0 ? '' : 's'}',
                        style: const TextStyle(color: FT.ivory, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
              onChanged: (v) {
                if (v != null) setState(() => _guests = v);
              },
            ),
          ),
        ),

        // 4. PRICE BREAKDOWN & LUXURY SUMMARY CARD (REPLACES OLD WHITE BOX)
        if (_total != null) ...[
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(18),
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
                // Room title & summary breakdown
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        _selectedRoom?['name']?.toString() ?? 'Selected Room',
                        style: const TextStyle(
                          color: FT.ivory,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '$_nights night${_nights == 1 ? '' : 's'} · $_guests guest${_guests == 1 ? '' : 's'}',
                      style: const TextStyle(
                        color: Color(0xFF9E988F),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(height: 1, color: const Color(0xFF25211B)),
                const SizedBox(height: 12),

                // Total price line
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TOTAL ESTIMATE',
                          style: TextStyle(
                            color: Color(0xFF8E8982),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Taxes & fees included',
                          style: TextStyle(
                            color: Color(0xFF6B665F),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'ETB ${_currencyFmt.format(_total)}',
                      style: const TextStyle(
                        color: FT.goldLight,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Reassuring perks badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1D1812),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF2C241B)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.shield_outlined, size: 15, color: FT.gold),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Pay at the hotel · No online payment needed',
                          style: TextStyle(
                            color: Color(0xFFD4CEC4),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],

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

        const SizedBox(height: 28),

        // 5. REQUEST BOOKING BUTTON
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
                onTap: _saving ? null : _submit,
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
                              'Request Booking',
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
