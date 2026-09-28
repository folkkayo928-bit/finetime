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
  const BusinessProfileScreen({super.key, required this.businessId});

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

  bool get isHotel => b?['category']?.toString().toLowerCase() == 'hotel';
  bool get hasFood => menu.isNotEmpty;

  @override
  void initState() {
    super.initState();
    load();
    checkSaved();
  }

  List<String> strings(dynamic value) {
    if (value is List) {
      return value.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
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

  String city() => ((b?['cities'] as Map<String, dynamic>?)?['name'] ?? '').toString();

  Future<void> checkSaved() async {
    final user = sb.auth.currentUser;
    if (user == null) return;
    try {
      final row = await sb.from('saved_places').select('business_id')
          .eq('user_id', user.id).eq('business_id', widget.businessId).maybeSingle();
      if (mounted) setState(() => saved = row != null);
    } catch (_) {}
  }

  Future<void> load() async {
    try {
      final result = await Net.run(() async {
        final business = await sb.from('businesses')
            .select('*, cities(name)')
            .eq('id', widget.businessId)
            .maybeSingle();
        if (business == null) return null;

        final roomRows = await sb.from('room_types')
            .select().eq('business_id', widget.businessId).order('name');
        final menuRows = await sb.from('menu_categories')
            .select('*, menu_items(*)').eq('business_id', widget.businessId).order('sort_order');
        final reviewRows = await sb.from('reviews')
            .select('rating,body,created_at').eq('business_id', widget.businessId)
            .order('created_at', ascending: false);
        final promoRows = await sb.from('promotions')
            .select('id,title,description,badge,image_url,terms,starts_on,ends_on,status')
            .eq('business_id', widget.businessId).eq('status', 'active')
            .order('starts_on', ascending: true);
        return (business, roomRows, menuRows, reviewRows, promoRows);
      });

      if (result == null) {
        if (mounted) setState(() => error = 'This business is not available.');
        return;
      }
      if (mounted) {
        setState(() {
          b = Map<String, dynamic>.from(result.$1);
          rooms = List<Map<String, dynamic>>.from(result.$2);
          menu = List<Map<String, dynamic>>.from(result.$3);
          reviews = List<Map<String, dynamic>>.from(result.$4);
          promotions = List<Map<String, dynamic>>.from(result.$5);
        });
      }
      await checkReviewEligibility();
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
    final uri = Uri.parse(value);
    if (await launcher.canLaunchUrl(uri)) await launcher.launchUrl(uri);
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
    final url = 'https://finetime.cc/website/menu.html?id=' + Uri.encodeComponent(id);
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
    if (value.isEmpty) {
      return Container(
        height: height, width: width,
        decoration: BoxDecoration(color: const Color(0xFF1B1B1B), borderRadius: BorderRadius.circular(18)),
        child: const Icon(Icons.image_outlined, color: Colors.white24, size: 42),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Image.network(value, height: height, width: width, fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          height: height, width: width, color: const Color(0xFF1B1B1B),
          child: const Icon(Icons.image_outlined, color: Colors.white24, size: 42),
        ),
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
              (room['capacity'] ?? 0).toString() + ' guests' +
                  (room['beds'] == null ? '' : ' · ' + room['beds'].toString()),
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
              price == null ? 'Rate confirmed by hotel' : 'ETB ' + price.toString() + ' / night',
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
            Text(item['price'] == null ? '' : 'ETB ' + item['price'].toString(),
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
            Text('★ ' + rating.toString() + '.0', style: const TextStyle(color: FT.gold, fontWeight: FontWeight.w800)),
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
            b?['phone'] == null ? null : () => launchUrlValue('tel:' + b!['phone'].toString())),
          bottomAction(Icons.directions_outlined, 'Directions',
            b?['lat'] == null ? null : () => launchUrlValue(
              'https://maps.google.com/?q=' + b!['lat'].toString() + ',' + b!['lng'].toString())),
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
  Widget build(BuildContext context) {
    if (error != null) {
      return Scaffold(appBar: AppBar(), body: Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(error!, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(onPressed: load, child: const Text('Retry')),
        ]),
      )));
    }

    final business = b;
    if (business == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final highlights = strings(business['highlights']);
    final services = strings(business['services']);
    final amenities = strings(business['amenities']);
    final gallery = strings(business['gallery_urls']);
    final hours = asMap(business['opening_hours']);

    final ratings = reviews
        .map((r) => num.tryParse(r['rating']?.toString() ?? ''))
        .whereType<num>().toList();
    final average = ratings.isEmpty ? null : ratings.reduce((a, c) => a + c) / ratings.length;
    final subtitle = (business['tagline'] ?? business['short_description'] ?? business['about'] ?? '').toString().trim();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('FineTime'),
        actions: [
          if (hasFood) IconButton(icon: const Icon(Icons.qr_code_2), onPressed: showQr, tooltip: 'Show QR menu'),
          IconButton(
            icon: Icon(saved ? Icons.favorite : Icons.favorite_border, color: saved ? FT.gold : FT.ivory),
            onPressed: toggleSave,
            tooltip: saved ? 'Remove from saved' : 'Save place',
          ),
        ],
      ),
      bottomNavigationBar: bottomActions(),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Stack(children: [
            image(business['cover_url']?.toString(), height: 290, width: double.infinity),
            Positioned.fill(child: IgnorePointer(child: DecoratedBox(
              decoration: BoxDecoration(gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Colors.black.withValues(alpha: .12), Colors.black.withValues(alpha: .9)],
              )),
            ))),
          ]),
          Transform.translate(
            offset: const Offset(0, -28),
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              decoration: const BoxDecoration(
                color: FT.charcoal,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(business['name'] ?? '', style: const TextStyle(fontSize: 29, height: 1.05, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, runSpacing: 7, children: [
                  FT.badge((business['category'] ?? 'hospitality').toString().replaceAll('_', ' ').toUpperCase()),
                  if (average != null) Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.star, color: FT.gold, size: 19),
                    const SizedBox(width: 4),
                    Text(average.toStringAsFixed(1) + ' · ' + ratings.length.toString() +
                      ' review' + (ratings.length == 1 ? '' : 's'),
                      style: const TextStyle(color: Colors.white70)),
                  ]),
                ]),
                if (subtitle.isNotEmpty) Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.35)),
                ),
                const SizedBox(height: 18),
                Wrap(spacing: 10, runSpacing: 10, children: [
                  FilledButton.icon(
                    onPressed: business['lat'] == null ? null : () => launchUrlValue(
                      'https://maps.google.com/?q=' + business['lat'].toString() + ',' + business['lng'].toString()),
                    icon: const Icon(Icons.location_on_outlined),
                    label: const Text('Get directions'),
                  ),
                  OutlinedButton.icon(
                    onPressed: business['phone'] == null ? null : () => launchUrlValue('tel:' + business['phone'].toString()),
                    icon: const Icon(Icons.call_outlined),
                    label: const Text('Call'),
                    style: OutlinedButton.styleFrom(foregroundColor: FT.ivory, side: const BorderSide(color: FT.gold)),
                  ),
                  if (hasFood) OutlinedButton.icon(
                    onPressed: openMenu,
                    icon: const Icon(Icons.restaurant_menu_outlined),
                    label: const Text('View digital menu'),
                    style: OutlinedButton.styleFrom(foregroundColor: FT.ivory, side: const BorderSide(color: Colors.white24)),
                  ),
                ]),
                const SizedBox(height: 30),

                if ((business['about'] ?? '').toString().trim().isNotEmpty) ...[
                  title('About'),
                  const SizedBox(height: 10),
                  Text(business['about'].toString(),
                    style: const TextStyle(color: Colors.white70, height: 1.55, fontSize: 15)),
                  const SizedBox(height: 26),
                ],

                if (highlights.isNotEmpty || services.isNotEmpty || (isHotel && amenities.isNotEmpty)) ...[
                  title('Highlights & services'),
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    ...highlights.map(pill),
                    ...services.map(pill),
                    if (isHotel) ...amenities.map(pill),
                  ]),
                  const SizedBox(height: 28),
                ],

                if (gallery.isNotEmpty) ...[
                  title('Gallery'),
                  const SizedBox(height: 12),
                  SizedBox(height: 190, child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: gallery.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (_, i) => image(gallery[i], height: 190, width: 290),
                  )),
                  const SizedBox(height: 28),
                ],

                if (hours.isNotEmpty) ...[
                  infoCard(Icons.access_time, 'Opening hours',
                    hours.entries.map((e) => e.key + ': ' + e.value.toString()).join('\n')),
                  const SizedBox(height: 12),
                ],
                infoCard(
                  Icons.location_on_outlined,
                  'Location',
                  [city(), if ((business['address'] ?? '').toString().trim().isNotEmpty) business['address'].toString().trim()]
                      .where((e) => e.isNotEmpty).join(', ').isEmpty
                    ? 'Location not provided'
                    : [city(), if ((business['address'] ?? '').toString().trim().isNotEmpty) business['address'].toString().trim()]
                        .where((e) => e.isNotEmpty).join(', '),
                ),
                const SizedBox(height: 28),

                if (isHotel && rooms.isNotEmpty) ...[
                  title('Stay · Rooms'),
                  const SizedBox(height: 12),
                  ...rooms.map(roomCard),
                  const SizedBox(height: 16),
                ],

                if (hasFood) ...[
                  title('Dine · Menu', action: 'Order', onAction: openMenu),
                  const SizedBox(height: 12),
                  ...menu.map(menuCategory),
                  const SizedBox(height: 16),
                ],

                if (promotions.isNotEmpty) ...[
                  title('Promotions'),
                  const SizedBox(height: 12),
                  ...promotions.map((p) => Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    clipBehavior: Clip.antiAlias,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      if ((p['image_url'] ?? '').toString().isNotEmpty)
                        image(p['image_url'].toString(), height: 150, width: double.infinity),
                      Padding(padding: const EdgeInsets.all(14), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        if ((p['badge'] ?? '').toString().isNotEmpty)
                          Padding(padding: const EdgeInsets.only(right: 10), child: FT.badge(p['badge'].toString())),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(p['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w800)),
                          if ((p['description'] ?? '').toString().isNotEmpty)
                            Padding(padding: const EdgeInsets.only(top: 5),
                              child: Text(p['description'].toString(), style: const TextStyle(color: Colors.white70))),
                        ])),
                      ])),
                    ]),
                  )),
                  const SizedBox(height: 16),
                ],

                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF151515),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    title('Reviews'),
                    const SizedBox(height: 12),
                    Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(average == null ? '—' : average.toStringAsFixed(1),
                        style: const TextStyle(fontSize: 38, height: 1, fontWeight: FontWeight.w800)),
                      const SizedBox(width: 16),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: List.generate(5, (i) => Icon(
                          i < (average?.round() ?? 0) ? Icons.star : Icons.star_border,
                          color: FT.gold, size: 19))),
                        const SizedBox(height: 5),
                        Text(reviews.length.toString() + ' review' + (reviews.length == 1 ? '' : 's'),
                          style: const TextStyle(color: Colors.white54)),
                      ]),
                      const Spacer(),
                      if (reviews.isNotEmpty)
                        TextButton(onPressed: showAllReviews, child: const Text('View all reviews ›')),
                    ]),
                    if (reviews.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      const Divider(),
                      const SizedBox(height: 8),
                      ...reviews.take(3).map(reviewTile),
                    ],
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: openReview,
                      icon: Icon(reviewEligible ? Icons.rate_review_outlined : Icons.lock_outline),
                      label: Text(reviewEligible ? 'Write a review' : 'Review after a completed experience'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: reviewEligible ? FT.ivory : Colors.white54,
                        side: BorderSide(color: reviewEligible ? FT.gold : Colors.white12),
                      ),
                    ),
                  ]),
                ),

                if (hasFood) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
                    decoration: BoxDecoration(
                      color: const Color(0xFF17130A),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: FT.gold.withValues(alpha: .35)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.qr_code_2, color: FT.gold, size: 22),
                      const SizedBox(width: 12),
                      const Expanded(child: Text(
                        'Scan the QR code at your table to view the full digital menu and place an order.',
                        style: TextStyle(color: Colors.white70, height: 1.35))),
                      IconButton(onPressed: showQr, icon: const Icon(Icons.open_in_new, color: FT.gold)),
                    ]),
                  ),
                ],
                const SizedBox(height: 24),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
