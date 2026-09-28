import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReviewScreen extends StatefulWidget {
  final String businessId;
  final String businessName;
  const ReviewScreen({super.key, required this.businessId, required this.businessName});
  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  final sb = Supabase.instance.client;
  final _body = TextEditingController();
  int _rating = 5;
  bool _saving = false;

  Future<void> _submit() async {
    final user = sb.auth.currentUser;
    if (user == null) return;
    setState(() => _saving = true);
    try {
      await sb.from('reviews').upsert({
        'user_id': user.id,
        'business_id': widget.businessId,
        'rating': _rating,
        'body': _body.text.trim().isEmpty ? null : _body.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Review submitted.')),
        );
        Navigator.pop(context, true);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('A completed FineTime experience is required to review this place.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Write a review')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(widget.businessName,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 20),
            const Text('Your rating',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Row(
              children: List.generate(5, (i) => IconButton(
                onPressed: () => setState(() => _rating = i + 1),
                icon: Icon(i < _rating ? Icons.star : Icons.star_border,
                    color: const Color(0xFFC9A227), size: 32),
              )),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _body,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Review (optional)',
                hintText: 'Share what you experienced.',
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: Text(_saving ? 'Submitting…' : 'Submit review'),
            ),
          ],
        ),
      );
}
