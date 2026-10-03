import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme.dart';

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  static const _faq = <Map<String, String>>[
    {
      'q': 'How do I book a hotel?',
      'a': 'Open a hotel from Discover or Explore, choose an available room, enter your dates and guests, then submit the booking request. You can follow the result in My Trips.',
    },
    {
      'q': 'How do I reserve a table?',
      'a': 'Open a cafe or restaurant, choose Reserve a table, select the date, time and party size, then submit. Your reservation appears in My Trips.',
    },
    {
      'q': 'How do I save a place?',
      'a': 'Use the save button on a place card or business profile. Saved places are available from the Saved tab and your Me page.',
    },
    {
      'q': 'How many reviews can I leave for one place?',
      'a': 'FineTime allows up to two reviews from the same account for one business. Review submission also requires a completed FineTime experience.',
    },
    {
      'q': 'How do I change my email or password?',
      'a': 'Open Me → Profile settings → Personal information. Email changes and password changes require your current password for verification.',
    },
    {
      'q': 'Where can I see my activity?',
      'a': 'Use My Trips for stays, dining and orders, Order history for a combined activity history, and My reviews for reviews you have written.',
    },
  ];

  Future<void> _openWebsite(BuildContext context) async {
    final uri = Uri.parse('https://folkkayo928-bit.github.io/finetime/website/');
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('FineTime website could not be opened.')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('FineTime website could not be opened.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FT.obsidian,
      appBar: AppBar(title: const Text('Help center')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 40),
        children: [
          const Text(
            'How can we help?',
            style: TextStyle(
              color: FT.ivory,
              fontSize: 30,
              fontWeight: FontWeight.w800,
              fontFamily: 'serif',
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Quick answers for your account, bookings, dining and reviews.',
            style: TextStyle(color: FT.muted, height: 1.4),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF111518),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF252A2D)),
            ),
            child: Column(
              children: _faq.map((item) {
                return ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 14),
                  iconColor: FT.gold,
                  collapsedIconColor: FT.muted,
                  title: Text(
                    item['q']!,
                    style: const TextStyle(
                      color: FT.ivory,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        item['a']!,
                        style: const TextStyle(
                          color: FT.cream,
                          height: 1.45,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: FT.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF2A2721)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.support_agent_rounded, color: FT.gold, size: 24),
                    SizedBox(width: 10),
                    Text(
                      'Need more help?',
                      style: TextStyle(
                        color: FT.ivory,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Visit the official FineTime website for the latest support and contact information.',
                  style: TextStyle(color: FT.muted, height: 1.4),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: () => _openWebsite(context),
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Open FineTime website'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
