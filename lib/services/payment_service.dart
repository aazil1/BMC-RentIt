
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/product_model.dart';

class PaymentService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<Product>> fetchProducts() async {
    final products = await _client.from('products').select();

    return products
        .map((product) => Product.fromMap(product))
        .toList();
  }

  Future<Map<String, dynamic>> createInvoice(Product product) async {
    final response = await _client.functions.invoke(
      'create-invoice',
      body: {
        'product_id': product.id,
        'product_name': product.name,
        'amount': product.price,
      },
    );

    if (response.status < 200 || response.status >= 300) {
      throw Exception(
        'Invoice creation failed (${response.status}).',
      );
    }

    final data = response.data;

    if (data is! Map<String, dynamic> ||
        data['invoice_url'] is! String ||
        data['external_id'] is! String) {
      throw const FormatException(
        'Invoice response must include invoice_url and external_id.',
      );
    }

    return data;
  }

  Future<String> checkOrderStatus(String externalId) async {
    final order = await _client
        .from('orders')
        .select('status')
        .eq('external_id', externalId)
        .maybeSingle();

    if (order == null) {
      throw StateError(
        'No order found for external ID $externalId.',
      );
    }

    final status = order['status'];

    if (status is! String) {
      throw const FormatException(
        'Order status is missing or invalid.',
      );
    }

    return status;
  }
}
