import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../net.dart';
import '../theme.dart';
import 'root.dart';

class AuthScreen extends StatefulWidget {
  final bool startWithSignIn;
  const AuthScreen({super.key, this.startWithSignIn = false});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final sb = Supabase.instance.client;
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  late bool _create;
  bool _busy = false;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _create = !widget.startWithSignIn;
  }

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

  Future<void> _forgotPassword() async {
    final resetController = TextEditingController(text: _email.text.trim());
    bool sending = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: FT.obsidian,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: FT.gold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.lock_reset_rounded, color: FT.gold, size: 24),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Reset Password',
                            style: TextStyle(
                              color: FT.ivory,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            )),
                        SizedBox(height: 2),
                        Text('We will send you a reset link',
                            style: TextStyle(color: FT.muted, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                'Enter the email address registered with your FineTime account. You will receive an email with instructions to reset your password.',
                style: TextStyle(color: FT.cream, fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: resetController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: FT.ivory),
                decoration: const InputDecoration(
                  labelText: 'Email address',
                  prefixIcon: Icon(Icons.mail_outline_rounded, color: FT.gold),
                ),
              ),
              const SizedBox(height: 22),
              GestureDetector(
                onTap: sending
                    ? null
                    : () async {
                        final email = resetController.text.trim();
                        if (!email.contains('@')) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(content: Text('Please enter a valid email address.')),
                            );
                          }
                          return;
                        }
                        setModalState(() => sending = true);
                        try {
                          await sb.auth.resetPasswordForEmail(email);
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                          }
                          _message('Password reset email sent! Check your inbox.');
                        } on AuthException catch (e) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text(Net.friendly(e))),
                            );
                          }
                        } catch (e) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text(Net.friendly(e))),
                            );
                          }
                        } finally {
                          if (ctx.mounted) setModalState(() => sending = false);
                        }
                      },
                child: Container(
                  width: double.infinity,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: sending ? null : FT.goldGradient,
                    color: sending ? Colors.white12 : null,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    sending ? 'Sending reset link…' : 'Send Reset Link',
                    style: TextStyle(
                      color: sending ? Colors.white54 : const Color(0xFF1E1607),
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: FT.obsidian,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('FINETIME.CC',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: FT.ivory,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 4)),
                    const SizedBox(height: 6),
                    const Text('Discover. Dine. Stay.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: FT.cream, fontSize: 14)),
                    const SizedBox(height: 36),
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
                      style: const TextStyle(color: FT.muted),
                    ),
                    const SizedBox(height: 20),
                    if (_create) ...[
                      TextField(
                        controller: _name,
                        textCapitalization: TextCapitalization.words,
                        style: const TextStyle(color: FT.ivory),
                        decoration: const InputDecoration(labelText: 'Full real name'),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: FT.ivory),
                      decoration: const InputDecoration(labelText: 'Email'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _password,
                      obscureText: _obscure,
                      style: const TextStyle(color: FT.ivory),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off, color: FT.gold),
                        ),
                      ),
                    ),
                    if (!_create) ...[
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _busy ? null : _forgotPassword,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'Forgot password?',
                            style: TextStyle(
                              color: FT.gold,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: _busy ? null : _submit,
                      child: Container(
                        width: double.infinity,
                        height: 54,
                        decoration: BoxDecoration(
                          gradient: _busy ? null : FT.goldGradient,
                          color: _busy ? Colors.white12 : null,
                          borderRadius: BorderRadius.circular(27),
                          boxShadow: _busy
                              ? null
                              : [
                                  BoxShadow(
                                    color: FT.gold.withValues(alpha: 0.3),
                                    blurRadius: 14,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _busy
                              ? 'Please wait…'
                              : _create
                                  ? 'Create Account'
                                  : 'Sign In',
                          style: TextStyle(
                            color: _busy ? Colors.white54 : const Color(0xFF1E1607),
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() => _create = !_create),
                      child: Text(_create
                          ? 'Already have an account? Sign in'
                          : 'New to FineTime? Create an account',
                          style: const TextStyle(color: FT.gold, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _busy
                          ? null
                          : () => Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const RootScreen()),
                              ),
                      icon: const Icon(Icons.explore_outlined, color: FT.gold),
                      label: const Text('Explore as Guest',
                          style: TextStyle(color: FT.ivory, fontWeight: FontWeight.w700)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF332C24)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(27)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}
