import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart' as launcher;
import 'package:qr_flutter/qr_flutter.dart';

import '../net.dart';
import '../theme.dart';
import 'book_hotel.dart';
import 'reserve_table.dart';
import 'order_food.dart';
import 'review.dart';

class BusinessProfileScreen extends StatefulWidget {
  final String businessId;
  final Map<String, dynamic>? initialBusiness;

  const BusinessProfileScreen({
    super.key,
    required this.businessId,
    this.initialBusiness,
  });

  @override
  State<BusinessProfileScreen> createState() => _BusinessProfileScreenState();
}

class _BusinessProfileScreenState extends State<BusinessProfileScreen> {
  final sb = Supabase.instance.client;
  Map<String, dynamic>? b;
  List<Map<String, dynamic>> rooms = [];
  List<Map<String, dynamic>> menu = [];
  List<Map<String, dynamic>> reviews = [];
  List<Map<String, dynamic>> promotions = [];
  bool saved = false;
  bool reviewEligible = false;
  String? error;
  RealtimeChannel? _realtime;

  bool get isHotel => b?['category']?.toString().toLowerCase() == 'hotel';
  bool get hasFood => menu.isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (widget.initialBusiness != null) {
      b = Map<String, dynamic>.from(widget.initialBusiness!);
    }
    load();
    checkSaved();
  }

  List<String> strings(dynamic value) {
    if (value is List) {
      return value.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
    }
    if (value is String && value.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) {
          return decoded.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
        }
      } catch (_) {}
    }
    return const [];
  }

  Map<String, dynamic> asMap(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is String && value.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return const {};
  }

  String city() {
    final raw = b?['cities'];
    if (raw is Map) {
      return (raw['name'] ?? '').toString().trim();
    }
    if (raw is List && raw.isNotEmpty && raw.first is Map) {
      final first = Map<String, dynamic>.from(raw.first as Map);
      return (first['name'] ?? '').toString().trim();
    }
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) return (decoded['name'] ?? '').toString().trim();
        if (decoded is List && decoded.isNotEmpty && decoded.first is Map) {
          final first = Map<String, dynamic>.from(decoded.first as Map);
          return (first['name'] ?? '').toString().trim();
        }
      } catch (_) {}
    }
    return '';
  }

  void _subscribeToUpdates() {
    _realtime = sb.channel('business-live-${widget.businessId}')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'businesses',
        callback: (_) => load(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'room_types',
        callback: (_) => load(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'menu_categories',
        callback: (_) => load(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'menu_items',
        callback: (_) => load(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'promotions',
        callback: (_) => load(),
      )
      ..subscribe();
  }

  Future<void> checkSaved() async {
    final user = sb.auth.currentUser;
    if (user == null) return;
    try {
      final row = await sb.from('saved_places').select('business_id')
          .eq('user_id', user.id).eq('business_id', widget.businessId).maybeSingle();
      if (mounted) setState(() => saved = row != null);
    } catch (_) {}
  }

  Future<dynamic> _safeOptional(Future<dynamic> request) async {
    try {
      return await request.timeout(const Duration(seconds: 8));
    } catch (_) {
      return <dynamic>[];
    }
  }

  Future<void> load() async {
    try {
      Map<String, dynamic>? business = widget.initialBusiness == null
          ? null
          : Map<String, dynamic>.from(widget.initialBusiness!);

      // When a list/search screen already has the business row, render that
      // data immediately and only fetch the richer profile in the background.
      if (business == null) {
        final row = await sb.from('businesses')
            .select('*')
            .eq('id', widget.businessId)
            .eq('is_published', true)
            .maybeSingle()
            .timeout(const Duration(seconds: 10));
        if (row == null) {
          if (mounted) {
            setState(() => error = 'This business is not available.');
          }
          return;
        }
        business = Map<String, dynamic>.from(row);
        if (mounted) {
          setState(() {
            b = business;
            error = null;
          });
        }
      }

      final cityId = business['city_id']?.toString();
      final extras = await Future.wait<dynamic>([
        if (cityId != null && cityId.isNotEmpty)
          _safeOptional(
            sb.from('cities').select('name').eq('id', cityId).maybeSingle(),
          )
        else
          Future.value(<dynamic>[]),
        _safeOptional(
          sb.from('room_types')
              .select()
              .eq('business_id', widget.businessId)
              .order('name'),
        ),
        _safeOptional(
          sb.from('menu_categories')
              .select('*, menu_items(*)')
              .eq('business_id', widget.businessId)
              .order('sort_order'),
        ),
        _safeOptional(
          sb.from('reviews')
              .select('rating,body,created_at')
              .eq('business_id', widget.businessId)
              .order('created_at', ascending: false),
        ),
        _safeOptional(
          sb.from('promotions')
              .select('id,title,description,badge,image_url,terms,starts_on,ends_on,status')
              .eq('business_id', widget.businessId)
              .eq('status', 'active')
              .order('starts_on', ascending: true),
        ),
      ]);

      if (!mounted) return;
      final city = extras[0] is Map
          ? Map<String, dynamic>.from(extras[0] as Map)
          : null;
      final current = Map<String, dynamic>.from(business);
      if (city != null) current['cities'] = city;

      setState(() {
        b = current;
        rooms = List<Map<String, dynamic>>.from(extras[1] as List);
        menu = List<Map<String, dynamic>>.from(extras[2] as List);
        reviews = List<Map<String, dynamic>>.from(extras[3] as List);
        promotions = List<Map<String, dynamic>>.from(extras[4] as List);
      });

      checkReviewEligibility();
    } catch (e) {
      if (mounted) setState(() => error = Net.friendly(e));
    }
  }

  Future<void> checkReviewEligibility() async {
    final user = sb.auth.currentUser;
    if (user == null) return;
    try {
      final booking = await sb.from('bookings').select('id')
          .eq('user_id', user.id).eq('business_id', widget.businessId)
          .eq('status', 'completed').limit(1);
      if (booking.isNotEmpty) {
        if (mounted) setState(() => reviewEligible = true);
        return;
      }
      final reservation = await sb.from('reservations').select('id')
          .eq('user_id', user.id).eq('business_id', widget.businessId)
          .eq('status', 'completed').limit(1);
      if (reservation.isNotEmpty) {
        if (mounted) setState(() => reviewEligible = true);
        return;
      }
      final order = await sb.from('orders').select('id')
          .eq('user_id', user.id).eq('business_id', widget.businessId)
          .inFilter('status', ['delivered', 'completed']).limit(1);
      if (mounted) setState(() => reviewEligible = order.isNotEmpty);
    } catch (_) {}
  }

  Future<void> launchUrlValue(String value) async {
    try {
      final sanitized = value.startsWith('tel:')
          ? 'tel:${value.substring(4).replaceAll(RegExp(r'[\s()\-–]'), '')}'
          : value;
      final uri = Uri.tryParse(sanitized);
      if (uri != null) {
        await launcher.launchUrl(uri, mode: launcher.LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  Future<void> toggleSave() async {
    final user = sb.auth.currentUser;
    if (user == null) {
      message('Sign in to save places.');
      return;
    }
    try {
      if (saved) {
        await sb.from('saved_places').delete()
            .eq('user_id', user.id).eq('business_id', widget.businessId);
      } else {
        await sb.from('saved_places').insert({
          'user_id': user.id, 'business_id': widget.businessId
        });
      }
      if (mounted) setState(() => saved = !saved);
    } catch (_) {
      message('Could not update saved places.');
    }
  }

  void message(String text) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void openBooking() {
    if (b == null) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => isHotel
          ? BookHotelScreen(business: Map<String, dynamic>.from(b!))
          : ReserveTableScreen(business: Map<String, dynamic>.from(b!)),
    ));
  }

  void openMenu() {
    if (b == null || menu.isEmpty) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => OrderFoodScreen(
        business: Map<String, dynamic>.from(b!),
        menuCategories: menu,
      ),
    ));
  }

  void showQr() {
    final id = b?['id']?.toString();
    if (id == null || id.isEmpty || !hasFood) return;
    final url = 'https://finetime.cc/website/menu.html?id=${Uri.encodeComponent(id)}';
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('QR Menu'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          QrImageView(data: url, size: 230, backgroundColor: Colors.white),
          const SizedBox(height: 12),
          const Text('Scan this code to open the digital menu directly.', textAlign: TextAlign.center),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  Future<void> openReview() async {
    if (!reviewEligible) {
      message('Reviews are available after a completed stay, table reservation, or delivered order.');
      return;
    }
    final changed = await Navigator.push(context, MaterialPageRoute(
      builder: (_) => ReviewScreen(
        businessId: b!['id'],
        businessName: b!['name'] ?? '',
      ),
    ));
    if (changed == true) await load();
  }

  void showAllReviews() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: FT.charcoal,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .75,
        maxChildSize: .95,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(20),
          children: [
            const Text('All reviews', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            ...reviews.map(reviewTile),
          ],
        ),
      ),
    );
  }

  Widget image(String? url, {double height = 180, double? width}) {
    final value = url?.trim() ?? '';
    Widget fallback() => Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF25383B), Color(0xFF101617)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Center(child: Icon(Icons.hotel_outlined, color: Colors.white24, size: 42)),
    );
    if (value.isEmpty) return fallback();
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Image.network(
        value,
        height: height,
        width: width,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.low,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return fallback();
        },
        errorBuilder: (_, __, ___) => fallback(),
      ),
    );
  }

  Widget title(String text, {String? action, VoidCallback? onAction}) {
    return Row(children: [
      Expanded(child: Text(text.toUpperCase(), style: const TextStyle(
        color: FT.gold, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 3))),
      if (action != null) TextButton(onPressed: onAction, child: Text(action, style: const TextStyle(color: FT.gold))),
    ]);
  }

  Widget pill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B1B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white70)),
    );
  }

  Widget infoCard(IconData icon, String heading, String value) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: FT.gold, size: 21),
        const SizedBox(width: 13),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(heading.toUpperCase(), style: const TextStyle(color: FT.gold, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 2)),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(color: Colors.white70)),
        ])),
      ]),
    );
  }

  Widget roomCard(Map<String, dynamic> room) {
    final price = room['public_price'];
    final amenityList = strings(room['amenities']);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 112, child: image(room['photo_url']?.toString(), height: 112, width: 112)),
          const SizedBox(width: 13),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(room['name'] ?? '', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 5),
            Text(
              '${room['capacity'] ?? 0} guests${room['beds'] == null ? '' : ' · ${room['beds']}'}',
              style: const TextStyle(color: Colors.white60),
            ),
            if ((room['description'] ?? '').toString().isNotEmpty)
              Padding(padding: const EdgeInsets.only(top: 6), child: Text(
                room['description'].toString(), maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, height: 1.25))),
            if (amenityList.isNotEmpty)
              Padding(padding: const EdgeInsets.only(top: 8), child: Wrap(
                spacing: 6, runSpacing: 6, children: amenityList.take(3).map(pill).toList())),
            const SizedBox(height: 10),
            Text(
              price == null ? 'Rate confirmed by hotel' : 'ETB $price / night',
              style: const TextStyle(color: FT.gold, fontWeight: FontWeight.w800),
            ),
          ])),
        ]),
      ),
    );
  }

  Widget menuCategory(Map<String, dynamic> category) {
    final items = ((category['menu_items'] ?? []) as List)
        .map((e) => Map<String, dynamic>.from(e))
        .where((e) => e['is_available'] != false).toList();
    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(category['name'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        ...items.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if ((item['photo_url'] ?? '').toString().isNotEmpty)
              Padding(padding: const EdgeInsets.only(right: 11), child: image(item['photo_url'].toString(), height: 64, width: 64)),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
              if ((item['description'] ?? '').toString().isNotEmpty)
                Padding(padding: const EdgeInsets.only(top: 3), child: Text(
                  item['description'].toString(), maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white60))),
            ])),
            const SizedBox(width: 8),
            Text(item['price'] == null ? '' : 'ETB ${item['price']}',
              style: const TextStyle(color: FT.gold, fontWeight: FontWeight.w800)),
          ]),
        )),
      ]),
    );
  }

  Widget reviewTile(Map<String, dynamic> review) {
    final rating = int.tryParse(review['rating']?.toString() ?? '') ?? 0;
    final body = (review['body'] ?? '').toString().trim();
    final date = (review['created_at'] ?? '').toString().split('T').first;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('★ $rating.0', style: const TextStyle(color: FT.gold, fontWeight: FontWeight.w800)),
            const Spacer(),
            if (date.isNotEmpty) Text(date, style: const TextStyle(color: Colors.white54)),
          ]),
          if (body.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8),
            child: Text(body, style: const TextStyle(height: 1.35))),
        ]),
      ),
    );
  }

  Widget bottomAction(IconData icon, String label, VoidCallback? action) {
    return Expanded(child: InkWell(
      onTap: action,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: action == null ? Colors.white24 : FT.gold, size: 22),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(
            color: action == null ? Colors.white24 : Colors.white70,
            fontSize: 11, fontWeight: FontWeight.w700)),
        ]),
      ),
    ));
  }

  Widget bottomActions() {
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF121212),
          border: Border(top: BorderSide(color: Colors.white12)),
        ),
        padding: const EdgeInsets.fromLTRB(8, 9, 8, 7),
        child: Row(children: [
          bottomAction(Icons.call_outlined, 'Call',
            b?['phone'] == null ? null : () => launchUrlValue('tel:${b!['phone']}')),
          bottomAction(Icons.directions_outlined, 'Directions',
            b?['lat'] == null ? null : () => launchUrlValue(
              'https://maps.google.com/?q=${b!['lat']},${b!['lng']}')),
          if (isHotel)
            bottomAction(Icons.hotel_outlined, 'Book', openBooking)
          else ...[
            bottomAction(Icons.event_available_outlined, 'Reserve', openBooking),
            if (hasFood) bottomAction(Icons.restaurant_outlined, 'Order', openMenu),
          ],
        ]),
      ),
    );
  }

  @override
  void dispose() {
    if (_realtime != null) sb.removeChannel(_realtime!);
    super.dispose();
  }


  int _profileTab = 0;
  static const _profileTabs = ['About', 'Highlights', 'Gallery', 'Hours', 'Reviews'];

  void _selectProfileTab(int index) {
    if (mounted) setState(() => _profileTab = index);
  }

  Widget _profileTabBar() {
    return Container(
      color: const Color(0xFF090B0C),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white10))),
      child: Row(
        children: List.generate(_profileTabs.length, (i) {
          final active = _profileTab == i;
          return Expanded(
            child: InkWell(
              onTap: () => _selectProfileTab(i),
              child: SizedBox(
                height: 64,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_profileTabs[i], style: TextStyle(
                      color: active ? FT.gold : Colors.white60,
                      fontSize: 13,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    )),
                    const SizedBox(height: 14),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      height: 3,
                      width: active ? 48 : 0,
                      decoration: BoxDecoration(color: FT.gold, borderRadius: BorderRadius.circular(4)),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _sectionHeading(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Text(text, style: const TextStyle(
      color: FT.ivory, fontSize: 25, height: 1.15,
      fontWeight: FontWeight.w800, fontFamily: 'serif',
    )),
  );

  Widget _glanceCard(IconData icon, String label) {
    return Container(
      height: 105,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF101416),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: FT.gold, size: 25),
          const SizedBox(height: 12),
          Text(label, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
        ]),
      );
  }

  Widget _highlightCard(String value, int index) {
    const icons = [
      Icons.spa_outlined, Icons.pool_outlined, Icons.restaurant_outlined,
      Icons.directions_car_outlined, Icons.wifi_outlined, Icons.star_outline_rounded,
    ];
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF101416),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(children: [
        Container(
          width: 58, height: 58,
          decoration: BoxDecoration(color: const Color(0xFF292316), borderRadius: BorderRadius.circular(17)),
          child: Icon(icons[index % icons.length], color: FT.gold, size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(child: Text(value, style: const TextStyle(
          color: FT.ivory, fontSize: 18, fontWeight: FontWeight.w800, fontFamily: 'serif',
        ))),
      ]),
    );
  }

  Widget _reviewCard(Map<String, dynamic> review, int index) {
    final rating = num.tryParse(review['rating']?.toString() ?? '')?.toDouble() ?? 0;
    final body = (review['body'] ?? '').toString().trim();
    final date = (review['created_at'] ?? '').toString().split('T').first;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF101416),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            radius: 21, backgroundColor: const Color(0xFF292316),
            child: Text(index.isEven ? 'G' : 'F',
              style: const TextStyle(color: FT.gold, fontSize: 18, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Verified guest', style: TextStyle(color: FT.ivory, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('★ ${rating.toStringAsFixed(1)}', style: const TextStyle(color: FT.gold, fontWeight: FontWeight.w700)),
          ])),
          if (date.isNotEmpty) Text(date, style: const TextStyle(color: Colors.white54, fontSize: 11)),
        ]),
        if (body.isNotEmpty) ...[
          const SizedBox(height: 17),
          Text(body, style: const TextStyle(color: FT.cream, fontSize: 15, height: 1.45, fontFamily: 'serif')),
        ],
      ]),
    );
  }

  Widget _locationBlock(Map<String, dynamic> business) {
    final place = [
      city(),
      if ((business['address'] ?? '').toString().trim().isNotEmpty) business['address'].toString().trim(),
    ].where((e) => e.isNotEmpty).join(', ');
    final hasCoords = business['lat'] != null && business['lng'] != null;
    return Container(
      height: 170,
      decoration: BoxDecoration(
        color: const Color(0xFF172025),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(children: [
        Positioned.fill(child: CustomPaint(painter: _MapLinesPainter())),
        const Center(child: Icon(Icons.location_on_outlined, color: FT.gold, size: 30)),
        Positioned(
          left: 14, right: 14, bottom: 14,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(color: const Color(0xFF090B0C), borderRadius: BorderRadius.circular(15)),
            child: Row(children: [
              Expanded(child: Text(place.isEmpty ? 'Location not provided' : place,
                maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: FT.ivory, fontWeight: FontWeight.w600))),
              if (hasCoords)
                TextButton(
                  onPressed: () => launchUrlValue(
                    'https://maps.google.com/?q=${business['lat']},${business['lng']}',
                  ),
                  child: const Text('Get directions'),
                ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _aboutContent(Map<String, dynamic> business, List<String> allHighlights) {
    final about = (business['about'] ?? '').toString().trim();
    final subtitle = (business['tagline'] ?? business['short_description'] ?? '').toString().trim();
    final glance = <Map<String, dynamic>>[];
    for (final item in allHighlights.take(3)) {
      glance.add({'icon': Icons.auto_awesome_outlined, 'label': item});
    }
    if (glance.length < 3 && isHotel && amenityFallback().contains('Lake view')) {
      glance.add({'icon': Icons.waves_outlined, 'label': 'Lake view'});
    }
    while (glance.length < 3) {
      const labels = ['FineTime selected', 'Great location', 'Guest favorite'];
      const icons = [Icons.star_outline, Icons.location_on_outlined, Icons.favorite_outline];
      glance.add({'icon': icons[glance.length], 'label': labels[glance.length]});
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 34, 22, 30),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (about.isNotEmpty || subtitle.isNotEmpty)
          Text(about.isNotEmpty ? about : subtitle, style: const TextStyle(
            color: FT.cream, fontSize: 17, height: 1.55, fontFamily: 'serif',
          )),
        const SizedBox(height: 34),
        _sectionHeading('At a glance'),
        Row(children: List.generate(3, (i) => Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i == 2 ? 0 : 10),
            child: _glanceCard(glance[i]['icon'] as IconData, glance[i]['label'].toString()),
          ),
        ))),
        const SizedBox(height: 34),
        _sectionHeading('Why FineTime loves it'),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
          decoration: BoxDecoration(
            color: const Color(0xFF2B190B),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: FT.gold.withValues(alpha: .24)),
          ),
          child: Text(
            (business['fine_time_note'] ?? business['tagline'] ??
              'A genuine sense of place, thoughtful hospitality, and the kind of detail that stays with you.').toString(),
            style: const TextStyle(color: FT.cream, fontSize: 16, height: 1.5,
              fontStyle: FontStyle.italic, fontFamily: 'serif'),
          ),
        ),
        const SizedBox(height: 34),
        _sectionHeading('Location'),
        _locationBlock(business),
      ]),
    );
  }

  Widget _highlightsContent(List<String> allHighlights) {
    final items = allHighlights.isEmpty
      ? ['FineTime verified hospitality', 'Thoughtful guest service', 'Local experiences']
      : allHighlights;
    return Padding(
      padding: const EdgeInsets.fromLTRB(34, 38, 34, 30),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionHeading('Signature highlights'),
        ...items.asMap().entries.map((e) => _highlightCard(e.value, e.key)),
      ]),
    );
  }

  Widget _galleryContent(List<String> gallery) {
    if (gallery.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(34),
        child: Text('Gallery photos will appear here when this business adds them.',
          style: TextStyle(color: Colors.white60, fontSize: 15)),
      );
    }
    final first = gallery.first;
    final rest = gallery.skip(1).take(4).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(34, 38, 34, 30),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionHeading('A closer look'),
        SizedBox(
          height: 430,
          child: Row(children: [
            Expanded(flex: 2, child: image(first, height: 430, width: double.infinity)),
            const SizedBox(width: 10),
            Expanded(child: Column(children: List.generate(2, (i) => Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: i == 1 ? 0 : 10),
                child: rest.length > i
                  ? image(rest[i], height: double.infinity, width: double.infinity)
                  : Container(
                      decoration: BoxDecoration(color: const Color(0xFF101416), borderRadius: BorderRadius.circular(18)),
                    ),
              ),
            )))),
          ]),
        ),
        if (rest.length > 2) ...[
          const SizedBox(height: 10),
          Row(children: rest.skip(2).take(2).map((url) => Expanded(
            child: Padding(padding: const EdgeInsets.only(right: 10),
              child: image(url, height: 210, width: double.infinity)),
          )).toList()),
        ],
      ]),
    );
  }

  Widget _hoursContent(Map<String, dynamic> hours, Map<String, dynamic> business) {
    final entries = hours.entries.toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(34, 38, 34, 30),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionHeading('Opening hours'),
        if (entries.isEmpty)
          const Text('Opening hours have not been added yet.',
            style: TextStyle(color: Colors.white60, fontSize: 15))
        else
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF101416),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(children: entries.map((entry) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
              child: Row(children: [
                Expanded(child: Text(entry.key.replaceAll('_', ' ').toUpperCase(),
                  style: const TextStyle(color: FT.ivory, fontSize: 12, fontWeight: FontWeight.w700))),
                Flexible(child: Text(entry.value.toString(), textAlign: TextAlign.right,
                  style: const TextStyle(color: Colors.white70))),
              ]),
            )).toList()),
          ),
        const SizedBox(height: 34),
        _sectionHeading('Contact'),
        if ((business['phone'] ?? '').toString().trim().isNotEmpty)
          infoCard(Icons.call_outlined, 'Phone', business['phone'].toString()),
        if ((business['address'] ?? '').toString().trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          infoCard(Icons.location_on_outlined, 'Address', business['address'].toString()),
        ],
      ]),
    );
  }

  Widget _reviewsContent() {
    final ratings = reviews.map((r) => num.tryParse(r['rating']?.toString() ?? ''))
      .whereType<num>().map((n) => n.toDouble()).toList();
    final average = ratings.isEmpty ? 0.0 : ratings.reduce((a, b) => a + b) / ratings.length;
    final counts = <int, int>{for (final n in [5, 4, 3, 2, 1]) n: 0};
    for (final rating in ratings) {
      final rounded = rating.round().clamp(1, 5);
      counts[rounded] = (counts[rounded] ?? 0) + 1;
    }
    final maxCount = counts.values.fold<int>(1, (a, b) => a > b ? a : b);

    return Padding(
      padding: const EdgeInsets.fromLTRB(34, 38, 34, 30),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(ratings.isEmpty ? '—' : average.toStringAsFixed(1),
              style: const TextStyle(color: FT.ivory, fontSize: 58, height: .95,
                fontWeight: FontWeight.w500, fontFamily: 'serif')),
            const SizedBox(height: 10),
            Text('★ ${average.toStringAsFixed(1)}',
              style: const TextStyle(color: FT.gold, fontWeight: FontWeight.w700)),
            const SizedBox(height: 18),
            Text('${reviews.length} verified review${reviews.length == 1 ? '' : 's'}',
              style: const TextStyle(color: Colors.white54)),
          ]),
          const SizedBox(width: 34),
          Expanded(child: Column(children: [5, 4, 3, 2, 1].map((star) {
            final count = counts[star] ?? 0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                SizedBox(width: 14, child: Text('$star', style: const TextStyle(color: Colors.white70, fontSize: 12))),
                const SizedBox(width: 8),
                Expanded(child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: count / maxCount,
                    minHeight: 5,
                    backgroundColor: const Color(0xFF1C2528),
                    valueColor: const AlwaysStoppedAnimation<Color>(FT.gold),
                  ),
                )),
              ]),
            );
          }).toList())),
        ]),
        const SizedBox(height: 42),
        _sectionHeading('Guest stories'),
        if (reviews.isEmpty)
          const Text('No reviews yet. Be the first guest to share your experience.',
            style: TextStyle(color: Colors.white60, fontSize: 15))
        else
          ...reviews.asMap().entries.map((e) => _reviewCard(e.value, e.key)),
        if (reviewEligible) ...[
          const SizedBox(height: 4),
          SizedBox(width: double.infinity, child: OutlinedButton(
            onPressed: openReview,
            style: OutlinedButton.styleFrom(foregroundColor: FT.ivory, side: const BorderSide(color: FT.gold),
              padding: const EdgeInsets.symmetric(vertical: 15)),
            child: const Text('Write a review'),
          )),
        ],
      ]),
    );
  }

  Widget _profileHero(Map<String, dynamic> business, double? average) {
    final cover = business['cover_url']?.toString().trim() ?? '';
    final gallery = strings(business['gallery_urls']);
    final heroUrl = cover.isNotEmpty ? cover : (gallery.isNotEmpty ? gallery.first : '');
    final name = (business['name'] ?? 'FineTime place').toString();
    final place = [
      city(),
      if ((business['address'] ?? '').toString().trim().isNotEmpty) business['address'].toString().trim(),
    ].where((e) => e.isNotEmpty).join(', ');
    return SizedBox(
      height: 420,
      child: Stack(children: [
        Positioned.fill(
          child: heroUrl.isNotEmpty
            ? image(heroUrl, height: 420, width: double.infinity)
            : Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF30474A), Color(0xFF090B0C)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Center(
              child: Text(
                name.isEmpty ? 'F' : name.trim()[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white10,
                  fontSize: 150,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'serif',
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(child: IgnorePointer(child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: .28), Colors.transparent,
                const Color(0xFF090B0C).withValues(alpha: .88), const Color(0xFF090B0C),
              ],
              stops: const [0, .38, .78, 1],
            ),
          ),
        ))),
        Positioned(
          top: 0, left: 0, right: 0,
          child: SafeArea(bottom: false, child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: Row(children: [
            _heroIconButton(Icons.arrow_back_ios_new_rounded, () => Navigator.pop(context)),
            const Spacer(),
            if (hasFood) _heroIconButton(Icons.qr_code_2_rounded, showQr),
            const SizedBox(width: 10),
            _heroIconButton(saved ? Icons.favorite_rounded : Icons.favorite_border_rounded, toggleSave, active: saved),
            ]),
          )),
        ),
        Positioned(
          left: 24, right: 24, bottom: 24,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text((business['category'] ?? 'hospitality').toString().toUpperCase(),
              style: const TextStyle(color: FT.gold, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 2.5)),
            const SizedBox(height: 9),
            Text(business['name'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: FT.ivory, fontSize: 36, height: 1, fontWeight: FontWeight.w500, fontFamily: 'serif')),
            const SizedBox(height: 12),
            Row(children: [
              const Icon(Icons.star, color: FT.gold, size: 18),
              const SizedBox(width: 5),
              Text(average == null ? 'New' : average.toStringAsFixed(1),
                style: const TextStyle(color: FT.ivory, fontWeight: FontWeight.w700)),
              if (average != null) ...[
                const SizedBox(width: 4),
                Text('(${reviews.length} reviews)', style: const TextStyle(color: Colors.white60, fontSize: 12)),
              ],
              const Spacer(),
              if (place.isNotEmpty) ...[
                const Icon(Icons.location_on_outlined, color: Colors.white70, size: 17),
                const SizedBox(width: 4),
                Flexible(child: Text(place, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right,
                  style: const TextStyle(color: Colors.white70, fontSize: 12))),
              ],
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _heroIconButton(IconData icon, VoidCallback action, {bool active = false}) {
    return Material(
      color: const Color(0xFF090B0C).withValues(alpha: .78),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: action,
        customBorder: const CircleBorder(),
        child: SizedBox(width: 48, height: 48,
          child: Icon(icon, color: active ? FT.gold : FT.ivory, size: 22)),
      ),
    );
  }

  Widget _bottomBookingBar(Map<String, dynamic> business) {
    final price = isHotel && rooms.isNotEmpty ? rooms.first['public_price'] : null;
    final priceText = price == null ? (isHotel ? 'Rate on request' : 'Reserve your experience') : 'ETB $price / night';
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 11, 18, 11),
        decoration: const BoxDecoration(
          color: Color(0xFF080D0E),
          border: Border(top: BorderSide(color: Colors.white10)),
        ),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('From', style: TextStyle(color: Colors.white54, fontSize: 11)),
            const SizedBox(height: 3),
            Text(priceText, style: const TextStyle(color: FT.gold, fontSize: 16, fontWeight: FontWeight.w800)),
          ])),
          SizedBox(
            height: 58, width: 205,
            child: FilledButton(
              onPressed: openBooking,
              style: FilledButton.styleFrom(
                backgroundColor: FT.gold,
                foregroundColor: const Color(0xFF17120A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
              ),
              child: Text(isHotel ? 'Book now →' : 'Reserve now →',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            ),
          ),
        ]),
      ),
    );
  }

  List<String> amenityFallback() => strings(b?['amenities']);


  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Scaffold(
        backgroundColor: const Color(0xFF090B0C),
        body: Center(child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: load, child: const Text('Retry')),
          ]),
        )),
      );
    }

    final business = b;
    if (business == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF090B0C),
        body: Center(child: CircularProgressIndicator(color: FT.gold)),
      );
    }

    final highlights = strings(business['highlights']);
    final services = strings(business['services']);
    final amenities = strings(business['amenities']);
    final gallery = strings(business['gallery_urls']);
    final hours = asMap(business['opening_hours']);
    final allHighlights = {...highlights, ...services, if (isHotel) ...amenities}.toList();

    final ratings = reviews.map((r) => num.tryParse(r['rating']?.toString() ?? ''))
      .whereType<num>().map((n) => n.toDouble()).toList();
    final average = ratings.isEmpty ? null : ratings.reduce((a, b) => a + b) / ratings.length;

    return Scaffold(
      backgroundColor: const Color(0xFF090B0C),
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.only(bottom: 105),
              children: [
                _profileHero(business, average),
                _profileTabBar(),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: KeyedSubtree(
                    key: ValueKey(_profileTab),
                    child: switch (_profileTab) {
                      0 => _aboutContent(business, allHighlights),
                      1 => _highlightsContent(allHighlights),
                      2 => _galleryContent(gallery),
                      3 => _hoursContent(hours, business),
                      4 => _reviewsContent(),
                      _ => _aboutContent(business, allHighlights),
                    },
                  ),
                ),
              ],
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _bottomBookingBar(business),
            ),
          ],
        ),
      ),
    );
  }




}

class _MapLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: .08)..strokeWidth = 2;
    final path1 = Path()
      ..moveTo(-20, size.height * .72)
      ..lineTo(size.width * .2, size.height * .5)
      ..lineTo(size.width * .52, size.height * .62)
      ..lineTo(size.width + 20, size.height * .2);
    final path2 = Path()
      ..moveTo(-10, size.height * .28)
      ..lineTo(size.width * .35, size.height * .48)
      ..lineTo(size.width * .72, size.height * .34)
      ..lineTo(size.width + 10, size.height * .52);
    final path3 = Path()
      ..moveTo(size.width * .42, -10)
      ..lineTo(size.width * .48, size.height * .38)
      ..lineTo(size.width * .4, size.height + 10);
    canvas.drawPath(path1, paint);
    canvas.drawPath(path2, paint);
    canvas.drawPath(path3, paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
