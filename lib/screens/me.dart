import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final u = sb.auth.currentUser;
    if (u == null) return;
    final p = await sb.from('profiles').select().eq('id', u.id).maybeSingle();
    if (mounted) setState(() { _profile = p; _name.text = p?['full_name'] ?? ''; });
  }

  Future<void> _signUp() async {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Full real name is required.')));
      return;
    }
    try {
      final res = await sb.auth.signUp(email: _email.text.trim(), password: _pass.text);
      final u = res.user;
      if (u != null) {
        await sb.from('profiles').upsert({'id': u.id, 'full_name': _name.text.trim()});
        await _loadProfile();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sign up failed. Check your details.')));
    }
  }

  Future<void> _signIn() async {
    try { await sb.auth.signInWithPassword(email: _email.text.trim(), password: _pass.text); await _loadProfile(); }
    catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sign in failed.')));
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
            const SizedBox(height: 20),
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Full real name')),
            TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email'), keyboardType: TextInputType.emailAddress),
            TextField(controller: _pass, decoration: const InputDecoration(labelText: 'Password'), obscureText: true),
            const SizedBox(height: 16),
            FilledButton(onPressed: _signUp, child: const Text('Create Account')),
            TextButton(onPressed: _signIn, child: const Text('Already have an account? Sign in')),
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
