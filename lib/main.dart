import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'theme.dart';
import 'update_checker.dart';
import 'screens/welcome.dart';
import 'screens/root.dart';

const defaultSupabaseUrl = 'https://atewcbkuzrnfnmzsylze.supabase.co';
const defaultSupabaseAnonKey = 'sb_publishable_CxfreIiozKEB-GcvNOCyhQ_RVnIgGVG';

const configuredSupabaseUrl = String.fromEnvironment('SUPABASE_URL');
const configuredSupabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

final supabaseUrl = configuredSupabaseUrl.isNotEmpty ? configuredSupabaseUrl : defaultSupabaseUrl;
final supabaseAnonKey = configuredSupabaseAnonKey.isNotEmpty ? configuredSupabaseAnonKey : defaultSupabaseAnonKey;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    runApp(const FineTimeApp(configurationError: true));
    return;
  }

  await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseAnonKey);
  runApp(const FineTimeApp());
}

class FineTimeApp extends StatelessWidget {
  final bool configurationError;
  const FineTimeApp({super.key, this.configurationError = false});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'FineTime',
        debugShowCheckedModeBanner: false,
        theme: FT.theme(),
        home: configurationError
            ? const _ConfigurationErrorScreen()
            : const FineTimeUpdateGate(child: AuthGate()),
      );
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) => StreamBuilder<AuthState>(
        stream: Supabase.instance.client.auth.onAuthStateChange,
        builder: (context, snapshot) {
          final session = snapshot.data?.session ?? Supabase.instance.client.auth.currentSession;
          if (session != null) {
            return const RootScreen();
          }
          return const WelcomeScreen();
        },
      );
}

class _ConfigurationErrorScreen extends StatelessWidget {
  const _ConfigurationErrorScreen();

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: FT.charcoal,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('FINETIME',
                    style: TextStyle(
                        color: FT.gold,
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 3)),
                const SizedBox(height: 16),
                const Text('Configuration is missing.',
                    style: TextStyle(
                        color: FT.ivory,
                        fontSize: 20,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                const Text(
                  'The app was built without SUPABASE_URL and SUPABASE_ANON_KEY. Configure the GitHub Actions secrets and rebuild.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, height: 1.4),
                ),
              ],
            ),
          ),
        ),
      );
}
