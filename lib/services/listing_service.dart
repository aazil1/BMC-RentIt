// Creates and fetches rental listings through Supabase.
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../models/rental_listing.dart';

class ListingService {
  static const _imageBucket = 'listing-images';

  Future<RentalListing> createListing(RentalListing listing) async {
    await AppConfig.initializeSupabase();
    var imageUrl = listing.imageUrl;
    if (listing.imageBytes != null) {
      final (extension, contentType) = _imageFormat(listing.imageBytes!);
      final imagePath = 'listings/${listing.id}.$extension';
      final client = Supabase.instance.client;
      await client.storage
          .from(_imageBucket)
          .uploadBinary(
            imagePath,
            listing.imageBytes!,
            fileOptions: FileOptions(contentType: contentType),
          );
      imageUrl = client.storage.from(_imageBucket).getPublicUrl(imagePath);
    }

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
          'image_url': imageUrl.isEmpty ? null : imageUrl,
        })
        .select('id')
        .single();
    final id = row['id'];
    if (id is! String || id.isEmpty) {
      throw const FormatException('Supabase did not return a listing ID.');
    }
    return listing.copyWith(id: id, imageUrl: imageUrl);
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

  (String, String) _imageFormat(Uint8List bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return ('jpg', 'image/jpeg');
    }
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0D &&
        bytes[5] == 0x0A &&
        bytes[6] == 0x1A &&
        bytes[7] == 0x0A) {
      return ('png', 'image/png');
    }
    if (bytes.length >= 12 &&
        String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
        String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
      return ('webp', 'image/webp');
    }
    if (bytes.length >= 6) {
      final signature = String.fromCharCodes(bytes.sublist(0, 6));
      if (signature == 'GIF87a' || signature == 'GIF89a') {
        return ('gif', 'image/gif');
      }
    }
    throw const FormatException('The selected photo format is not supported.');
  }

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
