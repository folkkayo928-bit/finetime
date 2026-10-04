import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';
import 'business_profile.dart';
import 'explore.dart';
import 'search.dart';
import 'guest_reviews.dart';
import '../net.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});
  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final sb = Supabase.instance.client;
  List<Map<String, dynamic>> _featured = [];
  List<Map<String, dynamic>> _promos = [];
  Map<String, dynamic>? _heroModule;
  RealtimeChannel? _realtime;

  final Set<String> _savedIds = {};

  // Curated fallbacks matching Figma design when database has few items
  static const _defaultBuildingHero =
      'https://images.unsplash.com/photo-1542314831-068cd1dbfeeb?auto=format&fit=crop&w=1200&q=80';
  static const _defaultCoffeeStory =
      'https://images.unsplash.com/photo-1514432324607-a09d9b4aefdd?auto=format&fit=crop&w=1200&q=80';

  static const List<Map<String, dynamic>> _curatedFeatured = [
    {
      'id': 'curated_kuriftu',
      'name': 'Kuriftu Resort',
      'category': 'Hotel',
      'city': 'Bishoftu, Ethiopia',
      'price': '\$148',
      'unit': '/ night',
      'rating': '4.9',
      'tag': 'Lake view',
      'image':
          'https://images.unsplash.com/photo-1582719478250-c89cae4dc85b?auto=format&fit=crop&w=800&q=80',
    },
    {
      'id': 'curated_skylight',
      'name': 'Skylight Suites',
      'category': 'Hotel',
      'city': 'Bole, Addis Ababa',
      'price': '\$120',
      'unit': '/ night',
      'rating': '4.8',
      'tag': 'Poolside',
      'image':
          'https://images.unsplash.com/photo-1571896349842-33c89424de2d?auto=format&fit=crop&w=800&q=80',
    },
    {
      'id': 'curated_hyatt',
      'name': 'Hyatt Regency',
      'category': 'Hotel',
      'city': 'Meskel Square, Addis',
      'price': '\$195',
      'unit': '/ night',
      'rating': '4.9',
      'tag': 'City view',
      'image':
          'https://images.unsplash.com/photo-1566073771259-6a8506099945?auto=format&fit=crop&w=800&q=80',
    },
  ];

  static const List<Map<String, dynamic>> _curatedOffers = [
    {
      'badge': 'STAY 3, PAY 2',
      'title': 'A longer lakeside escape',
      'subtitle': 'Save 33% at Kuriftu Resort',
      'image':
          'https://images.unsplash.com/photo-1582719478250-c89cae4dc85b?auto=format&fit=crop&w=800&q=80',
    },
    {
      'badge': 'DINNER FOR TWO',
      'title': 'A taste of heritage',
      'subtitle': "Complimentary chef's selection",
      'image':
          'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&w=800&q=80',
    },
  ];

  @override
  void initState() {
    super.initState();
    _load();
    _subscribeToUpdates();
  }

  void _subscribeToUpdates() {
    _realtime = sb.channel('discover-live')
      ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'businesses',
          callback: (_) => _load())
      ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'promotions',
          callback: (_) => _load())
      ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'site_modules',
          callback: (_) => _load())
      ..subscribe();
  }

  Future<void> _load() async {
    try {
      final f = await Net.run(() => sb
          .from('businesses')
          .select('*, cities(name, region), room_types(name, public_price)')
          .eq('is_published', true)
          .limit(10));

      final p = await Net.run(() => sb
          .from('promotions')
          .select('*, businesses(name)')
          .eq('status', 'active')
          .order('starts_on', ascending: true));

      // Fetch dynamic hero header module configured from admin console
      final h = await Net.run(() => sb
          .from('site_modules')
          .select()
          .eq('placement', 'app_hero')
          .eq('is_enabled', true)
          .order('sort_order', ascending: true)
          .limit(1));

      if (mounted) {
        setState(() {
          _featured = List<Map<String, dynamic>>.from(f);
          _promos = List<Map<String, dynamic>>.from(p);
          _heroModule = h.isNotEmpty ? Map<String, dynamic>.from(h.first) : null;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    if (_realtime != null) sb.removeChannel(_realtime!);
    super.dispose();
  }

  void _openJourneyService(String title, String description, IconData icon) {
    showModalBottomSheet(
      context: context,
      backgroundColor: FT.obsidian,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: FT.gold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: FT.gold, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              color: FT.ivory,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'serif')),
                      const SizedBox(height: 3),
                      Text(description,
                          style: const TextStyle(color: FT.muted, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF16130E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF262017)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('FineTime Concierge Dispatch',
                      style: TextStyle(
                          color: FT.ivory,
                          fontWeight: FontWeight.w700,
                          fontSize: 15)),
                  SizedBox(height: 6),
                  Text(
                    'Direct hotel transfers, verified airport taxis, and intercity transit are curated exclusively for FineTime guests.',
                    style: TextStyle(color: FT.cream, fontSize: 13.5, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Connect with FineTime Concierge'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCoffeeStory() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: FT.obsidian,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollCtrl) => ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(_defaultCoffeeStory,
                  height: 200, width: double.infinity, fit: BoxFit.cover),
            ),
            const SizedBox(height: 18),
            const Text('A RITUAL OF WELCOME',
                style: TextStyle(
                    color: FT.gold,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.0)),
            const SizedBox(height: 6),
            const Text('The Ethiopian Coffee Ceremony',
                style: TextStyle(
                    color: FT.ivory,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'serif')),
            const SizedBox(height: 14),
            const Text(
              'Known locally as "Buna", the coffee ceremony is an ancient, deeply hospitable tradition honoring visitors. Fresh green beans are roasted over glowing coals, ground by hand, and brewed three times in a traditional clay pot (jebena): Abol (the first brew), Tona (the second), and Baraka (the blessing).\n\nFineTime partners across Ethiopia welcome you to experience this timeless ceremony first-hand.',
              style: TextStyle(
                  color: Color(0xFFDDD8D0), fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            const ExploreScreen(initialCategory: 'cafe')));
              },
              child: const Text('Discover Heritage Cafés'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Dynamic hero values from Supabase admin or fallback
    final heroImage = (_heroModule?['image_url'] ?? '').toString().trim().isNotEmpty
        ? _heroModule!['image_url'].toString().trim()
        : _defaultBuildingHero;
    final heroBadge = (_heroModule?['cta_label'] ?? '').toString().trim().isNotEmpty
        ? _heroModule!['cta_label'].toString().trim().toUpperCase()
        : 'CURATED FOR YOU';
    final heroTitle = (_heroModule?['title'] ?? '').toString().trim().isNotEmpty
        ? _heroModule!['title'].toString().trim()
        : 'Your next\nEthiopian story';
    final heroSubtitle = (_heroModule?['body'] ?? '').toString().trim().isNotEmpty
        ? _heroModule!['body'].toString().trim()
        : 'Exceptional places, chosen with care.';

    return Scaffold(
      backgroundColor: const Color(0xFF0C0A06),
      body: RefreshIndicator(
        onRefresh: _load,
        color: FT.gold,
        backgroundColor: const Color(0xFF1C1914),
        child: ListView(
          padding: const EdgeInsets.only(bottom: 36),
          children: [
            // ---------------------------------------------------------------
            // 1. HERO HEADER WITH DYNAMIC BUILDING IMAGE & LUXURY GRADIENT
            // ---------------------------------------------------------------
            Stack(
              children: [
                // Background Building Image
                SizedBox(
                  height: 430,
                  width: double.infinity,
                  child: FTImage(
                    url: heroImage,
                    fit: BoxFit.cover,
                  ),
                ),

                // Multi-Stop Obsidian Vignette Overlay
                Container(
                  height: 420,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.45),
                        Colors.transparent,
                        const Color(0xFF0C0A06).withValues(alpha: 0.8),
                        const Color(0xFF0C0A06),
                      ],
                      stops: const [0.0, 0.35, 0.75, 1.0],
                    ),
                  ),
                ),

                // Header Content
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),

                        // Logo bar matching Figma: [F] FineTime.cc
                        Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFE3A82D), Color(0xFFC99220)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: const Text(
                                'F',
                                style: TextStyle(
                                  color: Color(0xFF14110C),
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900,
                                  fontStyle: FontStyle.italic,
                                  fontFamily: 'serif',
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            RichText(
                              text: const TextSpan(
                                children: [
                                  TextSpan(
                                    text: 'FineTime',
                                    style: TextStyle(
                                      color: FT.ivory,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  TextSpan(
                                    text: '.cc',
                                    style: TextStyle(
                                      color: Color(0xFFE3A82D),
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 80),

                        // Badge: CURATED FOR YOU
                        Text(
                          heroBadge,
                          style: const TextStyle(
                            color: Color(0xFFE3A82D),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2.2,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Title: Your next Ethiopian story
                        Text(
                          heroTitle,
                          style: const TextStyle(
                            color: FT.ivory,
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'serif',
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Subtitle
                        Text(
                          heroSubtitle,
                          style: const TextStyle(
                            color: Color(0xFFDDD8D0),
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Modern Pill Search Bar
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const SearchScreen()),
                          ),
                          child: Container(
                            height: 52,
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            decoration: BoxDecoration(
                              color: const Color(0xFF14120E).withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(26),
                              border: Border.all(
                                  color: const Color(0xFF2C261F), width: 1),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.search,
                                    color: Color(0xFF8E8982), size: 21),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Search hotels, restaurants, cafés...',
                                    style: TextStyle(
                                      color: Color(0xFF8E8982),
                                      fontSize: 14,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Icon(Icons.tune_rounded,
                                    color: Color(0xFF8E8982), size: 20),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // ---------------------------------------------------------------
            // 2. CATEGORY PILLS (5 ICONS: Hotels, Restaurants, Cafés, Experiences, Nearby)
            // ---------------------------------------------------------------
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _categoryButton(
                      'Hotels', Icons.apartment_rounded, 'hotel'),
                  _categoryButton(
                      'Restaurants', Icons.restaurant_rounded, 'restaurant'),
                  _categoryButton(
                      'Cafés', Icons.coffee_rounded, 'cafe'),
                  _categoryButton(
                      'Experiences', Icons.auto_awesome_rounded, 'experience'),
                  _categoryButton(
                      'Nearby', Icons.near_me_rounded, 'nearby'),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // ---------------------------------------------------------------
            // 3. "Featured for you" CAROUSEL
            // ---------------------------------------------------------------
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  const Text(
                    'Featured for you',
                    style: TextStyle(
                      color: FT.ivory,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'serif',
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const GuestReviewsScreen())),
                    child: const Text(
                      'View all >',
                      style: TextStyle(
                        color: Color(0xFFE3A82D),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            SizedBox(
              height: 225,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _featured.isNotEmpty
                    ? _featured.length
                    : _curatedFeatured.length,
                itemBuilder: (ctx, i) {
                  if (_featured.isNotEmpty) {
                    final b = _featured[i];
                    return _liveFeaturedCard(b);
                  } else {
                    final item = _curatedFeatured[i];
                    return _curatedFeaturedCard(item);
                  }
                },
              ),
            ),

            const SizedBox(height: 32),

            // ---------------------------------------------------------------
            // 4. "Special offers" CAROUSEL
            // ---------------------------------------------------------------
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  const Text(
                    'Special offers',
                    style: TextStyle(
                      color: FT.ivory,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'serif',
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const GuestReviewsScreen())),
                    child: const Text(
                      'See all >',
                      style: TextStyle(
                        color: Color(0xFFE3A82D),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            SizedBox(
              height: 154,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _promos.isNotEmpty
                    ? _promos.length
                    : _curatedOffers.length,
                itemBuilder: (ctx, i) {
                  if (_promos.isNotEmpty) {
                    return _livePromoCard(_promos[i]);
                  } else {
                    return _curatedPromoCard(_curatedOffers[i]);
                  }
                },
              ),
            ),

            const SizedBox(height: 32),

            // ---------------------------------------------------------------
            // 5. STORY BANNER: "A RITUAL OF WELCOME" - ETHIOPIAN COFFEE CEREMONY
            // ---------------------------------------------------------------
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GestureDetector(
                onTap: _showCoffeeStory,
                child: Container(
                  height: 174,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFF262017), width: 1),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Stack(
                      children: [
                        // Coffee image
                        Positioned.fill(
                          child: Image.network(
                            _defaultCoffeeStory,
                            fit: BoxFit.cover,
                          ),
                        ),
                        // Dark Vignette
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  Colors.black.withValues(alpha: 0.88),
                                  Colors.black.withValues(alpha: 0.55),
                                  Colors.black.withValues(alpha: 0.25),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Content
                        Padding(
                          padding: const EdgeInsets.all(22),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              const Text(
                                'A RITUAL OF WELCOME',
                                style: TextStyle(
                                  color: Color(0xFFE3A82D),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 2.0,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'The Ethiopian\ncoffee ceremony',
                                style: TextStyle(
                                  color: FT.ivory,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  fontFamily: 'serif',
                                  height: 1.15,
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Row(
                                children: [
                                  Text(
                                    'Discover the story →',
                                    style: TextStyle(
                                      color: Color(0xFFE3A82D),
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 34),

            // ---------------------------------------------------------------
            // 6. "Plan your journey" (Book a ride, Bus tickets, Guest reviews)
            // ---------------------------------------------------------------
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Plan your journey',
                style: TextStyle(
                  color: FT.ivory,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'serif',
                ),
              ),
            ),
            const SizedBox(height: 14),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _journeyTile(
                    'Book a ride',
                    'Safe city and airport taxis',
                    Icons.directions_car_rounded,
                    () => _openJourneyService(
                      'Book a Ride',
                      'Safe city and airport transfers across Addis Ababa & Bishoftu.',
                      Icons.directions_car_rounded,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _journeyTile(
                    'Bus tickets',
                    'Travel city to city',
                    Icons.directions_bus_rounded,
                    () => _openJourneyService(
                      'Bus Tickets & Intercity',
                      'Reliable express bus services between Ethiopian travel destinations.',
                      Icons.directions_bus_rounded,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _journeyTile(
                    'Guest reviews',
                    'See all hotel and dining reviews',
                    Icons.chat_bubble_outline_rounded,
                    () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const GuestReviewsScreen())),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HELPER WIDGETS
  // ---------------------------------------------------------------------------

  Widget _categoryButton(String label, IconData icon, String categoryKey) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ExploreScreen(initialCategory: categoryKey),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFF181510),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF282218), width: 1),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: const Color(0xFFE3A82D), size: 24),
          ),
          const SizedBox(height: 7),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFDDD8D0),
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _curatedFeaturedCard(Map<String, dynamic> item) {
    final id = item['id'].toString();
    final isSaved = _savedIds.contains(id);

    return Container(
      width: 204,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF15120D),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF262017), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Stack(
              children: [
                SizedBox(
                  height: 122,
                  width: double.infinity,
                  child: Image.network(item['image'], fit: BoxFit.cover),
                ),
                Positioned(
                  bottom: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      item['category'],
                      style: const TextStyle(
                        color: FT.ivory,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isSaved) {
                          _savedIds.remove(id);
                        } else {
                          _savedIds.add(id);
                        }
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isSaved ? Icons.favorite : Icons.favorite_border,
                        color: const Color(0xFFE3A82D),
                        size: 19,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        item['name'],
                        style: const TextStyle(
                          color: FT.ivory,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'serif',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.star,
                            color: Color(0xFFE3A82D), size: 14),
                        const SizedBox(width: 3),
                        Text(
                          item['rating'],
                          style: const TextStyle(
                            color: Color(0xFFE3A82D),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined,
                        color: Color(0xFF8E8982), size: 13),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        item['city'],
                        style: const TextStyle(
                          color: Color(0xFF8E8982),
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: item['price'],
                            style: const TextStyle(
                              color: Color(0xFFE3A82D),
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          TextSpan(
                            text: ' ${item['unit']}',
                            style: const TextStyle(
                              color: Color(0xFF756F67),
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      item['tag'],
                      style: const TextStyle(
                        color: Color(0xFF756F67),
                        fontSize: 11.5,
                      ),
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

  Widget _liveFeaturedCard(Map<String, dynamic> b) {
    final id = b['id'].toString();
    final isSaved = _savedIds.contains(id);
    final cover = (b['cover_url'] ?? '').toString();
    final cat = (b['category'] ?? 'Hotel').toString().toUpperCase();
    final cityName = b['cities']?['name'] ?? 'Addis Ababa';

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => BusinessProfileScreen(
              businessId: b['id'].toString(),
              initialBusiness: Map<String, dynamic>.from(b),
            )),
      ),
      child: Container(
        width: 204,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF15120D),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF262017), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              child: Stack(
                children: [
                  SizedBox(
                    height: 122,
                    width: double.infinity,
                    child: FTImage(
                      url: cover.isNotEmpty ? cover : _defaultBuildingHero,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    bottom: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        cat,
                        style: const TextStyle(
                          color: FT.ivory,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isSaved) {
                            _savedIds.remove(id);
                          } else {
                            _savedIds.add(id);
                          }
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isSaved ? Icons.favorite : Icons.favorite_border,
                          color: const Color(0xFFE3A82D),
                          size: 19,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          b['name'] ?? 'FineTime Venue',
                          style: const TextStyle(
                            color: FT.ivory,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'serif',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Row(
                        children: [
                          Icon(Icons.star,
                              color: Color(0xFFE3A82D), size: 14),
                          SizedBox(width: 3),
                          Text(
                            '4.9',
                            style: TextStyle(
                              color: Color(0xFFE3A82D),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined,
                          color: Color(0xFF8E8982), size: 13),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          cityName,
                          style: const TextStyle(
                            color: Color(0xFF8E8982),
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Builder(
                        builder: (_) {
                          final rooms = b['room_types'] is List
                              ? List<Map<String, dynamic>>.from(b['room_types'])
                              : const <Map<String, dynamic>>[];
                          final price = rooms.isNotEmpty ? rooms.first['public_price'] : null;
                          final highlights = b['highlights'] is List ? List.from(b['highlights']) : const [];
                          final tag = highlights.isNotEmpty ? highlights.first.toString() : 'FineTime selection';
                          return Expanded(
                            child: Text(
                              price != null
                                  ? 'ETB ${price.toStringAsFixed(0)} / night'
                                  : tag,
                              style: const TextStyle(
                                color: Color(0xFFE3A82D),
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      Text(
                        (b['category'] ?? 'stay').toString() == 'hotel'
                            ? 'Lake view'
                            : 'View place',
                        style: const TextStyle(
                          color: Color(0xFF756F67),
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _curatedPromoCard(Map<String, dynamic> item) {
    return Container(
      width: 266,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF262017), width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.network(item['image'], fit: BoxFit.cover),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.35),
                      Colors.black.withValues(alpha: 0.85),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    item['badge'],
                    style: const TextStyle(
                      color: Color(0xFFE3A82D),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item['title'],
                    style: const TextStyle(
                      color: FT.ivory,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'serif',
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item['subtitle'],
                    style: const TextStyle(
                      color: Color(0xFFDDD8D0),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'View offer >',
                    style: TextStyle(
                      color: Color(0xFFE3A82D),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
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

  Widget _livePromoCard(Map<String, dynamic> p) {
    final title = p['title'] ?? 'Exclusive Offer';
    final badge = p['badge'] ?? 'SPECIAL OFFER';
    final sub = p['description'] ?? p['businesses']?['name'] ?? '';
    final image = (p['image_url'] ?? '').toString();

    return Container(
      width: 266,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF262017), width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Positioned.fill(
              child: FTImage(
                url: image.isNotEmpty ? image : _defaultBuildingHero,
                fit: BoxFit.cover,
              ),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.35),
                      Colors.black.withValues(alpha: 0.85),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    badge,
                    style: const TextStyle(
                      color: Color(0xFFE3A82D),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: const TextStyle(
                      color: FT.ivory,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'serif',
                    ),
                  ),
                  if (sub.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      sub,
                      style: const TextStyle(
                        color: Color(0xFFDDD8D0),
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 10),
                  const Text(
                    'View offer >',
                    style: TextStyle(
                      color: Color(0xFFE3A82D),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
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

  Widget _journeyTile(
      String title, String subtitle, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF14110C),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF241F18), width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF1F1A12),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: const Color(0xFFE3A82D), size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: FT.ivory,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF8E8982),
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: Color(0xFF6B665E), size: 22),
          ],
        ),
      ),
    );
  }
}

/// Robust image loader that gracefully handles:
/// - Supabase Storage public URLs uploaded from the Admin Console
/// - Legacy Base64 Data URLs (`data:image/...;base64,...`) from older admin uploads
/// - Standard web URLs (`https://...`)
/// - Graceful fallback container
class FTImage extends StatelessWidget {
  final String? url;
  final double? width;
  final double? height;
  final BoxFit fit;

  const FTImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final raw = (url ?? '').trim();
    if (raw.isEmpty) {
      return Container(color: const Color(0xFF1C1914));
    }
    if (raw.startsWith('data:image')) {
      try {
        final comma = raw.indexOf(',');
        if (comma != -1) {
          final bytes = base64Decode(raw.substring(comma + 1));
          return Image.memory(
            bytes,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (_, __, ___) =>
                Container(color: const Color(0xFF1C1914)),
          );
        }
      } catch (_) {}
    }
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return Image.network(
        raw,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) =>
            Container(color: const Color(0xFF1C1914)),
      );
    }
    return Container(color: const Color(0xFF1C1914));
  }
}
