import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'config/app_config.dart';
import 'data/sample_data.dart';
import 'models/chat_models.dart';
import 'models/rental_listing.dart';
import 'screens/xendit_webview_screen.dart';
import 'services/listing_service.dart';
import 'services/payment_service.dart';

Widget _listingImage(
  RentalListing listing, {
  required double height,
  double? width,
}) {
  if (listing.imageBytes != null) {
    return Image.memory(
      listing.imageBytes!,
      height: height,
      width: width,
      fit: BoxFit.cover,
    );
  }
  if (listing.imageUrl.isEmpty) {
    return _imagePlaceholder(height: height, width: width);
  }
  return Image.network(
    listing.imageUrl,
    height: height,
    width: width,
    fit: BoxFit.cover,
    errorBuilder: (_, __, ___) =>
        _imagePlaceholder(height: height, width: width),
  );
}

Widget _imagePlaceholder({required double height, double? width}) {
  return Container(
    height: height,
    width: width,
    color: const Color(0xFFE7D4C0),
    child: const Center(
      child: Icon(
        Icons.image_not_supported_rounded,
        size: 50,
        color: Color(0xFF8B5A38),
      ),
    ),
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (AppConfig.isSupabaseConfigured) {
    await AppConfig.initializeSupabase();
  }

  runApp(const RentItApp());
}

class RentItApp extends StatelessWidget {
  const RentItApp({super.key, this.listingService});

  final ListingService? listingService;

  @override
  Widget build(BuildContext context) {
    const warmBrown = Color(0xFF211A16);
    const orange = Color(0xFFF4510B);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'RentIt',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF6F1EB),
        colorScheme: ColorScheme.fromSeed(
          seedColor: orange,
          primary: orange,
          secondary: const Color(0xFF542B12),
          surface: const Color(0xFFFFFBF7),
          onSurface: const Color(0xFF211A16),
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: warmBrown,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(
            color: Color(0xFF221B18),
            fontWeight: FontWeight.w700,
          ),
          titleMedium: TextStyle(
            color: Color(0xFF221B18),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      home: RentItHome(listingService: listingService),
    );
  }
}

class RentItHome extends StatefulWidget {
  const RentItHome({super.key, this.listingService});

  final ListingService? listingService;

  @override
  State<RentItHome> createState() => _RentItHomeState();
}

class _RentItHomeState extends State<RentItHome> {
  late final ListingService _listingService =
      widget.listingService ?? ListingService();
  int _currentIndex = 0;
  final List<Conversation> _conversations = [];
  final List<RentalListing> _listings = List.of(sampleListings);
  final Set<String> _savedListingIds = {};
  String _profileName = 'John Doe';
  String _profileEmail = 'john.doe@example.com';
  String _profileLocation = 'Makati';

  @override
  void initState() {
    super.initState();
    if (AppConfig.isSupabaseConfigured) {
      _loadPublishedListings();
    }
  }

  Future<void> _loadPublishedListings() async {
    try {
      final published = await _listingService.fetchListings();
      if (!mounted) return;
      setState(() {
        for (final listing in published) {
          if (_listings.every((existing) => existing.id != listing.id)) {
            _listings.add(listing);
          }
        }
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load published listings: $error')),
      );
    }
  }

  Future<void> _publishListing(RentalListing listing) async {
    final persistedListing = await _listingService.createListing(listing);
    if (!mounted) return;
    setState(() {
      _listings.insert(0, persistedListing);
      _currentIndex = 0;
    });
  }

  void _toggleSaved(RentalListing listing) {
    setState(() {
      if (!_savedListingIds.add(listing.id)) {
        _savedListingIds.remove(listing.id);
      }
    });
  }

  void _updateProfile({
    required String name,
    required String email,
    required String location,
  }) {
    setState(() {
      _profileName = name;
      _profileEmail = email;
      _profileLocation = location;
    });
  }

  void _saveConversation(Conversation updatedConversation) {
    setState(() {
      final index = _conversations.indexWhere(
        (conversation) => conversation.id == updatedConversation.id,
      );
      if (index == -1) {
        _conversations.add(updatedConversation);
      } else {
        _conversations[index] = updatedConversation;
      }
    });
  }

  void _startConversation(RentalListing listing) {
    final existingIndex = _conversations.indexWhere(
      (conversation) => conversation.itemName == listing.name,
    );
    final conversation = existingIndex == -1
        ? Conversation(
            id: 'conv-${listing.id}',
            participantName: listing.ownerName,
            itemName: listing.name,
            avatarText: listing.ownerAvatar,
            relatedImageUrl: listing.imageUrl,
            unread: false,
            archived: false,
            messages: const [],
          )
        : _conversations[existingIndex];

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          conversation: conversation,
          listing: listing,
          isSaved: _savedListingIds.contains(listing.id),
          onToggleSaved: _toggleSaved,
          onConversationUpdated: _saveConversation,
          onMessageOwner: _startConversation,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      ExploreScreen(
        listings: _listings,
        savedListingIds: _savedListingIds,
        onToggleSaved: _toggleSaved,
        onMessageOwner: _startConversation,
      ),
      InboxScreen(
        conversations: _conversations,
        listings: _listings,
        savedListingIds: _savedListingIds,
        onToggleSaved: _toggleSaved,
        onConversationUpdated: _saveConversation,
        onMessageOwner: _startConversation,
      ),
      ListItemScreen(ownerName: _profileName, onPublish: _publishListing),
      const ActivityScreen(),
      ProfileScreen(
        name: _profileName,
        email: _profileEmail,
        location: _profileLocation,
        savedListings: _listings
            .where((listing) => _savedListingIds.contains(listing.id))
            .toList(),
        myListings: _listings
            .where(
              (listing) => !sampleListings.any((seed) => seed.id == listing.id),
            )
            .toList(),
        onUpdate: _updateProfile,
        onToggleSaved: _toggleSaved,
        onMessageOwner: _startConversation,
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF211A16).withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            backgroundColor: Colors.white,
            indicatorColor: const Color(0xFFFFF0E6),
            labelTextStyle: WidgetStateProperty.all(
              const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          child: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (value) =>
                setState(() => _currentIndex = value),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.explore_outlined),
                selectedIcon: Icon(Icons.explore),
                label: 'Explore',
              ),
              NavigationDestination(
                icon: Icon(Icons.inbox_outlined),
                selectedIcon: Icon(Icons.inbox),
                label: 'Inbox',
              ),
              NavigationDestination(
                icon: Icon(Icons.add_circle_outline),
                selectedIcon: Icon(Icons.add_circle),
                label: 'List Item',
              ),
              NavigationDestination(
                icon: Badge(
                  backgroundColor: Color(0xFFF4510B),
                  label: Text('1'),
                  child: Icon(Icons.receipt_long_outlined),
                ),
                selectedIcon: Badge(
                  backgroundColor: Color(0xFFF4510B),
                  label: Text('1'),
                  child: Icon(Icons.receipt_long),
                ),
                label: 'Activity',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({
    super.key,
    required this.listings,
    required this.savedListingIds,
    required this.onToggleSaved,
    required this.onMessageOwner,
  });

  final List<RentalListing> listings;
  final Set<String> savedListingIds;
  final ValueChanged<RentalListing> onToggleSaved;
  final ValueChanged<RentalListing> onMessageOwner;

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  String selectedCategory = 'All';
  final TextEditingController searchController = TextEditingController();

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  List<RentalListing> get filteredListings {
    final query = searchController.text.trim().toLowerCase();

    return widget.listings.where((listing) {
      final matchesCategory =
          selectedCategory == 'All' || listing.category == selectedCategory;
      final matchesQuery =
          query.isEmpty ||
          listing.name.toLowerCase().contains(query) ||
          listing.description.toLowerCase().contains(query) ||
          listing.category.toLowerCase().contains(query) ||
          listing.location.toLowerCase().contains(query);
      return matchesCategory && matchesQuery;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF211A16),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    radius: 18,
                    backgroundColor: Color(0xFFF4510B),
                    child: Icon(
                      Icons.shopping_bag_outlined,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'RentIt',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 24,
                          ),
                        ),
                        const Text(
                          'Borrow more. Buy less.',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Color(0xFFC8BDB4),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              const Text(
                'Good morning, John',
                style: TextStyle(
                  color: Color(0xFFC8BDB4),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Find your next rental',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEF5C16), Color(0xFFC9470D)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Make room for more',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 20,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Rent what you need, when you need it.',
                            style: TextStyle(
                              color: Color(0xFFFFEDE5),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.shopping_bag_rounded,
                        size: 34,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF30251F),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Color(0xFFC8BDB4),
                  ),
                  hintText: 'Search cameras, tools, games...',
                  hintStyle: const TextStyle(color: Color(0xFFC8BDB4)),
                  suffixIcon: searchController.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            searchController.clear();
                            setState(() {});
                          },
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Color(0xFFC8BDB4),
                          ),
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFF45372F)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 46,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: rentalCategories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final category = rentalCategories[index];
                    final isSelected = selectedCategory == category;
                    return ChoiceChip(
                      label: Text(category),
                      selected: isSelected,
                      onSelected: (_) =>
                          setState(() => selectedCategory = category),
                      selectedColor: const Color(0xFFF4510B),
                      backgroundColor: const Color(0xFF30251F),
                      labelStyle: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : const Color(0xFFE8DED6),
                        fontWeight: FontWeight.w700,
                      ),
                      side: BorderSide.none,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 22),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Expanded(
                    child: Text(
                      'Popular near you',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    '${filteredListings.length} items',
                    style: const TextStyle(
                      color: Color(0xFFC8BDB4),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (filteredListings.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 36,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF30251F),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF45372F)),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.search_off_rounded,
                        size: 42,
                        color: Color(0xFFC8BDB4),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'No rentals found',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Try another search or choose a different category.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFFC8BDB4)),
                      ),
                      if (searchController.text.isNotEmpty ||
                          selectedCategory != 'All') ...[
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () {
                            searchController.clear();
                            setState(() => selectedCategory = 'All');
                          },
                          child: const Text('Clear filters'),
                        ),
                      ],
                    ],
                  ),
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredListings.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.44,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 8,
                  ),
                  itemBuilder: (context, index) {
                    final listing = filteredListings[index];
                    return _ListingCard(
                      listing: listing,
                      isSaved: widget.savedListingIds.contains(listing.id),
                      onToggleSaved: widget.onToggleSaved,
                      onMessageOwner: widget.onMessageOwner,
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ListingCard extends StatefulWidget {
  const _ListingCard({
    required this.listing,
    required this.isSaved,
    required this.onToggleSaved,
    required this.onMessageOwner,
  });

  final RentalListing listing;
  final bool isSaved;
  final ValueChanged<RentalListing> onToggleSaved;
  final ValueChanged<RentalListing> onMessageOwner;

  @override
  State<_ListingCard> createState() => _ListingCardState();
}

class _ListingCardState extends State<_ListingCard> {
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ListingDetailScreen(
            listing: widget.listing,
            isSaved: widget.isSaved,
            onToggleSaved: widget.onToggleSaved,
            onMessageOwner: widget.onMessageOwner,
          ),
        ),
      ),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(18),
                  ),
                  child: _listingImage(
                    widget.listing,
                    height: 132,
                    width: double.infinity,
                  ),
                ),
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF211A16).withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      widget.listing.category,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 10,
                  top: 10,
                  child: Material(
                    color: Colors.white.withValues(alpha: 0.92),
                    shape: const CircleBorder(),
                    child: IconButton(
                      tooltip: widget.isSaved
                          ? 'Remove from saved items'
                          : 'Save item',
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints.tightFor(
                        width: 34,
                        height: 34,
                      ),
                      padding: EdgeInsets.zero,
                      onPressed: () => widget.onToggleSaved(widget.listing),
                      icon: Icon(
                        widget.isSaved
                            ? Icons.favorite
                            : Icons.favorite_border_rounded,
                        color: widget.isSaved
                            ? const Color(0xFFF4510B)
                            : const Color(0xFF211A16),
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Text(
                widget.listing.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF211A16),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Text(
                '₱${widget.listing.pricePerDay}/day',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFF4510B),
                ),
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: widget.listing.isAvailable
                          ? const Color(0xFF6E8B75)
                          : const Color(0xFFD9534F),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      widget.listing.isAvailable ? 'Available now' : 'Booked',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: widget.listing.isAvailable
                            ? const Color(0xFF6E8B75)
                            : const Color(0xFFD9534F),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ListingDetailScreen extends StatefulWidget {
  const ListingDetailScreen({
    super.key,
    required this.listing,
    required this.isSaved,
    required this.onToggleSaved,
    required this.onMessageOwner,
  });

  final RentalListing listing;
  final bool isSaved;
  final ValueChanged<RentalListing> onToggleSaved;
  final ValueChanged<RentalListing> onMessageOwner;

  @override
  State<ListingDetailScreen> createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends State<ListingDetailScreen> {
  late bool _isSaved;

  RentalListing get listing => widget.listing;
  ValueChanged<RentalListing> get onToggleSaved => widget.onToggleSaved;
  ValueChanged<RentalListing> get onMessageOwner => widget.onMessageOwner;

  @override
  void initState() {
    super.initState();
    _isSaved = widget.isSaved;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5EAE0),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  _listingImage(listing, height: 280, width: double.infinity),
                  Positioned(
                    top: 16,
                    left: 16,
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: const CircleAvatar(
                        backgroundColor: Colors.white,
                        child: Icon(Icons.arrow_back, color: Color(0xFF211A16)),
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            listing.name,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF211A16),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: _isSaved
                              ? 'Remove from saved items'
                              : 'Save item',
                          onPressed: () {
                            setState(() => _isSaved = !_isSaved);
                            onToggleSaved(listing);
                          },
                          icon: Icon(
                            _isSaved
                                ? Icons.favorite
                                : Icons.favorite_border_rounded,
                            color: const Color(0xFFF4510B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          color: Color(0xFF8B5A38),
                          size: 18,
                        ),
                        Text(
                          listing.location,
                          style: const TextStyle(
                            color: Color(0xFF8B5A38),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Rental price',
                                style: TextStyle(
                                  color: Color(0xFF8B5A38),
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                '₱${listing.pricePerDay}/day',
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFF4510B),
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Security deposit',
                                style: TextStyle(
                                  color: Color(0xFF8B5A38),
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                listing.deposit,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF211A16),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: const Color(0xFFE7D4C0),
                          child: Text(
                            listing.ownerAvatar,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF211A16),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              listing.ownerName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF211A16),
                                fontSize: 16,
                              ),
                            ),
                            const Text(
                              'Verified owner',
                              style: TextStyle(
                                color: Color(0xFF6E8B75),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Description',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF211A16),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      listing.description,
                      style: const TextStyle(
                        color: Color(0xFF4C403B),
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _DetailGrid(listing: listing),
                    const SizedBox(height: 20),
                    const Text(
                      'Rental rules',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF211A16),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...listing.rules.map(
                      (rule) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.check_circle_rounded,
                              color: Color(0xFF6E8B75),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                rule,
                                style: const TextStyle(
                                  color: Color(0xFF4C403B),
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'No reviews yet.',
                      style: TextStyle(color: Color(0xFF8B5A38)),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => onMessageOwner(listing),
                            icon: const Icon(Icons.chat_bubble_outline_rounded),
                            label: const Text('Message Owner'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF211A16),
                              side: const BorderSide(color: Color(0xFF211A16)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: listing.isAvailable
                                ? () => showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    backgroundColor: Colors.transparent,
                                    builder: (_) =>
                                        BookingSheet(listing: listing),
                                  )
                                : null,
                            icon: Icon(
                              listing.isAvailable
                                  ? Icons.calendar_today_rounded
                                  : Icons.event_busy_rounded,
                            ),
                            label: Text(
                              listing.isAvailable ? 'Rent Now' : 'Booked',
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFF4510B),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailGrid extends StatelessWidget {
  const _DetailGrid({required this.listing});

  final RentalListing listing;

  @override
  Widget build(BuildContext context) {
    final items = <MapEntry<String, String>>[
      MapEntry('Condition', listing.condition),
      MapEntry('Category', listing.category),
      MapEntry('Pickup', listing.location),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 2.4,
      ),
      itemBuilder: (_, index) {
        final item = items[index];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFEFE2D7),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.key,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF8B5A38),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                item.value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF211A16),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class BookingSheet extends StatefulWidget {
  const BookingSheet({super.key, required this.listing});

  final RentalListing listing;

  @override
  State<BookingSheet> createState() => _BookingSheetState();
}

class _BookingSheetState extends State<BookingSheet> {
  final PaymentService _paymentService = PaymentService();
  DateTimeRange selectedRange = DateTimeRange(
    start: DateTime.now(),
    end: DateTime.now().add(const Duration(days: 3)),
  );
  bool _isProcessingPayment = false;

  int get totalDays => selectedRange.duration.inDays + 1;

  int get subtotal => widget.listing.pricePerDay * totalDays;
  int get serviceFee => (subtotal * 0.08).round();
  int get securityDeposit =>
      int.tryParse(widget.listing.deposit.replaceAll(RegExp(r'[^0-9]'), '')) ??
      0;
  int get finalTotal => subtotal + serviceFee + securityDeposit;

  Future<void> pickDates() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: selectedRange,
    );

    if (picked != null && mounted) {
      setState(() => selectedRange = picked);
    }
  }

  Future<void> _payNow() async {
    if (_isProcessingPayment) return;

    setState(() => _isProcessingPayment = true);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final invoice = await _paymentService.createRentalInvoice(
        listingId: widget.listing.id,
        days: totalDays,
      );
      final invoiceUrl = invoice['invoice_url'] as String;
      final externalId = invoice['external_id'] as String;

      if (!mounted) return;

      navigator.pop();
      await navigator.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => XenditWebViewScreen(invoiceUrl: invoiceUrl),
        ),
      );

      final status = await _paymentService.checkOrderStatus(externalId);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            status == 'PAID'
                ? 'Payment complete. ${widget.listing.name} is paid.'
                : 'Payment status: $status',
          ),
          backgroundColor: status == 'PAID'
              ? const Color(0xFF4E7B57)
              : const Color(0xFFB66A16),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Could not start payment: $error'),
          backgroundColor: const Color(0xFFB3261E),
        ),
      );
    } finally {
      if (mounted) setState(() => _isProcessingPayment = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
      decoration: const BoxDecoration(
        color: Color(0xFFF5EAE0),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFD4C2B3),
                borderRadius: BorderRadius.circular(100),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Review and pay',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF211A16),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Dates',
                        style: TextStyle(
                          color: Color(0xFF8B5A38),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${selectedRange.start.day}/${selectedRange.start.month}/${selectedRange.start.year} - ${selectedRange.end.day}/${selectedRange.end.month}/${selectedRange.end.year}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF211A16),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: pickDates,
                icon: const Icon(Icons.calendar_month_rounded),
                label: const Text('Pick'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF4510B),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _BreakdownRow(label: 'Rental subtotal', value: '₱$subtotal'),
                _BreakdownRow(label: 'Service fee', value: '₱$serviceFee'),
                _BreakdownRow(
                  label: 'Refundable deposit',
                  value: '₱$securityDeposit',
                  tinted: true,
                ),
                const Divider(height: 20),
                _BreakdownRow(
                  label: 'Final amount',
                  value: '₱$finalTotal',
                  isTotal: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isProcessingPayment ? null : _payNow,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFF4510B),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _isProcessingPayment
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text('Pay now · ₱$finalTotal'),
            ),
          ),
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    super.key,
    required this.label,
    required this.value,
    this.tinted = false,
    this.isTotal = false,
  });

  final String label;
  final String value;
  final bool tinted;
  final bool isTotal;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: tinted ? const Color(0xFF8B5A38) : const Color(0xFF4C403B),
              fontWeight: isTotal ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: isTotal
                  ? const Color(0xFFF4510B)
                  : const Color(0xFF211A16),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class InboxScreen extends StatefulWidget {
  const InboxScreen({
    super.key,
    required this.conversations,
    required this.listings,
    required this.savedListingIds,
    required this.onToggleSaved,
    required this.onConversationUpdated,
    required this.onMessageOwner,
  });

  final List<Conversation> conversations;
  final List<RentalListing> listings;
  final Set<String> savedListingIds;
  final ValueChanged<RentalListing> onToggleSaved;
  final ValueChanged<Conversation> onConversationUpdated;
  final ValueChanged<RentalListing> onMessageOwner;

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  String selectedFilter = 'All messages';
  final TextEditingController searchController = TextEditingController();

  List<Conversation> get visibleConversations {
    final query = searchController.text.trim().toLowerCase();
    final filtered = widget.conversations.where((conversation) {
      final filterMatches = switch (selectedFilter) {
        'Unread' => conversation.unread,
        'Archived' => conversation.archived,
        _ => true,
      };
      final searchMatches =
          query.isEmpty ||
          conversation.participantName.toLowerCase().contains(query) ||
          conversation.itemName.toLowerCase().contains(query) ||
          conversation.preview.toLowerCase().contains(query);
      return filterMatches && searchMatches;
    }).toList();
    filtered.sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));
    return filtered;
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Color(0xFFF4510B),
                      radius: 16,
                      child: Icon(
                        Icons.shopping_bag_outlined,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'RentIt',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF211A16),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Text(
              'Inbox',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: Color(0xFF211A16),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Good rentals start with a conversation.',
              style: TextStyle(
                color: Color(0xFF8B5A38),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                prefixIcon: const Icon(Icons.search, color: Color(0xFF8B5A38)),
                hintText: 'Search messages',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: ['All messages', 'Unread', 'Archived'].map((filter) {
                final selected = selectedFilter == filter;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(filter),
                      selected: selected,
                      onSelected: (_) =>
                          setState(() => selectedFilter = filter),
                      selectedColor: const Color(0xFFF4510B),
                      backgroundColor: Colors.white,
                      labelStyle: TextStyle(
                        color: selected
                            ? Colors.white
                            : const Color(0xFF211A16),
                        fontWeight: FontWeight.w700,
                      ),
                      side: BorderSide.none,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: visibleConversations.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 54,
                              color: Color(0xFFB9A79A),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              widget.conversations.isEmpty
                                  ? 'No conversations yet'
                                  : 'No messages found',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF211A16),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.conversations.isEmpty
                                  ? 'Message an owner to start a conversation.'
                                  : 'Try changing your search or message filter.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFF8B5A38),
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: visibleConversations.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final conversation = visibleConversations[index];
                        return InkWell(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                conversation: conversation,
                                listing: widget.listings
                                    .where(
                                      (item) =>
                                          item.name == conversation.itemName,
                                    )
                                    .firstOrNull,
                                isSaved: widget.listings
                                    .where(
                                      (item) =>
                                          item.name == conversation.itemName,
                                    )
                                    .any(
                                      (item) => widget.savedListingIds.contains(
                                        item.id,
                                      ),
                                    ),
                                onToggleSaved: widget.onToggleSaved,
                                onConversationUpdated:
                                    widget.onConversationUpdated,
                                onMessageOwner: widget.onMessageOwner,
                              ),
                            ),
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 25,
                                  backgroundColor: const Color(0xFFE7D4C0),
                                  child: Text(
                                    conversation.avatarText,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF211A16),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              conversation.participantName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFF211A16),
                                              ),
                                            ),
                                          ),
                                          Text(
                                            _formatTime(
                                              conversation.lastUpdated,
                                            ),
                                            style: const TextStyle(
                                              color: Color(0xFF8B5A38),
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        conversation.itemName,
                                        style: const TextStyle(
                                          color: Color(0xFF8B5A38),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              conversation.preview,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Color(0xFF4C403B),
                                              ),
                                            ),
                                          ),
                                          if (conversation.unread)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 7,
                                                    vertical: 4,
                                                  ),
                                              decoration: const BoxDecoration(
                                                color: Color(0xFFF4510B),
                                                borderRadius: BorderRadius.all(
                                                  Radius.circular(999),
                                                ),
                                              ),
                                              child: const Text(
                                                '1',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    if (dateTime.year == now.year &&
        dateTime.month == now.month &&
        dateTime.day == now.day) {
      return '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
    return '${dateTime.day}/${dateTime.month}';
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.conversation,
    this.listing,
    this.isSaved = false,
    this.onToggleSaved,
    required this.onConversationUpdated,
    required this.onMessageOwner,
  });

  final Conversation conversation;
  final RentalListing? listing;
  final bool isSaved;
  final ValueChanged<RentalListing>? onToggleSaved;
  final ValueChanged<Conversation> onConversationUpdated;
  final ValueChanged<RentalListing> onMessageOwner;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController messageController = TextEditingController();
  late List<ChatMessage> messages;

  @override
  void initState() {
    super.initState();
    messages = List<ChatMessage>.from(widget.conversation.messages);
  }

  @override
  void dispose() {
    messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5EAE0),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: const Icon(Icons.arrow_back, color: Colors.white),
            ),
            const SizedBox(width: 10),
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFFE7D4C0),
              child: Text(
                widget.conversation.avatarText,
                style: const TextStyle(
                  color: Color(0xFF211A16),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.conversation.participantName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    widget.conversation.itemName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFFE7D4C0),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ListingDetailScreen(
                  listing:
                      widget.listing ??
                      sampleListings.firstWhere(
                        (item) => item.name == widget.conversation.itemName,
                      ),
                  isSaved: widget.isSaved,
                  onToggleSaved: widget.onToggleSaved ?? (_) {},
                  onMessageOwner: widget.onMessageOwner,
                ),
              ),
            ),
            icon: const Icon(Icons.open_in_new_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index];
                final isMe = message.isMe;

                return Align(
                  alignment: isMe
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.7,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isMe ? const Color(0xFFF4510B) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          message.text,
                          style: TextStyle(
                            color: isMe
                                ? Colors.white
                                : const Color(0xFF211A16),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _formatTime(message.sentAt),
                          style: TextStyle(
                            fontSize: 10,
                            color: isMe
                                ? Colors.white.withValues(alpha: 0.8)
                                : const Color(0xFF8B5A38),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 18),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: messageController,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF5EAE0),
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  backgroundColor: const Color(0xFFF4510B),
                  onPressed: () {
                    final text = messageController.text.trim();
                    if (text.isEmpty) return;
                    final newMessage = ChatMessage(
                      id: 'msg-${DateTime.now().millisecondsSinceEpoch}',
                      text: text,
                      isMe: true,
                      sentAt: DateTime.now(),
                    );
                    setState(() {
                      messages.add(newMessage);
                      messageController.clear();
                    });
                    widget.onConversationUpdated(
                      Conversation(
                        id: widget.conversation.id,
                        participantName: widget.conversation.participantName,
                        itemName: widget.conversation.itemName,
                        avatarText: widget.conversation.avatarText,
                        relatedImageUrl: widget.conversation.relatedImageUrl,
                        unread: false,
                        archived: widget.conversation.archived,
                        messages: List<ChatMessage>.unmodifiable(messages),
                      ),
                    );
                  },
                  child: const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

class ListItemScreen extends StatefulWidget {
  const ListItemScreen({
    super.key,
    required this.ownerName,
    required this.onPublish,
  });

  final String ownerName;
  final Future<void> Function(RentalListing listing) onPublish;

  @override
  State<ListItemScreen> createState() => _ListItemScreenState();
}

class _ListItemScreenState extends State<ListItemScreen> {
  final titleController = TextEditingController();
  final locationController = TextEditingController(text: 'Makati');
  final priceController = TextEditingController(text: '600');
  final descriptionController = TextEditingController();
  final conditionController = TextEditingController(text: 'Good');
  final rulesController = TextEditingController(
    text: 'Return on time\nHandle with care',
  );
  Uint8List? imageBytes;
  bool isPublishing = false;
  String category = 'Tech';
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void dispose() {
    titleController.dispose();
    locationController.dispose();
    priceController.dispose();
    descriptionController.dispose();
    conditionController.dispose();
    rulesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (pickedFile == null) return;
    final bytes = await pickedFile.readAsBytes();
    if (!mounted) return;
    setState(() => imageBytes = bytes);
  }

  Future<void> _publish() async {
    if (isPublishing) return;
    final name = titleController.text.trim();
    final location = locationController.text.trim();
    final price = int.tryParse(priceController.text.trim());
    if (name.isEmpty || location.isEmpty || price == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter an item title, pickup location, and valid daily rate.',
          ),
        ),
      );
      return;
    }

    final rules = rulesController.text
        .split('\n')
        .map((rule) => rule.trim())
        .where((rule) => rule.isNotEmpty)
        .toList();
    final listing = RentalListing(
      id: 'listing-${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      category: category,
      ownerName: widget.ownerName,
      ownerAvatar: widget.ownerName
          .trim()
          .split(RegExp(r'\s+'))
          .take(2)
          .map((part) => part[0])
          .join()
          .toUpperCase(),
      location: location,
      description: descriptionController.text.trim(),
      condition: conditionController.text.trim().isEmpty
          ? 'Not specified'
          : conditionController.text.trim(),
      imageUrl: '',
      imageBytes: imageBytes,
      deposit: '₱0',
      pricePerDay: price,
      rating: 0,
      isAvailable: true,
      rules: rules,
      reviews: const [],
    );
    setState(() => isPublishing = true);
    try {
      await widget.onPublish(listing);
      if (!mounted) return;
      titleController.clear();
      descriptionController.clear();
      conditionController.text = 'Good';
      rulesController.text = 'Return on time\nHandle with care';
      setState(() => imageBytes = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your listing is now visible in Explore.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not publish listing: $error'),
          backgroundColor: const Color(0xFFB3261E),
        ),
      );
    } finally {
      if (mounted) setState(() => isPublishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'List an item',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: Color(0xFF211A16),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create a listing and reach people nearby.',
              style: TextStyle(
                color: Color(0xFF8B5A38),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Item title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: category,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              items: rentalCategories.where((value) => value != 'All').map((
                value,
              ) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (value) => setState(() => category = value ?? 'Tech'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: locationController,
              decoration: const InputDecoration(
                labelText: 'Pickup location',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Daily rate (₱)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: descriptionController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: conditionController,
              decoration: const InputDecoration(
                labelText: 'Condition',
                hintText: 'e.g. Like new, good, or fair',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: rulesController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Rental rules',
                hintText: 'Enter one rule per line',
                helperText: 'These rules are shown on your listing.',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  if (imageBytes == null)
                    const Icon(
                      Icons.camera_alt_outlined,
                      color: Color(0xFFF4510B),
                      size: 28,
                    )
                  else
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        imageBytes!,
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                      ),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      imageBytes == null
                          ? 'Upload item photos'
                          : 'Photo selected',
                    ),
                  ),
                  TextButton(
                    onPressed: _pickImage,
                    child: Text(imageBytes == null ? 'Add' : 'Change'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: isPublishing ? null : _publish,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFF4510B),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: isPublishing
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Publish listing'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final activities = [
      _ActivityCard(
        title: 'Sony Alpha a7 III Camera Kit',
        status: 'Pending approval',
        detail: 'Requested for 3 days · ₱1,800 total',
      ),
      _ActivityCard(
        title: 'Nintendo Switch OLED',
        status: 'Confirmed',
        detail: 'Pickup tomorrow · 4.8 rating',
      ),
      _ActivityCard(
        title: 'Bosch Cordless Drill',
        status: 'Completed',
        detail: 'Returned on Oct 24 · Deposit refunded',
      ),
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Activity',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: Color(0xFF211A16),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Your rental requests and bookings.',
              style: TextStyle(
                color: Color(0xFF8B5A38),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: ListView.separated(
                itemCount: activities.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, index) => activities[index],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    super.key,
    required this.title,
    required this.status,
    required this.detail,
  });

  final String title;
  final String status;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final color = status == 'Confirmed'
        ? const Color(0xFF6E8B75)
        : status == 'Completed'
        ? const Color(0xFF8B5A38)
        : const Color(0xFFF4510B);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Status: $status'),
                const SizedBox(height: 8),
                Text(detail),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.receipt_long_rounded, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF211A16),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      detail,
                      style: const TextStyle(color: Color(0xFF8B5A38)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.name,
    required this.email,
    required this.location,
    required this.savedListings,
    required this.myListings,
    required this.onUpdate,
    required this.onToggleSaved,
    required this.onMessageOwner,
  });

  final String name;
  final String email;
  final String location;
  final List<RentalListing> savedListings;
  final List<RentalListing> myListings;
  final void Function({
    required String name,
    required String email,
    required String location,
  })
  onUpdate;
  final ValueChanged<RentalListing> onToggleSaved;
  final ValueChanged<RentalListing> onMessageOwner;

  Future<void> _editProfile(BuildContext context) async {
    final result = await showDialog<(String, String, String)>(
      context: context,
      builder: (context) =>
          _EditProfileDialog(name: name, email: email, location: location),
    );
    if (result != null) {
      onUpdate(name: result.$1, email: result.$2, location: result.$3);
    }
  }

  void _showListings(
    BuildContext context, {
    required String title,
    required List<RentalListing> listings,
    required bool allowSave,
  }) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 420,
          height: 360,
          child: listings.isEmpty
              ? const Center(child: Text('No items to show yet.'))
              : ListView.separated(
                  itemCount: listings.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final listing = listings[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 4),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: _listingImage(listing, width: 52, height: 52),
                      ),
                      title: Text(
                        listing.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text('₱${listing.pricePerDay} / day'),
                      trailing: allowSave
                          ? IconButton(
                              tooltip: 'Remove saved item',
                              onPressed: () {
                                onToggleSaved(listing);
                                Navigator.pop(context);
                              },
                              icon: const Icon(
                                Icons.favorite,
                                color: Color(0xFFF4510B),
                              ),
                            )
                          : null,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ListingDetailScreen(
                              listing: listing,
                              isSaved: savedListings.any(
                                (item) => item.id == listing.id,
                              ),
                              onToggleSaved: onToggleSaved,
                              onMessageOwner: onMessageOwner,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const Text(
            'Profile',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: Color(0xFF211A16),
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: const Color(0xFFF4510B),
                  child: Text(
                    name.trim().isEmpty
                        ? '?'
                        : name
                              .trim()
                              .split(RegExp(r'\s+'))
                              .take(2)
                              .map((part) => part[0])
                              .join()
                              .toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF211A16),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email,
                        style: const TextStyle(color: Color(0xFF8B5A38)),
                      ),
                      Text(
                        location,
                        style: const TextStyle(color: Color(0xFF8B5A38)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Edit profile',
                  onPressed: () => _editProfile(context),
                  icon: const Icon(
                    Icons.edit_outlined,
                    color: Color(0xFFF4510B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _profileAction(
            title: 'My Listings',
            trailing: '${myListings.length} items',
            onTap: () => _showListings(
              context,
              title: 'My Listings',
              listings: myListings,
              allowSave: false,
            ),
          ),
          _profileAction(
            title: 'Payment methods',
            trailing: 'Manage',
            onTap: () => showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Payment methods'),
                content: const Text(
                  'Payment options are selected securely during checkout.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ),
          _profileAction(
            title: 'Saved items',
            trailing: '${savedListings.length} saved',
            onTap: () => _showListings(
              context,
              title: 'Saved items',
              listings: savedListings,
              allowSave: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileAction({
    required String title,
    required String trailing,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF211A16),
                    ),
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 125),
                  child: Text(
                    trailing,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                      color: Color(0xFF8B5A38),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EditProfileDialog extends StatefulWidget {
  const _EditProfileDialog({
    required this.name,
    required this.email,
    required this.location,
  });

  final String name;
  final String email;
  final String location;

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  late final TextEditingController nameController;
  late final TextEditingController emailController;
  late final TextEditingController locationController;
  final formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.name);
    emailController = TextEditingController(text: widget.email);
    locationController = TextEditingController(text: widget.location);
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit profile'),
      content: Form(
        key: formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter your name'
                    : null,
              ),
              TextFormField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
              ),
              TextFormField(
                controller: locationController,
                decoration: const InputDecoration(labelText: 'Location'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!formKey.currentState!.validate()) return;
            Navigator.pop(context, (
              nameController.text.trim(),
              emailController.text.trim(),
              locationController.text.trim(),
            ));
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
