import 'dart:async';

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
  final _controller = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final q = value.trim();
    if (q.isEmpty) {
      setState(() {
        _results = [];
        _loading = false;
        _error = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(q));
  }

  Future<void> _search(String q) async {
    try {
      final rows = await sb
          .from('businesses')
          .select('id,name,category,cover_url')
          .eq('is_published', true)
          .ilike('name', '%$q%')
          .order('name')
          .limit(40);
      if (!mounted) return;
      setState(() {
        _results = List<Map<String, dynamic>>.from(rows);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _results = [];
        _loading = false;
        _error = 'Search is temporarily unavailable. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: TextField(
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.search,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            decoration: const InputDecoration(
              hintText: 'Search hotels, restaurants, cafés…',
              hintStyle: TextStyle(color: Colors.white54),
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
            ),
            onChanged: _onChanged,
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: () => _search(_controller.text.trim()),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                : _controller.text.trim().isEmpty
                    ? const Center(
                        child: Text(
                          'Search by a real FineTime business name.',
                          style: TextStyle(color: Colors.white54),
                        ),
                      )
                    : _results.isEmpty
                        ? const Center(
                            child: Text(
                              'No published places match your search.',
                              style: TextStyle(color: Colors.white54),
                            ),
                          )
                        : ListView.separated(
                            itemCount: _results.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (_, i) {
                              final b = _results[i];
                              return ListTile(
                                leading: Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: Colors.white10,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: b['cover_url'] != null
                                      ? Image.network(
                                          b['cover_url'],
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              const Icon(Icons.store),
                                        )
                                      : const Icon(Icons.store),
                                ),
                                title: Text(
                                  b['name'] ?? '',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                subtitle: Text(
                                  (b['category'] ?? '')
                                      .toString()
                                      .toUpperCase(),
                                  style:
                                      const TextStyle(color: Colors.white70),
                                ),
                                trailing: const Icon(
                                  Icons.chevron_right,
                                  color: Color(0xFFC9A227),
                                ),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => BusinessProfileScreen(
                                      businessId: b['id'],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
      );
}
