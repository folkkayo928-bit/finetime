import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'theme.dart';
import 'screens/root.dart';

const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // ignore: deprecated_member_use
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  runApp(const FineTimeApp());
}

class FineTimeApp extends StatelessWidget {
  const FineTimeApp({super.key});
  @override
  Widget build(BuildContext context) =>
      MaterialApp(title: 'FineTime', debugShowCheckedModeBanner: false, theme: FT.theme(), home: const RootScreen());
}
