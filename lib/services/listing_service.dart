import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../models/rental_listing.dart';

class ListingService {
  Future<RentalListing> createListing(RentalListing listing) async {
    await AppConfig.initializeSupabase();
    final row = await Supabase.instance.client
        .from('rental_listings')
        .insert({
          'name': listing.name,
          'category': listing.category,
          'owner_name': listing.ownerName,
          'location': listing.location,
          'description': listing.description,
          'condition': listing.condition,
          'price_per_day': listing.pricePerDay,
          'deposit': _depositAmount(listing.deposit),
          'available': listing.isAvailable,
          'rules': listing.rules,
          'image_url': listing.imageUrl.isEmpty ? null : listing.imageUrl,
        })
        .select('id')
        .single();
    final id = row['id'];
    if (id is! String || id.isEmpty) {
      throw const FormatException('Supabase did not return a listing ID.');
    }
    return listing.copyWith(id: id);
  }

  Future<List<RentalListing>> fetchListings() async {
    await AppConfig.initializeSupabase();
    final rows = await Supabase.instance.client
        .from('rental_listings')
        .select(
          'id, name, category, owner_name, location, description, condition, '
          'price_per_day, deposit, available, rules, image_url',
        )
        .eq('available', true)
        .order('created_at', ascending: false);
    return rows.map(_listingFromRow).toList();
  }

  int _depositAmount(String value) =>
      int.tryParse(value.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

  RentalListing _listingFromRow(Map<String, dynamic> row) {
    final rules = row['rules'];
    return RentalListing(
      id: row['id'] as String,
      name: row['name'] as String,
      category: row['category'] as String,
      ownerName: row['owner_name'] as String,
      ownerAvatar: (row['owner_name'] as String)
          .trim()
          .split(RegExp(r'\s+'))
          .take(2)
          .map((part) => part.isEmpty ? '' : part[0])
          .join()
          .toUpperCase(),
      location: row['location'] as String,
      description: row['description'] as String? ?? '',
      condition: row['condition'] as String? ?? 'Not specified',
      imageUrl: row['image_url'] as String? ?? '',
      deposit: '₱${(row['deposit'] as num).round()}',
      pricePerDay: (row['price_per_day'] as num).round(),
      rating: 0,
      isAvailable: row['available'] as bool? ?? true,
      rules: rules is List
          ? rules.map((rule) => rule.toString()).toList()
          : const [],
      reviews: const [],
    );
  }
}
