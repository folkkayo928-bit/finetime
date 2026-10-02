import 'package:flutter/material.dart';
import '../theme.dart';
import 'auth.dart';
import 'root.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: FT.obsidian,
      body: Stack(
        children: [
          // Background Hero Artwork with Gradient Fade
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: size.height * 0.56,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/welcome_hero.png',
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  errorBuilder: (_, __, ___) => Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF33484B), Color(0xFF1B1815)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
                // Gradient overlay to seamlessly merge into obsidian background
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withValues(alpha: 0.35),
                        Colors.black.withValues(alpha: 0.15),
                        FT.obsidian.withValues(alpha: 0.85),
                        FT.obsidian,
                      ],
                      stops: const [0.0, 0.45, 0.82, 1.0],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content Layer
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: topPadding > 0 ? 8 : 16),

                  // Header Brand (FINETIME.CC - Discover. Dine. Stay.)
                  Column(
                    children: [
                      const Text(
                        'FINETIME.CC',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: FT.ivory,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4.0,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildDot(),
                          Text(
                            'Discover',
                            style: TextStyle(
                              color: FT.cream,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.5,
                            ),
                          ),
                          _buildDot(),
                          Text(
                            'Dine',
                            style: TextStyle(
                              color: FT.cream,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.5,
                            ),
                          ),
                          _buildDot(),
                          Text(
                            'Stay',
                            style: TextStyle(
                              color: FT.cream,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.5,
                            ),
                          ),
                          _buildDot(),
                        ],
                      ),
                    ],
                  ),

                  const Spacer(),

                  // Editorial Section (Figma Match)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: FT.gold.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: FT.gold.withValues(alpha: 0.3), width: 1),
                        ),
                        child: const Text(
                          'ETHIOPIA, BEAUTIFULLY CURATED',
                          style: TextStyle(
                            color: FT.gold,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Exceptional stays.',
                        style: TextStyle(
                          color: FT.ivory,
                          fontSize: 34,
                          fontWeight: FontWeight.w700,
                          height: 1.15,
                          fontFamily: 'serif',
                          letterSpacing: -0.5,
                        ),
                      ),
                      const Text(
                        'Unforgettable tables.',
                        style: TextStyle(
                          color: FT.ivory,
                          fontSize: 34,
                          fontWeight: FontWeight.w700,
                          height: 1.15,
                          fontFamily: 'serif',
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Primary CTA Button: Glowing Gold Pill
                  GestureDetector(
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const RootScreen()),
                      );
                    },
                    child: Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: FT.goldGradient,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: FT.gold.withValues(alpha: 0.35),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Get started',
                            style: TextStyle(
                              color: Color(0xFF1E1607),
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            '—',
                            style: TextStyle(
                              color: Color(0xFF1E1607),
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Secondary Link: Sign In
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AuthScreen(startWithSignIn: true)),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(fontSize: 14, color: FT.cream),
                          children: const [
                            TextSpan(text: 'Already a member? '),
                            TextSpan(
                              text: 'Sign in',
                              style: TextStyle(
                                color: FT.gold,
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.underline,
                                decorationColor: FT.gold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: bottomPadding > 0 ? 6 : 14),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildDot() => Container(
        margin: const EdgeInsets.symmetric(horizontal: 7),
        width: 3.5,
        height: 3.5,
        decoration: const BoxDecoration(
          color: FT.gold,
          shape: BoxShape.circle,
        ),
      );
}
