import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../net.dart';
import '../theme.dart';

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

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final u = sb.auth.currentUser;
    if (u == null) return;
    try {
      final p = await Net.run(
          () => sb.from('profiles').select().eq('id', u.id).maybeSingle());
      if (mounted) setState(() { _profile = p; _name.text = p?['full_name'] ?? ''; });
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
    if (name.isEmpty) { _snack('Full real name is required.'); return; }
    if (!email.contains('@')) { _snack('Enter a valid email address.'); return; }
    if (pass.length < 6) { _snack('Password must be at least 6 characters.'); return; }

    setState(() => _busy = true);
    try {
      // retry: false — auth endpoints are rate-limited by Supabase;
      // retrying would multiply requests and trigger "Limit exceeded".
      final res = await Net.run(
        () => sb.auth.signUp(email: email, password: pass),
        retry: false,
      );
      final u = res.user;
      if (u == null) {
        _snack('Sign up failed. Please try again.');
        return;
      }
      if (res.session == null) {
        _snack('Account created! Check your email and confirm to sign in.');
        return;
      }
      await Net.run(() => sb.from('profiles').upsert({'id': u.id, 'full_name': name}));
      await _loadProfile();
    } on AuthException catch (e) {
      _snack(e.message);
    } catch (e) {
      _snack(Net.friendly(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signIn() async {
    setState(() => _busy = true);
    try {
      await Net.run(
        () => sb.auth
            .signInWithPassword(email: _email.text.trim(), password: _pass.text),
        retry: false,
      );
      await _loadProfile();
    } on AuthException catch (e) {
      _snack(Net.friendly(e));
    } catch (e) {
      _snack(Net.friendly(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = sb.auth.currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('Me')),
      body: u == null
        ? ListView(padding: const EdgeInsets.all(16), children: [
            const Text('Welcome to FineTime F', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: FT.charcoal)),
            const Text('BUILD 5', style: TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 20),
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Full real name')),
            TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email'), keyboardType: TextInputType.emailAddress),
            TextField(controller: _pass, decoration: const InputDecoration(labelText: 'Password'), obscureText: true),
            const SizedBox(height: 16),
            FilledButton(onPressed: _busy ? null : _signUp, child: Text(_busy ? 'Working…' : 'Create Account')),
            TextButton(onPressed: _busy ? null : _signIn, child: const Text('Already have an account? Sign in')),
          ])
        : ListView(children: [
            const CircleAvatar(radius: 36, backgroundColor: FT.gold, child: Icon(Icons.person, size: 40, color: FT.charcoal)),
            Center(child: Padding(padding: const EdgeInsets.all(12),
              child: Text(_profile?['full_name'] ?? u.email ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)))),
            ListTile(leading: const Icon(Icons.logout), title: const Text('Sign out'),
              onTap: () async { await sb.auth.signOut(); if (mounted) setState(() => _profile = null); }),
          ]));
  }
}
