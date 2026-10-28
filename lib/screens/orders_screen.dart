// Displays orders fetched from Supabase.
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  Future<List<Map<String, dynamic>>> _fetchOrders() async {
    final result = await Supabase.instance.client
        .from('orders')
        .select()
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Order History')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchOrders(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final orders = snapshot.data ?? [];
          if (orders.isEmpty) {
            return const Center(child: Text('No orders found.'));
          }

          return ListView.builder(
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              final id = order['external_id'] ?? order['id'] ?? 'Unknown';
              final status = order['status'] ?? 'Unknown';
              final amount = order['amount'] ?? order['price'];

              return ListTile(
                title: Text('Order $id'),
                subtitle: Text(
                  amount == null
                      ? 'Status: $status'
                      : 'Amount: $amount · Status: $status',
                ),
              );
            },
          );
        },
      ),
    );
  }
}
