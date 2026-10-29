// Widget tests for the RentIt app's main user flows.
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

    await tester.ensureVisible(find.text('Sony Alpha a7 III Camera Kit').first);
    await tester.tap(find.text('Sony Alpha a7 III Camera Kit').first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Explore search filters and restores matching listings', (
    tester,
  ) async {
    await tester.pumpWidget(RentItApp(listingService: _FakeListingService()));

    expect(find.text('RentIt'), findsWidgets);
    expect(find.text('Borrow more. Buy less.'), findsOneWidget);
    expect(find.text('Explore'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'no matching rental');
    await tester.pump();
    expect(find.text('No rentals found'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    expect(find.text('Sony Alpha a7 III Camera Kit'), findsWidgets);
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

    expect(find.text('Edit listing'), findsNothing);
    expect(find.text('Delete listing'), findsNothing);
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
    await tester.enterText(find.byType(TextField).at(2), '450');
    await tester.enterText(
      find.byKey(const Key('listing-security-deposit')),
      '1200',
    );
    await tester.enterText(
      find.byType(TextField).at(5),
      'Return clean\nKeep it dry',
    );
    await tester.enterText(find.byType(TextField).at(6), 'Quezon City');
    await tester.ensureVisible(find.text('Publish listing'));
    await tester.tap(find.text('Publish listing'));
    await tester.pumpAndSettle();

    expect(listingService.createdListings, hasLength(1));
    expect(listingService.createdListings.single.name, 'Test rental item');
    expect(listingService.createdListings.single.deposit, '₱1200');
    expect(listingService.createdListings.single.rules, [
      'Return clean',
      'Keep it dry',
    ]);
    expect(find.text('Test rental item'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tester.tap(find.text('Test rental item'));
    await tester.pumpAndSettle();
    expect(find.text('Edit listing'), findsOneWidget);
    expect(find.text('Delete listing'), findsOneWidget);

    await tester.tap(find.text('Edit listing'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).first,
      'Edited rental item',
    );
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(find.text('Edited rental item'), findsOneWidget);

    await tester.tap(find.text('Edited rental item'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete listing'));
    await tester.pumpAndSettle();
    expect(find.text('Delete listing?'), findsOneWidget);
    await tester.tap(find.text('Delete listing').last);
    await tester.pumpAndSettle();
    expect(listingService.deletedListingIds, ['published-test-id']);
    expect(find.text('Edited rental item'), findsNothing);
  });

  testWidgets('Activity cards open a detail dialog', (tester) async {
    await tester.pumpWidget(RentItApp(listingService: _FakeListingService()));
    await tester.tap(find.text('Activity').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sony Alpha a7 III Camera Kit'));
    await tester.pumpAndSettle();

    expect(find.text('Status: Pending'), findsOneWidget);
    expect(find.text('Requested for 3 days · ₱1,800 total'), findsNWidgets(2));
  });

  testWidgets('Activity displays persisted payment orders', (tester) async {
    await tester.pumpWidget(
      RentItApp(
        listingService: _FakeListingService(),
        ordersLoader: () async => [
          {
            'external_id': 'rentit-test-order',
            'product_name': 'Test rental item',
            'amount': 1500,
            'status': 'PAID',
            'listing_id': 'published-test-id',
            'created_at': '2026-10-29T12:00:00Z',
          },
        ],
      ),
    );
    await tester.tap(find.text('Activity').last);
    await tester.pumpAndSettle();

    expect(find.text('Test rental item'), findsOneWidget);
    expect(find.text('Paid'), findsWidgets);
    expect(find.textContaining('rentit-test-order'), findsOneWidget);
  });

  testWidgets('Pending persisted order can be confirmed', (tester) async {
    await _openPersistedOrder(tester, 'Pending');

    expect(find.text('Confirm rental'), findsOneWidget);
    expect(find.byTooltip('Delete activity'), findsWidgets);
  });

  testWidgets('Confirmed persisted order can be completed or refunded', (
    tester,
  ) async {
    await _openPersistedOrder(tester, 'Confirmed');

    expect(find.text('Mark completed'), findsOneWidget);
    expect(find.text('Request a refund'), findsOneWidget);
  });

  testWidgets('Completed persisted order can be refunded and reviewed', (
    tester,
  ) async {
    await _openPersistedOrder(tester, 'Completed');

    expect(find.text('Request a refund'), findsOneWidget);
    expect(find.text('Write a review'), findsWidgets);
  });

  testWidgets('Activity reloads orders when returning to its tab', (
    tester,
  ) async {
    var orderCount = 0;
    await tester.pumpWidget(
      RentItApp(
        listingService: _FakeListingService(),
        ordersLoader: () async => List.generate(
          orderCount,
          (index) => {
            'external_id': 'rentit-order-$index',
            'product_name': 'Persisted order $index',
            'amount': 1500,
            'status': 'PENDING',
            'listing_id': 'published-test-id',
            'created_at': '2026-10-29T12:00:00Z',
          },
        ),
      ),
    );
    await tester.tap(find.text('Activity').last);
    await tester.pumpAndSettle();
    expect(find.text('Persisted order 0'), findsNothing);

    orderCount = 1;
    await tester.tap(find.text('Explore').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Activity').last);
    await tester.pumpAndSettle();

    expect(find.text('Persisted order 0'), findsOneWidget);
  });

  testWidgets('Activity can be searched and filtered by status', (
    tester,
  ) async {
    await tester.pumpWidget(RentItApp(listingService: _FakeListingService()));
    await tester.tap(find.text('Activity').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, 'Bosch');
    await tester.pumpAndSettle();
    expect(find.text('Bosch Cordless Drill'), findsOneWidget);
    expect(find.text('Sony Alpha a7 III Camera Kit'), findsNothing);

    await tester.enterText(find.byType(TextField).last, '');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Completed'));
    await tester.pumpAndSettle();
    expect(find.text('Bosch Cordless Drill'), findsOneWidget);
    expect(find.text('Nintendo Switch OLED'), findsNothing);
  });

  testWidgets('Completed rentals can be reviewed', (tester) async {
    await tester.pumpWidget(RentItApp(listingService: _FakeListingService()));
    await tester.tap(find.text('Activity').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bosch Cordless Drill'));
    await tester.pumpAndSettle();

    expect(find.text('Write a review'), findsNWidgets(2));
    await tester.tap(find.text('Write a review').last);
    await tester.pumpAndSettle();
    expect(find.text('Review your rental'), findsOneWidget);

    await tester.tap(find.byTooltip('4 stars'));
    await tester.enterText(
      find.byType(TextField).last,
      'The drill worked great.',
    );
    await tester.tap(find.text('Submit review'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Your review · 4/5 · The drill worked great.'),
      findsOneWidget,
    );
    expect(find.text('Edit review'), findsOneWidget);

    await tester.tap(find.text('Explore').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Bosch Cordless Drill').first);
    await tester.tap(find.text('Bosch Cordless Drill').first);
    await tester.pumpAndSettle();
    expect(find.text('The drill worked great.'), findsOneWidget);
  });

  testWidgets('Activity status can move through simulated rental stages', (
    tester,
  ) async {
    await tester.pumpWidget(RentItApp(listingService: _FakeListingService()));
    await tester.tap(find.text('Activity').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sony Alpha a7 III Camera Kit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm rental'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sony Alpha a7 III Camera Kit'));
    await tester.pumpAndSettle();
    expect(find.text('Status: Confirmed'), findsOneWidget);
    await tester.tap(find.text('Mark completed'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sony Alpha a7 III Camera Kit'));
    await tester.pumpAndSettle();
    expect(find.text('Status: Completed'), findsOneWidget);
    await tester.tap(find.text('Request a refund'));
    await tester.pumpAndSettle();
    expect(find.text('Refund requested'), findsNWidgets(2));
  });

  testWidgets('Activity can open a chat with the listing owner', (
    tester,
  ) async {
    await tester.pumpWidget(RentItApp(listingService: _FakeListingService()));
    await tester.tap(find.text('Activity').last);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Message owner').first);
    await tester.pumpAndSettle();
    expect(find.text('John Doe'), findsOneWidget);
    expect(find.text('Sony Alpha a7 III Camera Kit'), findsOneWidget);
  });

  testWidgets('Activity entries can be deleted after confirmation', (
    tester,
  ) async {
    await tester.pumpWidget(RentItApp(listingService: _FakeListingService()));
    await tester.tap(find.text('Activity').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Delete activity').first);
    await tester.pumpAndSettle();
    expect(find.text('Delete activity?'), findsOneWidget);

    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    expect(find.text('Sony Alpha a7 III Camera Kit'), findsNothing);
    expect(find.text('Nintendo Switch OLED'), findsOneWidget);
  });

  testWidgets('Profile information can be edited', (tester) async {
    await tester.pumpWidget(RentItApp(listingService: _FakeListingService()));
    await tester.tap(find.text('Profile').last);
    await tester.pumpAndSettle();
    expect(find.text('Payments & payouts'), findsNothing);
    await tester.ensureVisible(find.text('Log out'));
    await tester.tap(find.text('Log out'));
    await tester.pump();
    expect(find.text('You have been logged out.'), findsOneWidget);

    await tester.tap(find.byTooltip('Edit profile'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Alex Smith');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Alex Smith'), findsOneWidget);
  });
}

Future<void> _openPersistedOrder(WidgetTester tester, String status) async {
  await tester.pumpWidget(
    RentItApp(
      listingService: _FakeListingService(),
      ordersLoader: () async => [
        {
          'external_id': 'rentit-${status.toLowerCase()}',
          'product_name': 'Persisted $status rental',
          'amount': 1500,
          'status': 'PAID',
          'rental_status': status,
          'listing_id': 'published-test-id',
          'created_at': '2026-10-29T12:00:00Z',
        },
      ],
    ),
  );
  await tester.tap(find.text('Activity').last);
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Persisted $status rental'));
  await tester.tap(find.text('Persisted $status rental'));
  await tester.pumpAndSettle();
}

class _FakeListingService extends ListingService {
  final List<RentalListing> createdListings = [];
  final List<String> deletedListingIds = [];

  @override
  String? get currentUserId => 'test-owner-id';

  @override
  Future<List<RentalListing>> fetchListings() async => [];

  @override
  Future<RentalListing> createListing(RentalListing listing) async {
    createdListings.add(listing);
    return listing.copyWith(id: 'published-test-id', ownerId: currentUserId);
  }

  @override
  Future<void> deleteListing(String listingId) async {
    deletedListingIds.add(listingId);
  }
}
