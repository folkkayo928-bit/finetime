import 'package:flutter/material.dart';
import 'discover.dart';
import 'explore.dart';
import 'trips.dart';
import 'saved.dart';
import 'me.dart';

class RootScreen extends StatefulWidget {
  const RootScreen({super.key});
  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  int _i = 0;
  final _tabs = const [
    DiscoverScreen(),
    ExploreScreen(),
    TripsScreen(),
    SavedScreen(),
    MeScreen(),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
        body: _tabs[_i],
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0C0A06),
            border: Border(
              top: BorderSide(color: Color(0xFF221C16), width: 0.8),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 60,
              child: Row(
                children: [
                  _navItem(0, Icons.home_outlined, Icons.home_rounded, 'Home'),
                  _navItem(1, Icons.explore_outlined, Icons.explore_rounded, 'Explore'),
                  _navItem(2, Icons.business_center_outlined, Icons.business_center_rounded, 'Trips'),
                  _navItem(3, Icons.favorite_outline, Icons.favorite_rounded, 'Saved'),
                  _navItem(4, Icons.person_outline, Icons.person_rounded, 'Profile'),
                ],
              ),
            ),
          ),
        ),
      );

  Widget _navItem(int index, IconData outlineIcon, IconData filledIcon, String label) {
    final active = _i == index;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _i = index),
        child: Column(
          children: [
            Container(
              height: 2.5,
              width: 30,
              decoration: BoxDecoration(
                color: active ? const Color(0xFFE3A82D) : Colors.transparent,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(2)),
              ),
            ),
            const Spacer(),
            Icon(
              active ? filledIcon : outlineIcon,
              color: active ? const Color(0xFFE3A82D) : const Color(0xFF756F67),
              size: 23,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: active ? const Color(0xFFE3A82D) : const Color(0xFF756F67),
                fontSize: 10.5,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
