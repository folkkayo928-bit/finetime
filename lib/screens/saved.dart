import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';
import 'business_profile.dart';

class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  final sb = Supabase.instance.client;

  List<Map<String, dynamic>> saved = [];
  bool loading = true;
  String? error;
  String filter = 'all';

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final user = sb.auth.currentUser;

    if (user == null) {
      if (mounted) {
        setState(() => loading = false);
      }
      return;
    }

    try {
      final rows = await sb
          .from('saved_places')
          .select('*, businesses(*)')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      if (!mounted) return;

      setState(() {
        saved = List<Map<String, dynamic>>.from(rows);
        loading = false;
        error = null;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        loading = false;
        error = 'Could not load saved places. Check your connection.';
      });
    }
  }

  Future<void> unsave(Map<String, dynamic> item) async {
    final user = sb.auth.currentUser;
    if (user == null) return;

    await sb
        .from('saved_places')
        .delete()
        .eq('user_id', user.id)
        .eq('business_id', item['business_id']);

    if (!mounted) return;
    setState(() => saved.remove(item));
  }

  String imageFor(Map<String, dynamic> business) {
    final candidates = [
      business['cover_url'],
      business['image_url'],
      business['cover_image_url'],
      business['hero_image_url'],
      business['photo_url'],
    ];

    for (final value in candidates) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }

    return 'https://images.unsplash.com/photo-1582719478250-c89cae4dc85b?auto=format&fit=crop&w=1200&q=80';
  }

  String cityFor(Map<String, dynamic> business) {
    final cityValue = business['cities'];
    if (cityValue is Map) {
      return (cityValue['name'] ?? business['city'] ?? 'Ethiopia').toString();
    }
    return (business['city'] ?? 'Ethiopia').toString();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = filter == 'all'
        ? saved
        : saved.where((item) {
            final value = item['businesses'];
            if (value is! Map) return false;
            return (value['category'] ?? '').toString().toLowerCase() == filter;
          }).toList();

    return Scaffold(
      backgroundColor: FT.obsidian,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: load,
          color: FT.gold,
          backgroundColor: FT.surface,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 30),
            children: [
              const Text(
                'Saved places',
                style: TextStyle(
                  color: FT.ivory,
                  fontSize: 38,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'serif',
                ),
              ),
              const SizedBox(height: 5),
              Text(
                saved.length.toString() +
                    ' place' +
                    (saved.length == 1 ? '' : 's') +
                    ' in your collection',
                style: const TextStyle(color: FT.muted, fontSize: 14),
              ),
              const SizedBox(height: 20),
              _chips(),
              const SizedBox(height: 20),
              if (sb.auth.currentUser == null)
                const _EmptySaved('Sign in to save places.')
              else if (loading)
                const Padding(
                  padding: EdgeInsets.all(50),
                  child: Center(
                    child: CircularProgressIndicator(color: FT.gold),
                  ),
                )
              else if (error != null)
                _errorState()
              else if (filtered.isEmpty)
                const _EmptySaved('Your saved places will appear here.')
              else
                ...filtered.map(_card),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chips() {
    const categories = ['all', 'hotel', 'restaurant', 'cafe', 'experience'];

    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: categories.map((category) {
          final selected = filter == category;
          final label = category == 'all'
              ? 'All'
              : category[0].toUpperCase() + category.substring(1);

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(label),
              selected: selected,
              selectedColor: FT.gold,
              backgroundColor: FT.surface,
              side: const BorderSide(color: Color(0xFF282B2D)),
              labelStyle: TextStyle(
                color: selected ? const Color(0xFF1B1407) : FT.cream,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              onSelected: (_) => setState(() => filter = category),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _card(Map<String, dynamic> item) {
    final value = item['businesses'];
    final business = value is Map
        ? Map<String, dynamic>.from(value)
        : <String, dynamic>{};

    final rating =
        business['rating'] ?? business['average_rating'] ?? '4.9';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BusinessProfileScreen(
                businessId: business['id'].toString(),
              ),
            ),
          ).then((_) => load());
        },
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF111518),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF252A2D)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  SizedBox(
                    height: 225,
                    width: double.infinity,
                    child: Image.network(
                      imageFor(business),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Container(color: FT.surface),
                    ),
                  ),
                  Positioned(
                    left: 12,
                    bottom: 10,
                    child: _badge(
                      (business['category'] ?? 'place').toString(),
                    ),
                  ),
                  Positioned(
                    right: 10,
                    top: 10,
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: .55),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => unsave(item),
                        icon: const Icon(
                          Icons.favorite,
                          color: FT.gold,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(15, 13, 15, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            business['name'] ?? 'FineTime place',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: FT.ivory,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'serif',
                            ),
                          ),
                        ),
                        const Icon(Icons.star, color: FT.gold, size: 17),
                        const SizedBox(width: 3),
                        Text(
                          rating.toString(),
                          style: const TextStyle(
                            color: FT.cream,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          color: FT.muted,
                          size: 14,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            cityFor(business),
                            style: const TextStyle(
                              color: FT.muted,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      business['price'] != null
                          ? 'ETB ' + business['price'].toString()
                          : 'View details',
                      style: const TextStyle(
                        color: FT.goldLight,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(String text) {
    final label = text.isEmpty
        ? 'Place'
        : text[0].toUpperCase() + text.substring(1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .72),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        label,
        style: const TextStyle(color: FT.ivory, fontSize: 10),
      ),
    );
  }

  Widget _errorState() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text(
            error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: FT.muted),
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: load,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _EmptySaved extends StatelessWidget {
  final String text;

  const _EmptySaved(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 55),
      child: Column(
        children: [
          const Icon(Icons.favorite_border, color: FT.muted, size: 55),
          const SizedBox(height: 14),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: FT.muted),
          ),
        ],
      ),
    );
  }
}
