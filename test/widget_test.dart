import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:student_shop/main.dart';
import 'package:student_shop/models/rental_listing.dart';
import 'package:student_shop/services/listing_service.dart';

void main() {
  testWidgets('Explore listing cards fit narrow screens', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(RentItApp(listingService: _FakeListingService()));

    expect(tester.takeException(), isNull);
  });

  testWidgets('RentIt app loads and clears Explore filters', (tester) async {
    await tester.pumpWidget(RentItApp(listingService: _FakeListingService()));

    expect(find.text('RentIt'), findsWidgets);
    expect(find.text('Borrow more. Buy less.'), findsOneWidget);
    expect(find.text('Explore'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'no matching rental');
    await tester.pump();
    expect(find.text('No rentals found'), findsOneWidget);

    await tester.ensureVisible(find.text('Clear filters'));
    await tester.tap(find.text('Clear filters'));
    await tester.pump();
    expect(find.text('6 items'), findsOneWidget);
  });

  testWidgets('Inbox starts empty and only lists chats after a message', (
    tester,
  ) async {
    await tester.pumpWidget(RentItApp(listingService: _FakeListingService()));

    await tester.tap(find.text('Inbox').last);
    await tester.pumpAndSettle();
    expect(find.text('No conversations yet'), findsOneWidget);
    expect(find.text('Maria Santos'), findsNothing);

    await tester.tap(find.text('Explore').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Sony Alpha a7 III Camera Kit').first);
    await tester.tap(find.text('Sony Alpha a7 III Camera Kit').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Message Owner'));
    await tester.tap(find.text('Message Owner'));
    await tester.pumpAndSettle();
    expect(find.text('John Doe'), findsOneWidget);
    expect(
      find.text('Hi! Is the camera available this weekend?'),
      findsNothing,
    );

    await tester.enterText(find.byType(TextField), 'Hello, is this available?');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();
    expect(find.text('Hello, is this available?'), findsOneWidget);

    Navigator.of(tester.element(find.byType(ChatScreen))).pop();
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.byType(ListingDetailScreen))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Inbox').last);
    await tester.pumpAndSettle();
    expect(find.text('John Doe'), findsOneWidget);
    expect(find.text('Hello, is this available?'), findsOneWidget);
  });

  testWidgets('Rental booking summary does not simulate checkout', (
    tester,
  ) async {
    await tester.pumpWidget(RentItApp(listingService: _FakeListingService()));

    await tester.ensureVisible(find.text('Sony Alpha a7 III Camera Kit').first);
    await tester.tap(find.text('Sony Alpha a7 III Camera Kit').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Rent Now'));
    await tester.tap(find.text('Rent Now'));
    await tester.pumpAndSettle();

    expect(find.text('Review and pay'), findsOneWidget);
    expect(find.textContaining('Pay now · ₱'), findsOneWidget);
    expect(find.text('Sandbox payment simulation'), findsNothing);
  });

  testWidgets('Booked rentals cannot open checkout', (tester) async {
    await tester.pumpWidget(RentItApp(listingService: _FakeListingService()));

    await tester.ensureVisible(find.text('Coleman Camping Tent'));
    await tester.tap(find.text('Coleman Camping Tent'));
    await tester.pumpAndSettle();

    final bookedButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Booked'),
    );
    expect(bookedButton.onPressed, isNull);
  });

  testWidgets('Saved listings appear in the profile saved-items dialog', (
    tester,
  ) async {
    await tester.pumpWidget(RentItApp(listingService: _FakeListingService()));

    await tester.ensureVisible(find.text('Sony Alpha a7 III Camera Kit').first);
    await tester.tap(find.text('Sony Alpha a7 III Camera Kit').first);
    await tester.pumpAndSettle();
    expect(find.text('No reviews yet.'), findsOneWidget);
    await tester.tap(find.byTooltip('Save item'));
    await tester.pump();
    expect(find.byTooltip('Remove from saved items'), findsOneWidget);
    Navigator.of(tester.element(find.byType(ListingDetailScreen))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profile').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saved items'));
    await tester.pumpAndSettle();

    expect(find.text('Sony Alpha a7 III Camera Kit'), findsOneWidget);
  });

  testWidgets('Published listings are added to Explore', (tester) async {
    final listingService = _FakeListingService();
    await tester.pumpWidget(RentItApp(listingService: listingService));
    await tester.tap(find.text('List Item').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'Test rental item');
    await tester.enterText(find.byType(TextField).at(1), 'Quezon City');
    await tester.enterText(find.byType(TextField).at(2), '450');
    await tester.ensureVisible(find.text('Publish listing'));
    await tester.tap(find.text('Publish listing'));
    await tester.pumpAndSettle();

    expect(listingService.createdListings, hasLength(1));
    expect(listingService.createdListings.single.name, 'Test rental item');
    expect(find.text('Test rental item'), findsOneWidget);
  });

  testWidgets('Activity cards open a detail dialog', (tester) async {
    await tester.pumpWidget(RentItApp(listingService: _FakeListingService()));
    await tester.tap(find.text('Activity').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sony Alpha a7 III Camera Kit'));
    await tester.pumpAndSettle();

    expect(find.text('Status: Pending approval'), findsOneWidget);
    expect(find.text('Requested for 3 days · ₱1,800 total'), findsNWidgets(2));
  });

  testWidgets('Profile information can be edited', (tester) async {
    await tester.pumpWidget(RentItApp(listingService: _FakeListingService()));
    await tester.tap(find.text('Profile').last);
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsNothing);
    expect(find.text('Log out'), findsNothing);
    await tester.tap(find.byTooltip('Edit profile'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Alex Smith');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Alex Smith'), findsOneWidget);
  });
}

class _FakeListingService extends ListingService {
  final List<RentalListing> createdListings = [];

  @override
  Future<List<RentalListing>> fetchListings() async => [];

  @override
  Future<RentalListing> createListing(RentalListing listing) async {
    createdListings.add(listing);
    return listing.copyWith(id: 'published-test-id');
  }
}
