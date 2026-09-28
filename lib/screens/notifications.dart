import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final sb = Supabase.instance.client;
  List _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final u = sb.auth.currentUser;
    if (u == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    setState(() => _error = null);
    try {
      final r = await sb
          .from('notifications')
          .select()
          .eq('user_id', u.id)
          .order('created_at', ascending: false);
      if (mounted) setState(() { _items = r; _loading = false; });
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Could not load notifications. Check your connection.';
          _loading = false;
        });
      }
    }
  }

  String _dateLabel(dynamic value) {
    final raw = value?.toString() ?? '';
    if (raw.length >= 10) return raw.substring(0, 10);
    return '';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Notifications')),
    body: _loading
      ? const Center(child: CircularProgressIndicator())
      : _error != null
        ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_error!),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ]))
        : _items.isEmpty
          ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.notifications_none, size: 56, color: Colors.white38),
              SizedBox(height: 12),
              Text("You're all caught up."),
            ]))
          : RefreshIndicator(
            onRefresh: _load,
            child: ListView.builder(
              itemCount: _items.length,
              itemBuilder: (_, i) {
                final n = _items[i];
                return ListTile(
                  leading: Icon(n['is_read'] == true
                      ? Icons.mark_email_read_outlined
                      : Icons.notifications_active, color: const Color(0xFFC6A664)),
                  title: Text(n['title'] ?? '', style: TextStyle(fontWeight: n['is_read'] == true ? FontWeight.w400 : FontWeight.w700)),
                  subtitle: Text(n['body'] ?? ''),
                  trailing: Text(_dateLabel(n['created_at']), style: const TextStyle(fontSize: 11)),
                  onTap: () async {
                    if (n['is_read'] != true) {
                      await sb.from('notifications').update({'is_read': true}).eq('id', n['id']);
                      if (mounted) setState(() => _items[i]['is_read'] = true);
                    }
                  },
                );
              },
            ),
          ),
  );
}
