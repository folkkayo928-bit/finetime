import 'package:flutter/material.dart';
import '../theme.dart';
import 'review_directory.dart';

class GuestReviewsScreen extends StatelessWidget {
  const GuestReviewsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C0A06),
      appBar: AppBar(backgroundColor: const Color(0xFF0C0A06), foregroundColor: FT.ivory, elevation: 0,
        title: const Text('Guest reviews', style: TextStyle(fontFamily: 'serif', fontWeight: FontWeight.w800))),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 10, 20, 32), children: [
        const Text('Real stays. Real tastes.', style: TextStyle(color: FT.ivory, fontSize: 30, fontWeight: FontWeight.w800, fontFamily: 'serif')),
        const SizedBox(height: 8),
        const Text('Explore what FineTime guests experienced across Ethiopia, then open any place to read the full stories and share your own.',
          style: TextStyle(color: FT.muted, fontSize: 14.5, height: 1.45)),
        const SizedBox(height: 24),
        _category(context, 'Hotels', 'Stays, service, rooms & Ethiopian hospitality', Icons.hotel_rounded, 'hotel'),
        const SizedBox(height: 14),
        _category(context, 'Cafés & Restaurants', 'Coffee, food & memorable Ethiopian experiences', Icons.restaurant_rounded, 'food'),
      ]),
    );
  }
  Widget _category(BuildContext context, String title, String subtitle, IconData icon, String category) {
    return Material(
      color: const Color(0xFF14110C), borderRadius: BorderRadius.circular(24),
      child: InkWell(borderRadius: BorderRadius.circular(24),
        onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => ReviewDirectoryScreen(category: category, title: title))),
        child: Padding(padding: const EdgeInsets.all(20), child: Row(children: [
          Container(width: 62, height: 62, decoration: BoxDecoration(color: FT.gold.withValues(alpha: .12), borderRadius: BorderRadius.circular(18)),
            child: Icon(icon, color: FT.gold, size: 30)),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: FT.ivory, fontSize: 21, fontWeight: FontWeight.w800, fontFamily: 'serif')),
            const SizedBox(height: 5),
            Text(subtitle, style: const TextStyle(color: FT.muted, fontSize: 13, height: 1.35)),
          ])),
          const Icon(Icons.arrow_forward_ios_rounded, color: FT.gold, size: 17),
        ])),
      ),
    );
  }
}
