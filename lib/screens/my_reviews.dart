import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';
import 'business_profile.dart';

class MyReviewsScreen extends StatefulWidget {
  const MyReviewsScreen({super.key});

  @override
  State<MyReviewsScreen> createState() => _MyReviewsScreenState();
}

class _MyReviewsScreenState extends State<MyReviewsScreen> {
  final sb = Supabase.instance.client;

  List<Map<String, dynamic>> reviews = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = sb.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => loading = false);
      return;
    }

    try {
      final rows = await sb
          .from('reviews')
          .select('*, businesses(id,name,category,cover_url)')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      if (!mounted) return;
      setState(() {
        reviews = List<Map<String, dynamic>>.from(rows);
        loading = false;
        error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = 'Could not load your reviews. Check your connection.';
      });
    }
  }

  String _date(dynamic value) {
    final raw = value?.toString() ?? '';
    return raw.length >= 10 ? raw.substring(0, 10) : raw;
  }

  String _category(Map<String, dynamic> row) {
    final business = row['businesses'];
    if (business is Map) {
      final value = (business['category'] ?? 'place').toString();
      if (value.isEmpty) return 'Place';
      return value[0].toUpperCase() + value.substring(1);
    }
    return 'Place';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FT.obsidian,
      appBar: AppBar(title: const Text('My reviews')),
      body: RefreshIndicator(
        onRefresh: _load,
        color: FT.gold,
        backgroundColor: FT.surface,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 38),
          children: [
            const Text(
              'Your FineTime voice',
              style: TextStyle(
                color: FT.ivory,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                fontFamily: 'serif',
              ),
            ),
            const SizedBox(height: 6),
            Text(
              reviews.length.toString() + ' review' + (reviews.length == 1 ? '' : 's') + ' written by you',
              style: const TextStyle(color: FT.muted),
            ),
            const SizedBox(height: 20),
            if (loading)
              const Padding(
                padding: EdgeInsets.all(50),
                child: Center(child: CircularProgressIndicator(color: FT.gold)),
              )
            else if (error != null)
              _error()
            else if (reviews.isEmpty)
              _empty()
            else
              ...reviews.map(_card),
          ],
        ),
      ),
    );
  }

  Widget _card(Map<String, dynamic> review) {
    final business = review['businesses'] is Map
        ? Map<String, dynamic>.from(review['businesses'])
        : <String, dynamic>{};
    final url = (business['cover_url'] ?? '').toString().trim();
    final rating = int.tryParse((review['rating'] ?? 0).toString()) ?? 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: business['id'] == null
            ? null
            : () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BusinessProfileScreen(
                      businessId: business['id'].toString(),
                    ),
                  ),
                );
              },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF111518),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF252A2D)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: url.isEmpty
                    ? Container(
                        width: 88,
                        height: 88,
                        color: FT.surface,
                        child: const Icon(Icons.place_outlined, color: FT.muted, size: 30),
                      )
                    : Image.network(
                        url,
                        width: 88,
                        height: 88,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 88,
                          height: 88,
                          color: FT.surface,
                          child: const Icon(Icons.place_outlined, color: FT.muted, size: 30),
                        ),
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (business['name'] ?? 'FineTime place').toString(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: FT.ivory,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'serif',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _category(review),
                      style: const TextStyle(color: FT.gold, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        ...List.generate(
                          5,
                          (index) => Icon(
                            index < rating ? Icons.star : Icons.star_border,
                            color: FT.gold,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _date(review['created_at']),
                          style: const TextStyle(color: FT.muted, fontSize: 11),
                        ),
                      ],
                    ),
                    if ((review['body'] ?? '').toString().trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        review['body'].toString(),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: FT.cream, height: 1.35, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _empty() => const Padding(
        padding: EdgeInsets.symmetric(vertical: 58),
        child: Column(
          children: [
            Icon(Icons.rate_review_outlined, color: FT.muted, size: 56),
            SizedBox(height: 14),
            Text(
              'You have not written a review yet.',
              style: TextStyle(color: FT.cream, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 6),
            Text(
              'After a completed FineTime experience, your reviews will appear here.',
              style: TextStyle(color: FT.muted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );

  Widget _error() => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: FT.muted),
            ),
            const SizedBox(height: 10),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
}
