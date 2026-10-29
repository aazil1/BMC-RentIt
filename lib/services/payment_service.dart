// Creates rental payment invoices and provides demo products.
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../models/product_model.dart';

class PaymentService {
  List<Product> _demoProducts() => [
    Product(
      id: 1,
      name: 'Sony Alpha a7 III Camera Kit',
      price: 600,
      imageUrl: 'https://images.unsplash.com/photo-1516035069371-29a1b244cc32?auto=format&fit=crop&w=900&q=80',
    ),
    Product(
      id: 2,
      name: 'Nintendo Switch OLED',
      price: 280,
      imageUrl: 'https://images.unsplash.com/photo-1606144042614-b2417e99c4e3?auto=format&fit=crop&w=900&q=80',
    ),
    Product(
      id: 3,
      name: 'Bosch Cordless Drill',
      price: 220,
      imageUrl: 'https://images.unsplash.com/photo-1504148455328-c376907d081c?auto=format&fit=crop&w=900&q=80',
    ),
  ];

  Future<List<Product>> fetchProducts() async {
    if (!AppConfig.isSupabaseConfigured) {
      return _demoProducts();
    }

    try {
      await AppConfig.initializeSupabase();
      final products = await Supabase.instance.client.from('products').select();
      return products.map((product) => Product.fromMap(product)).toList();
    } catch (_) {
      return _demoProducts();
    }
  }

  Future<Map<String, dynamic>> createInvoice(Product product) {
    return _invokeInvoice({'product_id': product.id});
  }

  Future<Map<String, dynamic>> createRentalInvoice({
    required String listingId,
    required int days,
  }) {
    return _invokeInvoice({'listing_id': listingId, 'days': days});
  }

  Future<List<Map<String, dynamic>>> fetchMyOrders() async {
    await AppConfig.initializeSupabase();
    final userId = await _ensureUser();
    final result = await Supabase.instance.client
        .from('orders')
        .select(
          'external_id, product_name, amount, status, listing_id, product_id, created_at',
        )
        .eq('owner_id', userId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(result);
  }

  Future<Map<String, dynamic>> _invokeInvoice(
    Map<String, dynamic> requestBody,
  ) async {
    await AppConfig.initializeSupabase();
    await _ensureUser();

    late final FunctionResponse response;
    try {
      response = await Supabase.instance.client.functions.invoke(
        'create-invoice',
        body: requestBody,
      );
    } on FunctionException catch (error) {
      final details = error.details;
      final message = details is Map && details['error'] is String
          ? [
              details['error'] as String,
              if (details['details'] is String) details['details'] as String,
            ].join(': ')
          : details?.toString() ?? error.reasonPhrase ?? 'Unknown server error';
      throw Exception('Invoice creation failed (${error.status}): $message');
    }
    final data = response.data;

    if (response.status < 200 || response.status >= 300) {
      throw Exception('Invoice creation failed (${response.status}): $data');
    }

    if (data is! Map<String, dynamic> ||
        data['invoice_url'] is! String ||
        data['external_id'] is! String) {
      throw const FormatException(
        'Invoice response must include invoice_url and external_id.',
      );
    }

    final invoiceUri = Uri.tryParse(data['invoice_url'] as String);
    if (invoiceUri == null ||
        invoiceUri.scheme != 'https' ||
        invoiceUri.host.isEmpty) {
      throw const FormatException('Invoice URL must be a valid HTTPS URL.');
    }

    return data;
  }

  Future<String> checkOrderStatus(String externalId) async {
    await AppConfig.initializeSupabase();
    await _ensureUser();

    final response = await Supabase.instance.client.functions.invoke(
      'get-order-status',
      body: {'external_id': externalId},
    );
    final data = response.data;

    if (response.status < 200 || response.status >= 300) {
      throw Exception(
        'Could not retrieve payment status (${response.status}).',
      );
    }
    if (data is! Map<String, dynamic> || data['status'] is! String) {
      throw const FormatException('Order status response is invalid.');
    }

    return data['status'] as String;
  }

  Future<String> _ensureUser() async {
    final client = Supabase.instance.client;
    final existingUser = client.auth.currentUser;
    if (existingUser != null) return existingUser.id;

    final response = await client.auth.signInAnonymously();
    final userId = response.user?.id;
    if (userId == null) {
      throw const FormatException('Supabase did not create an owner identity.');
    }
    return userId;
  }
}
