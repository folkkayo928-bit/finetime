import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../net.dart';
import '../theme.dart';
import 'business_profile.dart';

class ReviewDirectoryScreen extends StatefulWidget {
  final String category;
  final String title;
  const ReviewDirectoryScreen({super.key, required this.category, required this.title});
  @override
  State<ReviewDirectoryScreen> createState() => _ReviewDirectoryScreenState();
}

class _ReviewDirectoryScreenState extends State<ReviewDirectoryScreen> {
  final sb = Supabase.instance.client;
  List<Map<String, dynamic>> places = [];
  bool loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final categories = widget.category == 'food' ? ['cafe', 'restaurant'] : ['hotel'];
      final rows = await Net.run(() => sb.from('businesses')
        .select('id,name,category,about,cover_url,gallery_urls,cities(name),reviews(rating)')
        .eq('is_published', true).inFilter('category', categories).order('name'));
      if (mounted) setState(() { places = List<Map<String, dynamic>>.from(rows); loading = false; });
    } catch (_) { if (mounted) setState(() => loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C0A06),
      appBar: AppBar(backgroundColor: const Color(0xFF0C0A06), foregroundColor: FT.ivory, elevation: 0,
        title: Text(widget.title, style: const TextStyle(fontFamily: 'serif', fontWeight: FontWeight.w800))),
      body: RefreshIndicator(
        onRefresh: _load, color: FT.gold, backgroundColor: const Color(0xFF17130D),
        child: loading ? const Center(child: CircularProgressIndicator(color: FT.gold))
          : places.isEmpty ? ListView(children: const [SizedBox(height: 180), Center(child: Text('No places published yet.', style: TextStyle(color: FT.muted)))] )
          : ListView.separated(padding: const EdgeInsets.fromLTRB(20, 8, 20, 32), itemCount: places.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (_, i) => _placeCard(places[i])),
      ),
    );
  }

  Widget _placeCard(Map<String, dynamic> place) {
    final ratings = (place['reviews'] as List? ?? [])
      .map((r) => num.tryParse((r as Map)['rating']?.toString() ?? ''))
      .whereType<num>().map((n) => n.toDouble()).toList();
    final average = ratings.isEmpty ? null : ratings.reduce((a, b) => a + b) / ratings.length;
    final about = (place['about'] ?? '').toString().trim();
    final city = place['cities'] is Map ? (place['cities']['name'] ?? '').toString() : '';
    final gallery = place['gallery_urls'];
    final galleryUrl = gallery is List && gallery.isNotEmpty ? gallery.first.toString() : '';
    final cover = (place['cover_url'] ?? '').toString().trim();
    final imageUrl = cover.isNotEmpty ? cover : galleryUrl;

    return Material(
      color: const Color(0xFF14110C), borderRadius: BorderRadius.circular(22),
      child: InkWell(borderRadius: BorderRadius.circular(22),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BusinessProfileScreen(businessId: place['id'].toString()))),
        child: Padding(padding: const EdgeInsets.all(12), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(borderRadius: BorderRadius.circular(16),
            child: imageUrl.isEmpty ? Container(width: 104, height: 126, color: const Color(0xFF252016), child: const Icon(Icons.photo_outlined, color: Colors.white24, size: 30))
              : Image.network(imageUrl, width: 104, height: 126, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(width: 104, height: 126, color: const Color(0xFF252016), child: const Icon(Icons.photo_outlined, color: Colors.white24, size: 30)))),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text((place['category'] ?? '').toString().toUpperCase(), style: const TextStyle(color: FT.gold, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.8)),
            const SizedBox(height: 5),
            Text(place['name'] ?? 'FineTime place', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: FT.ivory, fontSize: 20, fontWeight: FontWeight.w800, fontFamily: 'serif')),
            if (city.isNotEmpty) ...[const SizedBox(height: 5), Text(city, style: const TextStyle(color: Colors.white54, fontSize: 12))],
            const SizedBox(height: 9),
            Row(children: [
              const Icon(Icons.star_rounded, color: FT.gold, size: 17), const SizedBox(width: 4),
              Text(average == null ? 'New' : average.toStringAsFixed(1), style: const TextStyle(color: FT.ivory, fontWeight: FontWeight.w800)),
              const SizedBox(width: 6),
              Text(ratings.length.toString() + ' review' + (ratings.length == 1 ? '' : 's'), style: const TextStyle(color: Colors.white54, fontSize: 11.5)),
            ]),
            if (about.isNotEmpty) ...[const SizedBox(height: 9), Text(about, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: FT.cream, fontSize: 12.5, height: 1.35))],
          ])),
          const Padding(padding: EdgeInsets.only(top: 8), child: Icon(Icons.arrow_forward_ios_rounded, color: FT.gold, size: 14)),
        ])),
      ),
    );
  }
}
