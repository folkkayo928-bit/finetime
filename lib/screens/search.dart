import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'business_profile.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final sb = Supabase.instance.client;
  List _results = [];

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) return setState(() => _results = []);
    final r = await sb.from('businesses').select().eq('is_published', true).ilike('name', '%$q%');
    setState(() => _results = r);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: TextField(
      autofocus: true,
      decoration: const InputDecoration(hintText: 'Search places…', filled: false),
      onChanged: _search)),
    body: ListView(children: _results.map((b) => ListTile(
      title: Text(b['name']),
      subtitle: Text(b['category'].toString().toUpperCase()),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BusinessProfileScreen(businessId: b['id'])))).toList()));
}
