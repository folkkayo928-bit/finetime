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
  final _tabs = const [DiscoverScreen(), ExploreScreen(), TripsScreen(), SavedScreen(), MeScreen()];
  @override
  Widget build(BuildContext context) => Scaffold(
    body: _tabs[_i],
    bottomNavigationBar: BottomNavigationBar(
      currentIndex: _i,
      onTap: (v) => setState(() => _i = v),
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.explore_outlined), label: 'Discover'),
        BottomNavigationBarItem(icon: Icon(Icons.map_outlined), label: 'Explore'),
        BottomNavigationBarItem(icon: Icon(Icons.luggage_outlined), label: 'Trips'),
        BottomNavigationBarItem(icon: Icon(Icons.favorite_border), label: 'Saved'),
        BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Me'),
      ],
    ),
  );
}
