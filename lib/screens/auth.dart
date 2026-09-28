import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../net.dart';
import '../theme.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final sb = Supabase.instance.client;
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _create = true;
  bool _busy = false;
  bool _obscure = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    final email = _email.text.trim();
    final password = _password.text;

    if (_create && name.isEmpty) {
      _message('Enter your full real name.');
      return;
    }
    if (!email.contains('@')) {
      _message('Enter a valid email address.');
      return;
    }
    if (password.length < 6) {
      _message('Password must be at least 6 characters.');
      return;
    }

    setState(() => _busy = true);
    try {
      if (_create) {
        final response = await sb.auth.signUp(
          email: email,
          password: password,
          data: {'full_name': name},
        );
        final user = response.user;
        if (user == null) throw const AuthException('Could not create the account.');

        if (response.session == null) {
          _message('Account created. Confirm your email, then sign in.');
          return;
        }

        await sb.from('profiles').upsert({
          'id': user.id,
          'full_name': name,
        });
      } else {
        final response = await sb.auth.signInWithPassword(email: email, password: password);
        final user = response.user;
        if (user != null) {
          final profile = await sb.from('profiles').select('id').eq('id', user.id).maybeSingle();
          if (profile == null) {
            final fullName = (user.userMetadata?['full_name'] ?? '').toString().trim();
            if (fullName.isEmpty) {
              await sb.auth.signOut();
              _message('Please contact FineTime support to complete your profile.');
              return;
            }
            await sb.from('profiles').insert({'id': user.id, 'full_name': fullName});
          }
        }
      }
    } on AuthException catch (e) {
      _message(Net.friendly(e));
    } catch (e) {
      _message(Net.friendly(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: FT.charcoal,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('FINETIME',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: FT.gold,
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 4)),
                    const SizedBox(height: 8),
                    const Text('Discover. Dine. Stay.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: FT.ivory, fontSize: 16)),
                    const SizedBox(height: 40),
                    Text(_create ? 'Create your account' : 'Welcome back',
                        style: const TextStyle(
                            color: FT.ivory,
                            fontSize: 24,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text(
                      _create
                          ? 'Your name is reused for bookings and reservations.'
                          : 'Sign in to continue to FineTime.',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 20),
                    if (_create) ...[
                      TextField(
                        controller: _name,
                        textCapitalization: TextCapitalization.words,
                        style: const TextStyle(color: FT.charcoal),
                        decoration: const InputDecoration(labelText: 'Full real name'),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: FT.charcoal),
                      decoration: const InputDecoration(labelText: 'Email'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _password,
                      obscureText: _obscure,
                      style: const TextStyle(color: FT.charcoal),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: Text(_busy
                          ? 'Please wait…'
                          : _create
                              ? 'Create Account'
                              : 'Sign In'),
                    ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() => _create = !_create),
                      child: Text(_create
                          ? 'Already have an account? Sign in'
                          : 'New to FineTime? Create an account'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}
