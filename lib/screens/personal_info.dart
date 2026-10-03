import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../net.dart';
import '../theme.dart';

class PersonalInfoScreen extends StatefulWidget {
  const PersonalInfoScreen({super.key});

  @override
  State<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  final sb = Supabase.instance.client;

  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();

  bool _loading = true;
  bool _savingProfile = false;
  bool _changingEmail = false;
  bool _changingPassword = false;
  bool _hideCurrent = true;
  bool _hideNew = true;
  bool _hideConfirm = true;

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
      if (mounted) Navigator.pop(context);
      return;
    }

    try {
      final profile = await sb
          .from('profiles')
          .select('full_name,phone')
          .eq('id', user.id)
          .maybeSingle();

      _name.text = (profile?['full_name'] ?? '').toString();
      _phone.text = (profile?['phone'] ?? '').toString();
      _email.text = user.email ?? '';

      if (mounted) setState(() => _loading = false);
    } catch (_) {
      _email.text = user.email ?? '';
      if (mounted) {
        setState(() => _loading = false);
        _message('Could not load your profile. You can retry from this page.');
      }
    }
  }

  Future<void> _savePersonalDetails() async {
    final user = sb.auth.currentUser;
    if (user == null) return;

    final name = _name.text.trim();
    final phone = _phone.text.trim();

    if (name.isEmpty) {
      _message('Please enter your full name.');
      return;
    }

    setState(() => _savingProfile = true);
    try {
      await sb.from('profiles').upsert({
        'id': user.id,
        'full_name': name,
        'phone': phone.isEmpty ? null : phone,
      });

      _message('Your personal details were updated.');
    } catch (e) {
      _message(Net.friendly(e));
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  Future<bool> _verifyCurrentPassword(String password) async {
    final user = sb.auth.currentUser;
    final email = user?.email;

    if (email == null || email.isEmpty) {
      _message('Your account email is not available. Please sign in again.');
      return false;
    }

    try {
      await sb.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return true;
    } on AuthException catch (e) {
      _message('Current password is incorrect.');
      return false;
    } catch (_) {
      _message('We could not verify your current password.');
      return false;
    }
  }

  Future<void> _changeEmail() async {
    final user = sb.auth.currentUser;
    final currentEmail = user?.email ?? '';
    final nextEmail = _email.text.trim();
    final password = _currentPassword.text;

    if (nextEmail.isEmpty || !nextEmail.contains('@')) {
      _message('Enter a valid new email address.');
      return;
    }
    if (nextEmail.toLowerCase() == currentEmail.toLowerCase()) {
      _message('That is already your current email address.');
      return;
    }
    if (password.isEmpty) {
      _message('Enter your current password to change your email.');
      return;
    }

    setState(() => _changingEmail = true);
    try {
      final verified = await _verifyCurrentPassword(password);
      if (!verified) return;

      await sb.auth.updateUser(UserAttributes(email: nextEmail));
      _currentPassword.clear();

      _message(
        'Email update started. Check your new email address to confirm the change if FineTime asks for verification.',
      );
    } on AuthException catch (e) {
      _message(Net.friendly(e));
    } catch (e) {
      _message(Net.friendly(e));
    } finally {
      if (mounted) setState(() => _changingEmail = false);
    }
  }

  Future<void> _changePassword() async {
    final oldPassword = _currentPassword.text;
    final newPassword = _newPassword.text;
    final confirm = _confirmPassword.text;

    if (oldPassword.isEmpty) {
      _message('Enter your current password.');
      return;
    }
    if (newPassword.length < 6) {
      _message('Your new password must be at least 6 characters.');
      return;
    }
    if (newPassword != confirm) {
      _message('The new passwords do not match.');
      return;
    }
    if (newPassword == oldPassword) {
      _message('Choose a new password that is different from your current one.');
      return;
    }

    setState(() => _changingPassword = true);
    try {
      final verified = await _verifyCurrentPassword(oldPassword);
      if (!verified) return;

      await sb.auth.updateUser(UserAttributes(password: newPassword));

      _currentPassword.clear();
      _newPassword.clear();
      _confirmPassword.clear();

      _message('Your password was updated successfully.');
    } on AuthException catch (e) {
      _message(Net.friendly(e));
    } catch (e) {
      _message(Net.friendly(e));
    } finally {
      if (mounted) setState(() => _changingPassword = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _currentPassword.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FT.obsidian,
      appBar: AppBar(title: const Text('Personal information')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: FT.gold))
          : ListView(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 40),
              children: [
                const Text(
                  'Your account, your control.',
                  style: TextStyle(
                    color: FT.ivory,
                    fontSize: 27,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'serif',
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Change your name, phone number, email or password whenever you need.',
                  style: TextStyle(color: FT.muted, height: 1.4),
                ),
                const SizedBox(height: 22),
                _section(
                  title: 'Personal details',
                  icon: Icons.person_outline_rounded,
                  children: [
                    TextField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Full name',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone number',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _savingProfile ? null : _savePersonalDetails,
                      child: Text(
                        _savingProfile ? 'Saving…' : 'Save personal details',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _section(
                  title: 'Email address',
                  icon: Icons.mail_outline_rounded,
                  children: [
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email address',
                        prefixIcon: Icon(Icons.alternate_email_rounded),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Changing your email may require confirmation from the new address.',
                      style: TextStyle(color: FT.muted, fontSize: 12, height: 1.4),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _currentPassword,
                      obscureText: _hideCurrent,
                      decoration: InputDecoration(
                        labelText: 'Current password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _hideCurrent = !_hideCurrent),
                          icon: Icon(
                            _hideCurrent
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton(
                      onPressed: _changingEmail ? null : _changeEmail,
                      child: Text(
                        _changingEmail ? 'Updating email…' : 'Update email',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _section(
                  title: 'Password',
                  icon: Icons.password_rounded,
                  children: [
                    TextField(
                      controller: _currentPassword,
                      obscureText: _hideCurrent,
                      decoration: InputDecoration(
                        labelText: 'Current password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _hideCurrent = !_hideCurrent),
                          icon: Icon(
                            _hideCurrent
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _newPassword,
                      obscureText: _hideNew,
                      decoration: InputDecoration(
                        labelText: 'New password',
                        prefixIcon: const Icon(Icons.lock_reset_rounded),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _hideNew = !_hideNew),
                          icon: Icon(
                            _hideNew
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _confirmPassword,
                      obscureText: _hideConfirm,
                      decoration: InputDecoration(
                        labelText: 'Confirm new password',
                        prefixIcon: const Icon(Icons.verified_user_outlined),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _hideConfirm = !_hideConfirm),
                          icon: Icon(
                            _hideConfirm
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Your current password is required before a new password can be saved.',
                      style: TextStyle(color: FT.muted, fontSize: 12, height: 1.4),
                    ),
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: _changingPassword ? null : _changePassword,
                      child: Text(
                        _changingPassword ? 'Updating password…' : 'Update password',
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _section({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        color: const Color(0xFF111518),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF252A2D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: FT.gold.withValues(alpha: .12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: FT.gold, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  color: FT.ivory,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}
