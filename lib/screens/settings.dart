import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../net.dart';
import '../theme.dart';
import 'notifications.dart';
import 'personal_info.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final sb = Supabase.instance.client;

  bool bookingUpdates = true;
  bool fineTimeOffers = true;
  String language = 'English';
  String currency = 'ETB';
  bool loading = true;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _load() async {
    final user = sb.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => loading = false);
      return;
    }

    final metadata = user.userMetadata ?? {};
    final raw = metadata['finetime_settings'];

    if (raw is Map) {
      bookingUpdates = raw['booking_updates'] != false;
      fineTimeOffers = raw['fine_time_offers'] != false;
      language = (raw['language'] ?? 'English').toString();
      currency = (raw['currency'] ?? 'ETB').toString();
    }

    if (mounted) setState(() => loading = false);
  }

  Future<void> _save() async {
    final user = sb.auth.currentUser;
    if (user == null) return;

    setState(() => saving = true);
    try {
      final settings = {
        'booking_updates': bookingUpdates,
        'fine_time_offers': fineTimeOffers,
        'language': language,
        'currency': currency,
      };

      await sb.auth.updateUser(
        UserAttributes(
          data: {
            ...?user.userMetadata,
            'finetime_settings': settings,
          },
        ),
      );

      _message('Settings saved on your FineTime account.');
    } on AuthException catch (e) {
      _message(Net.friendly(e));
    } catch (e) {
      _message(Net.friendly(e));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _pickValue({
    required String title,
    required List<String> options,
    required String value,
    required ValueChanged<String> onSelected,
  }) async {
    final chosen = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: FT.obsidian,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 8, 6, 12),
              child: Text(
                title,
                style: const TextStyle(
                  color: FT.ivory,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            ...options.map(
              (option) => ListTile(
                title: Text(option),
                trailing: option == value
                    ? const Icon(Icons.check_rounded, color: FT.gold)
                    : null,
                onTap: () => Navigator.pop(ctx, option),
              ),
            ),
          ],
        ),
      ),
    );

    if (chosen == null) return;
    setState(() => onSelected(chosen));
    await _save();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FT.obsidian,
      appBar: AppBar(title: const Text('Settings')),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: FT.gold))
          : ListView(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 40),
              children: [
                const Text(
                  'FineTime preferences',
                  style: TextStyle(
                    color: FT.ivory,
                    fontSize: 29,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'serif',
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'These preferences stay with your FineTime account.',
                  style: TextStyle(color: FT.muted),
                ),
                const SizedBox(height: 20),
                _group(
                  title: 'Account',
                  children: [
                    _row(
                      Icons.person_outline_rounded,
                      'Personal information',
                      'Name, phone, email and password',
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PersonalInfoScreen(),
                        ),
                      ),
                    ),
                    _row(
                      Icons.notifications_none_rounded,
                      'Notifications',
                      'See and manage your notification activity',
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NotificationsScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _group(
                  title: 'Preferences',
                  children: [
                    _toggle(
                      icon: Icons.event_available_outlined,
                      title: 'Booking & activity updates',
                      subtitle: 'Keep booking, dining and order updates enabled',
                      value: bookingUpdates,
                      onChanged: (value) {
                        setState(() => bookingUpdates = value);
                        _save();
                      },
                    ),
                    _toggle(
                      icon: Icons.local_offer_outlined,
                      title: 'FineTime offers',
                      subtitle: 'Receive FineTime promotions and special offers',
                      value: fineTimeOffers,
                      onChanged: (value) {
                        setState(() => fineTimeOffers = value);
                        _save();
                      },
                    ),
                    _row(
                      Icons.language_rounded,
                      'Language',
                      language,
                      () => _pickValue(
                        title: 'Language',
                        options: const ['English', 'Amharic'],
                        value: language,
                        onSelected: (value) => language = value,
                      ),
                    ),
                    _row(
                      Icons.payments_outlined,
                      'Currency',
                      currency,
                      () => _pickValue(
                        title: 'Currency',
                        options: const ['ETB', 'USD'],
                        value: currency,
                        onSelected: (value) => currency = value,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (saving)
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: FT.gold),
                      ),
                      SizedBox(width: 10),
                      Text('Saving…', style: TextStyle(color: FT.muted)),
                    ],
                  ),
              ],
            ),
    );
  }

  Widget _group({required String title, required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111518),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF252A2D)),
      ),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
              child: Text(
                title,
                style: const TextStyle(
                  color: FT.gold,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .6,
                ),
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _row(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Icon(icon, color: FT.gold),
      title: Text(
        title,
        style: const TextStyle(
          color: FT.ivory,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(subtitle, style: const TextStyle(color: FT.muted, fontSize: 12)),
      trailing: const Icon(Icons.chevron_right_rounded, color: FT.muted),
      onTap: onTap,
    );
  }

  Widget _toggle({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      secondary: Icon(icon, color: FT.gold),
      title: Text(
        title,
        style: const TextStyle(color: FT.ivory, fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: FT.muted, fontSize: 12, height: 1.3),
      ),
      value: value,
      onChanged: onChanged,
      activeTrackColor: FT.gold,
      activeThumbColor: const Color(0xFF1E1607),
    );
  }
}
