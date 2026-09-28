import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OrderFoodScreen extends StatefulWidget {
  final Map<String, dynamic> business;
  final List<Map<String, dynamic>> menuCategories;
  const OrderFoodScreen({super.key, required this.business, required this.menuCategories});
  @override
  State<OrderFoodScreen> createState() => _OrderFoodScreenState();
}

class _OrderFoodScreenState extends State<OrderFoodScreen> {
  final sb = Supabase.instance.client;
  final Map<String, int> _cart = {};
  final _table = TextEditingController();
  final _note = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _table.dispose();
    _note.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _items => widget.menuCategories
      .expand((c) => ((c['menu_items'] ?? []) as List).map((i) => Map<String, dynamic>.from(i)))
      .where((i) => i['is_available'] != false && i['price'] != null)
      .toList();

  double get _total {
    double total = 0;
    for (final item in _items) {
      final qty = _cart[item['id']?.toString()] ?? 0;
      total += (num.tryParse(item['price'].toString()) ?? 0) * qty;
    }
    return total;
  }

  int get _count => _cart.values.fold(0, (a, b) => a + b);

  Future<void> _submit() async {
    final user = sb.auth.currentUser;
    if (user == null) {
      _message('Please sign in first.');
      return;
    }
    if (_count == 0) {
      _message('Add at least one item.');
      return;
    }

    setState(() => _saving = true);
    try {
      final payload = _items
          .where((i) => (_cart[i['id']?.toString()] ?? 0) > 0)
          .map((i) => {
                'menu_item_id': i['id'],
                'name': i['name'],
                'unit_price': num.tryParse(i['price'].toString()) ?? 0,
                'quantity': _cart[i['id']?.toString()] ?? 0,
              })
          .toList();

      final result = await sb.rpc('create_food_order', params: {
        'p_business_id': widget.business['id'],
        'p_items': payload,
        'p_table_number': _table.text.trim().isEmpty ? null : _table.text.trim(),
        'p_customer_note': _note.text.trim().isEmpty ? null : _note.text.trim(),
      });
      final rows = List<Map<String, dynamic>>.from(result as List);
      if (rows.isEmpty) throw Exception('The business could not accept this order.');

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Order submitted'),
          content: const Text(
              'Your order was sent to the business. You will see status updates in Notifications when the partner responds.'),
          actions: [
            FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
          ],
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _message('Could not submit the order: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('Order · ${widget.business['name'] ?? ''}')),
        body: _items.isEmpty
            ? const Center(child: Text('No orderable menu items are available yet.'))
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
                children: [
                  Text('Choose from the menu',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _table,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Table number (optional)',
                      hintText: 'For dine-in orders',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _note,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Order note (optional)',
                      hintText: 'Special instructions or details',
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._items.map((item) {
                    final id = item['id']?.toString();
                    final qty = _cart[id] ?? 0;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(item['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(item['description']?.toString() ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
                        trailing: SizedBox(
                          width: 126,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                onPressed: qty == 0 ? null : () => setState(() {
                                  if (qty <= 1) {
                                    _cart.remove(id);
                                  } else {
                                    _cart[id!] = qty - 1;
                                  }
                                }),
                                icon: const Icon(Icons.remove_circle_outline),
                              ),
                              Text('$qty', style: const TextStyle(fontWeight: FontWeight.w800)),
                              IconButton(
                                onPressed: () => setState(() => _cart[id!] = qty + 1),
                                icon: const Icon(Icons.add_circle_outline),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: FilledButton(
              onPressed: _saving ? null : _submit,
              child: Text(_saving
                  ? 'Submitting…'
                  : 'Submit $_count item${_count == 1 ? '' : 's'} · ETB ${_total.toStringAsFixed(2)}'),
            ),
          ),
        ),
      );
}
