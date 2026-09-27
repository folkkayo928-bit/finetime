import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dns_fix.dart';
import 'theme.dart';
import 'screens/root.dart';

const supabaseUrl = String.fromEnvironment('SUPABASE_URL');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Resolve the Supabase host via DNS-over-HTTPS so the app works
  // even on devices whose DNS resolver is broken or filtered.
  if (supabaseUrl.isNotEmpty) {
    await DnsFix.prepare(supabaseUrl: supabaseUrl);
  }
  await Supabase.initialize(
    url: supabaseUrl,
    // ignore: deprecated_member_use
    anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
  );
  runApp(const FineTimeApp());
}

class FineTimeApp extends StatelessWidget {
  const FineTimeApp({super.key});
  @override
  Widget build(BuildContext context) =>
      MaterialApp(title: 'FineTime', debugShowCheckedModeBanner: false, theme: FT.theme(), home: const RootScreen());
}
