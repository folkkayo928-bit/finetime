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

  try {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabaseAnonKey,
    );
    ErrorWidget.builder = (details) => const _RuntimeErrorScreen();
    runApp(const FineTimeApp());
  } catch (error) {
    runApp(FineTimeApp(startupError: error.toString()));
  }
}

class FineTimeApp extends StatelessWidget {
  final bool configurationError;
  final String? startupError;
  const FineTimeApp({super.key, this.configurationError = false, this.startupError});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'FineTime',
        debugShowCheckedModeBanner: false,
        theme: FT.theme(),
        home: configurationError
            ? const _ConfigurationErrorScreen()
            : startupError != null
                ? _StartupErrorScreen(message: startupError!)
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

class _StartupErrorScreen extends StatelessWidget {
  final String message;
  const _StartupErrorScreen({required this.message});

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
                const Text('FineTime could not start.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: FT.ivory,
                        fontSize: 20,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                const Text(
                  'The connection setup failed before the app loaded. Please refresh and try again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, height: 1.4),
                ),
                const SizedBox(height: 18),
                SelectableText(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      );
}

class _RuntimeErrorScreen extends StatelessWidget {
  const _RuntimeErrorScreen();

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
                const Text('Something went wrong while loading this screen.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: FT.ivory,
                        fontSize: 19,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                const Text(
                  'Please refresh the page. Your FineTime account and data have not been changed.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, height: 1.4),
                ),
              ],
            ),
          ),
        ),
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
