import 'dart:typed_data';

class RentalListing {
  final String id;
  final String name;
  final String category;
  final String ownerName;
  final String ownerAvatar;
  final String location;
  final String description;
  final String condition;
  final String imageUrl;
  final Uint8List? imageBytes;
  final String deposit;
  final int pricePerDay;
  final double rating;
  final bool isAvailable;
  final List<String> rules;
  final List<Review> reviews;

  const RentalListing({
    required this.id,
    required this.name,
    required this.category,
    required this.ownerName,
    required this.ownerAvatar,
    required this.location,
    required this.description,
    required this.condition,
    required this.imageUrl,
    this.imageBytes,
    required this.deposit,
    required this.pricePerDay,
    required this.rating,
    required this.isAvailable,
    required this.rules,
    required this.reviews,
  });

  RentalListing copyWith({String? id}) {
    return RentalListing(
      id: id ?? this.id,
      name: name,
      category: category,
      ownerName: ownerName,
      ownerAvatar: ownerAvatar,
      location: location,
      description: description,
      condition: condition,
      imageUrl: imageUrl,
      imageBytes: imageBytes,
      deposit: deposit,
      pricePerDay: pricePerDay,
      rating: rating,
      isAvailable: isAvailable,
      rules: rules,
      reviews: reviews,
    );
  }
}

class Review {
  final String reviewerName;
  final String comment;
  final double rating;

  const Review({
    required this.reviewerName,
    required this.comment,
    required this.rating,
  });
}
