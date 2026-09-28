import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'notifications.dart';

class MeScreen extends StatefulWidget {
  const MeScreen({super.key});
  @override
  State<MeScreen> createState() => _MeScreenState();
}

class _MeScreenState extends State<MeScreen> {
  final sb = Supabase.instance.client;
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  Map? _profile;
  bool _busy = false;
  int _unread = 0;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final u = sb.auth.currentUser;
    if (u == null) return;
    try {
      final p = await sb.from('profiles').select().eq('id', u.id).maybeSingle();
      final n = await sb
          .from('notifications')
          .select('id')
          .eq('user_id', u.id)
          .eq('is_read', false);
      if (mounted) {
        setState(() {
          _profile = p;
          _name.text = p?['full_name'] ?? '';
          _unread = (n as List).length;
        });
      }
    } catch (_) {
      // Profile load is non-critical; user stays signed in.
    }
  }

  void _snack(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _signUp() async {
    final name = _name.text.trim();
    final email = _email.text.trim();
    final pass = _pass.text;
    if (name.isEmpty) {
      _snack('Full real name is required.');
      return;
    }
    if (!email.contains('@')) {
      _snack('Enter a valid email address.');
      return;
    }
    if (pass.length < 6) {
      _snack('Password must be at least 6 characters.');
      return;
    }

    setState(() => _busy = true);
    try {
      // retry: false — auth endpoints are rate-limited by Supabase;
      // retrying would multiply requests and trigger "Limit exceeded".
      final res = await sb.auth.signUp(email: email, password: pass);
      final u = res.user;
      if (u == null) {
        _snack('Sign up failed. Please try again.');
        return;
      }
      if (res.session == null) {
        _snack('Account created! Check your email and confirm to sign in.');
        return;
      }
      await sb.from('profiles').upsert({'id': u.id, 'full_name': name});
      await _loadProfile();
    } on AuthException catch (e) {
      _snack(e.message);
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signIn() async {
    setState(() => _busy = true);
    try {
      await sb.auth
          .signInWithPassword(email: _email.text.trim(), password: _pass.text);
      await _loadProfile();
    } on AuthException catch (e) {
      _snack(e.message);
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmSignOut() async {
    final go = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sign out?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sign out')),
        ],
      ),
    );
    if (go == true) {
      await sb.auth.signOut();
      if (mounted) setState(() => _profile = null);
    }
  }

  void _openSupport(String title, String body) {
    showDialog(
        context: context,
        builder: (_) => AlertDialog(
              title: Text(title),
              content: Text(body),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'))
              ],
            ));
  }

  @override
  Widget build(BuildContext context) {
    final u = sb.auth.currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('Me')),
      body: u == null
          ? ListView(padding: const EdgeInsets.all(16), children: [
              const Text('Welcome to FineTime F',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: FT.charcoal)),
              const SizedBox(height: 20),
              TextField(
                  controller: _name,
                  decoration:
                      const InputDecoration(labelText: 'Full real name')),
              TextField(
                  controller: _email,
                  decoration:
                      const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress),
              TextField(
                  controller: _pass,
                  decoration:
                      const InputDecoration(labelText: 'Password'),
                  obscureText: true),
              const SizedBox(height: 16),
              FilledButton(
                  onPressed: _busy ? null : _signUp,
                  child: Text(_busy ? 'Working…' : 'Create Account')),
              TextButton(
                  onPressed: _busy ? null : _signIn,
                  child: const Text('Already have an account? Sign in')),
            ])
          : ListView(children: [
              const CircleAvatar(
                  radius: 36,
                  backgroundColor: FT.gold,
                  child: Icon(Icons.person,
                      size: 40, color: FT.charcoal)),
              Center(
                  child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                          _profile?['full_name'] ?? u.email ?? '',
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700)))),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.notifications_none),
                title: const Text('Notifications'),
                trailing: _unread > 0
                    ? Badge(label: Text('$_unread'))
                    : const Icon(Icons.chevron_right),
                onTap: () async {
                  await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              const NotificationsScreen()));
                  _loadProfile();
                },
              ),
              const Divider(),
              ListTile(
                  leading: const Icon(Icons.help_outline),
                  title: const Text('Help Center'),
                  onTap: () => _openSupport('Help Center',
                      'Find answers about booking stays, reserving tables, saving places and managing your account. For anything else, contact FineTime support.')),
              ListTile(
                  leading: const Icon(Icons.headset_mic_outlined),
                  title: const Text('Contact FineTime'),
                  onTap: () => _openSupport('Contact FineTime',
                      'Support is available every day.\n\nEmail: support@finetime.cc\nTelegram: @FineTimeSupport\n\nInclude your booking reference (FT-...) when writing about a stay.')),
              ListTile(
                  leading: const Icon(Icons.flag_outlined),
                  title: const Text('Report a Problem'),
                  onTap: () => _openSupport('Report a Problem',
                      'Describe what went wrong and include the business name and any reference code. Send it to support@finetime.cc or @FineTimeSupport on Telegram and the team will follow up.')),
              const Divider(),
              ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('About FineTime'),
                  onTap: () => _openSupport('About FineTime',
                      'FineTime — Discover. Dine. Stay.\n\nAn Ethiopia-focused hospitality platform connecting guests with hotels, restaurants and cafés. More cities and businesses coming soon.')),
              const Divider(),
              ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Sign out'),
                  onTap: _confirmSignOut),
            ]),
    );
  }
}
