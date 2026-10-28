// Main app entry point, screens, and rental-listing interactions.
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

const _pageBackground = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    Color(0xFF17120F),
    Color(0xFF75401F),
    Color(0xFF1D1008),
    Color(0xFF8A470C),
  ],
  stops: [0, 0.38, 0.72, 1],
);

Widget _brandHeader() {
  return Row(
    children: [
      Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: const Color(0xFF17120F),
          borderRadius: BorderRadius.circular(5),
        ),
        child: const Icon(
          Icons.shopping_bag_rounded,
          color: Colors.white,
          size: 17,
        ),
      ),
      const SizedBox(width: 8),
      const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'RentIt',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          Text(
            'Borrow more. Buy less.',
            style: TextStyle(
              color: Color(0xFFE0D2C7),
              fontSize: 7,
              height: 1.2,
            ),
          ),
        ],
      ),
    ],
  );
}

Widget _pageBody(Widget child) {
  return Container(
    decoration: const BoxDecoration(gradient: _pageBackground),
    child: child,
  );
}

InputDecoration _designInputDecoration(String label) {
  return InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: Color(0xFFE0D2C7), fontSize: 9),
    filled: true,
    fillColor: const Color(0xFF4A382B),
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(9),
      borderSide: const BorderSide(color: Color(0xFF70543F)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(9),
      borderSide: const BorderSide(color: Color(0xFF70543F)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(9),
      borderSide: const BorderSide(color: Color(0xFFF4510B)),
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
        scaffoldBackgroundColor: const Color(0xFF211A16),
        colorScheme: ColorScheme.fromSeed(
          seedColor: orange,
          primary: orange,
          secondary: const Color(0xFF542B12),
          surface: const Color(0xFF30251F),
          onSurface: Colors.white,
          brightness: Brightness.dark,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: warmBrown,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
          titleMedium: TextStyle(
            color: Colors.white,
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

  void _updateListing(RentalListing updatedListing) {
    final index = _listings.indexWhere((item) => item.id == updatedListing.id);
    if (index < 0) {
      throw StateError('The listing is no longer available.');
    }
    setState(() => _listings[index] = updatedListing);
  }

  void _deleteListing(RentalListing listing) {
    setState(() {
      _listings.removeWhere((item) => item.id == listing.id);
      _savedListingIds.remove(listing.id);
    });
  }

  bool _canManageListing(RentalListing listing) =>
      listing.ownerName == _profileName &&
      !sampleListings.any((sample) => sample.id == listing.id);

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
          canManageListing: _canManageListing,
          onUpdateListing: _updateListing,
          onDeleteListing: _deleteListing,
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
        canManageListing: _canManageListing,
        onUpdateListing: _updateListing,
        onDeleteListing: _deleteListing,
        onToggleSaved: _toggleSaved,
        onMessageOwner: _startConversation,
      ),
      InboxScreen(
        conversations: _conversations,
        listings: _listings,
        savedListingIds: _savedListingIds,
        canManageListing: _canManageListing,
        onUpdateListing: _updateListing,
        onDeleteListing: _deleteListing,
        onToggleSaved: _toggleSaved,
        onConversationUpdated: _saveConversation,
        onMessageOwner: _startConversation,
      ),
      ListItemScreen(ownerName: _profileName, onPublish: _publishListing),
      ActivityScreen(listings: _listings, onMessageOwner: _startConversation),
      ProfileScreen(
        name: _profileName,
        email: _profileEmail,
        location: _profileLocation,
        canManageListing: _canManageListing,
        onUpdateListing: _updateListing,
        onDeleteListing: _deleteListing,
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
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          height: 56,
          backgroundColor: const Color(0xFFF4510B),
          indicatorColor: Colors.white,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w600,
              color: states.contains(WidgetState.selected)
                  ? const Color(0xFF211A16)
                  : Colors.white,
            ),
          ),
          iconTheme: WidgetStateProperty.resolveWith(
            (states) => IconThemeData(
              size: 18,
              color: states.contains(WidgetState.selected)
                  ? const Color(0xFF211A16)
                  : Colors.white,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (value) =>
              setState(() => _currentIndex = value),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Explore',
            ),
            NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline),
              selectedIcon: Icon(Icons.chat_bubble),
              label: 'Inbox',
            ),
            NavigationDestination(
              icon: Icon(Icons.add_circle_outline),
              selectedIcon: Icon(Icons.add_circle),
              label: 'List Item',
            ),
            NavigationDestination(
              icon: Icon(Icons.explore_outlined),
              selectedIcon: Icon(Icons.explore),
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
    );
  }
}

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({
    super.key,
    required this.listings,
    required this.savedListingIds,
    required this.canManageListing,
    required this.onUpdateListing,
    required this.onDeleteListing,
    required this.onToggleSaved,
    required this.onMessageOwner,
  });

  final List<RentalListing> listings;
  final Set<String> savedListingIds;
  final bool Function(RentalListing) canManageListing;
  final ValueChanged<RentalListing> onUpdateListing;
  final ValueChanged<RentalListing> onDeleteListing;
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
    return Scaffold(
      body: _pageBody(
        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _brandHeader(),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE95200),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'THE SMARTER WAY TO RENT',
                              style: TextStyle(
                                color: Color(0xFFFFD3B7),
                                fontWeight: FontWeight.w600,
                                fontSize: 7,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Find your next\nfavorite thing.',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 20,
                                height: 1.05,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Great finds, right around the corner.',
                              style: TextStyle(
                                color: Color(0xFFFFE4D4),
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.shopping_bag_rounded,
                        size: 48,
                        color: Color(0xFFF1DED1),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFF51473F),
                    prefixIcon: const Icon(Icons.search, color: Colors.white),
                    hintText: 'Search cameras, tools, games...',
                    hintStyle: const TextStyle(
                      color: Color(0xFFD4CCC6),
                      fontSize: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF75685F)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 30,
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
                        backgroundColor: const Color(0xFFF5F1EB),
                        labelStyle: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF2D2926),
                          fontWeight: FontWeight.w600,
                          fontSize: 9,
                        ),
                        side: BorderSide.none,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        visualDensity: VisualDensity.compact,
                      );
                    },
                  ),
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
                      ],
                    ),
                  )
                else
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final cardWidth = (constraints.maxWidth - 8) / 2;
                      final imageHeight = cardWidth * 0.48;
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredListings.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisExtent: imageHeight + 50,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 10,
                        ),
                        itemBuilder: (context, index) {
                          final listing = filteredListings[index];
                          return _ListingCard(
                            listing: listing,
                            imageHeight: imageHeight,
                            isSaved: widget.savedListingIds.contains(
                              listing.id,
                            ),
                            canManage: widget.canManageListing(listing),
                            onUpdateListing: widget.onUpdateListing,
                            onDeleteListing: widget.onDeleteListing,
                            onToggleSaved: widget.onToggleSaved,
                            onMessageOwner: widget.onMessageOwner,
                          );
                        },
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ListingCard extends StatefulWidget {
  const _ListingCard({
    required this.listing,
    required this.imageHeight,
    required this.isSaved,
    required this.canManage,
    required this.onUpdateListing,
    required this.onDeleteListing,
    required this.onToggleSaved,
    required this.onMessageOwner,
  });

  final RentalListing listing;
  final double imageHeight;
  final bool isSaved;
  final bool canManage;
  final ValueChanged<RentalListing> onUpdateListing;
  final ValueChanged<RentalListing> onDeleteListing;
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
            canManage: widget.canManage,
            onUpdateListing: widget.onUpdateListing,
            onDeleteListing: widget.onDeleteListing,
            onToggleSaved: widget.onToggleSaved,
            onMessageOwner: widget.onMessageOwner,
          ),
        ),
      ),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF66513F),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: const Color(0xFF9A7456)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(13),
                  ),
                  child: _listingImage(
                    widget.listing,
                    height: widget.imageHeight,
                    width: double.infinity,
                  ),
                ),
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      widget.listing.category,
                      style: const TextStyle(
                        color: Color(0xFF211A16),
                        fontSize: 7,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 10,
                  top: 10,
                  child: Material(
                    color: Colors.white,
                    shape: const CircleBorder(),
                    child: IconButton(
                      tooltip: widget.isSaved
                          ? 'Remove from saved items'
                          : 'Save item',
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints.tightFor(
                        width: 22,
                        height: 22,
                      ),
                      padding: EdgeInsets.zero,
                      onPressed: () => widget.onToggleSaved(widget.listing),
                      icon: Icon(
                        widget.isSaved
                            ? Icons.favorite
                            : Icons.favorite_border_rounded,
                        color: const Color(0xFF211A16),
                        size: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(7, 5, 7, 0),
              child: Text(
                widget.listing.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 8,
                  height: 1.05,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(7, 6, 7, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '₱${widget.listing.pricePerDay}/day',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Text(
                    '${widget.listing.rating} ★',
                    style: const TextStyle(
                      fontSize: 7,
                      color: Color(0xFFFFCF61),
                      fontWeight: FontWeight.w700,
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
    this.canManage = false,
    this.onUpdateListing,
    this.onDeleteListing,
    required this.onToggleSaved,
    required this.onMessageOwner,
  });

  final RentalListing listing;
  final bool isSaved;
  final bool canManage;
  final ValueChanged<RentalListing>? onUpdateListing;
  final ValueChanged<RentalListing>? onDeleteListing;
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

  Future<void> _editListing() async {
    final updatedListing = await showDialog<RentalListing>(
      context: context,
      builder: (_) => _EditListingDialog(listing: listing),
    );
    if (updatedListing == null || !mounted) return;
    widget.onUpdateListing?.call(updatedListing);
    Navigator.of(context).pop();
  }

  Future<void> _deleteListing() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete listing?'),
        content: Text('“${listing.name}” will be removed from your listings.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB3261E),
            ),
            child: const Text('Delete listing'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    widget.onDeleteListing?.call(listing);
    Navigator.of(context).pop();
  }

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
                        children: [
                          Expanded(
                            child: Column(
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
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFF4510B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Security deposit',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Color(0xFF8B5A38),
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  listing.deposit,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF211A16),
                                  ),
                                ),
                              ],
                            ),
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
                    if (widget.canManage) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _editListing,
                              icon: const Icon(Icons.edit_outlined),
                              label: const Text('Edit listing'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF211A16),
                                side: const BorderSide(
                                  color: Color(0xFF211A16),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _deleteListing,
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Delete listing'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFB3261E),
                                side: const BorderSide(
                                  color: Color(0xFFB3261E),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
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

class _EditListingDialog extends StatefulWidget {
  const _EditListingDialog({required this.listing});

  final RentalListing listing;

  @override
  State<_EditListingDialog> createState() => _EditListingDialogState();
}

class _EditListingDialogState extends State<_EditListingDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.listing.name);
  late final _conditionController = TextEditingController(
    text: widget.listing.condition,
  );
  late final _locationController = TextEditingController(
    text: widget.listing.location,
  );
  late final _priceController = TextEditingController(
    text: widget.listing.pricePerDay.toString(),
  );
  late final _descriptionController = TextEditingController(
    text: widget.listing.description,
  );
  late String _category = widget.listing.category;

  @override
  void dispose() {
    _nameController.dispose();
    _conditionController.dispose();
    _locationController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final price = int.parse(_priceController.text.trim());
    Navigator.of(context).pop(
      RentalListing(
        id: widget.listing.id,
        name: _nameController.text.trim(),
        category: _category,
        ownerName: widget.listing.ownerName,
        ownerAvatar: widget.listing.ownerAvatar,
        location: _locationController.text.trim(),
        description: _descriptionController.text.trim(),
        condition: _conditionController.text.trim(),
        imageUrl: widget.listing.imageUrl,
        imageBytes: widget.listing.imageBytes,
        deposit: widget.listing.deposit,
        pricePerDay: price,
        rating: widget.listing.rating,
        isAvailable: widget.listing.isAvailable,
        rules: widget.listing.rules,
        reviews: widget.listing.reviews,
      ),
    );
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Required' : null;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit listing'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Item name'),
                  validator: _required,
                ),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: rentalCategories
                      .where((category) => category != 'All')
                      .map(
                        (category) => DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _category = value);
                  },
                ),
                TextFormField(
                  controller: _conditionController,
                  decoration: const InputDecoration(labelText: 'Condition'),
                  validator: _required,
                ),
                TextFormField(
                  controller: _locationController,
                  decoration: const InputDecoration(
                    labelText: 'Pickup location',
                  ),
                  validator: _required,
                ),
                TextFormField(
                  controller: _priceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Daily rate (₱)',
                  ),
                  validator: (value) {
                    final price = int.tryParse(value?.trim() ?? '');
                    return price == null || price <= 0
                        ? 'Enter a valid daily rate'
                        : null;
                  },
                ),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save changes')),
      ],
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
        childAspectRatio: 1.8,
      ),
      itemBuilder: (_, index) {
        final item = items[index];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFEFE2D7),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
              Text(
                item.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
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
    required this.canManageListing,
    required this.onUpdateListing,
    required this.onDeleteListing,
    required this.onToggleSaved,
    required this.onConversationUpdated,
    required this.onMessageOwner,
  });

  final List<Conversation> conversations;
  final List<RentalListing> listings;
  final Set<String> savedListingIds;
  final bool Function(RentalListing) canManageListing;
  final ValueChanged<RentalListing> onUpdateListing;
  final ValueChanged<RentalListing> onDeleteListing;
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
    final unreadCount = widget.conversations
        .where((item) => item.unread)
        .length;
    return _pageBody(
      SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _brandHeader(),
                  if (unreadCount > 0)
                    Text(
                      '$unreadCount unread',
                      style: const TextStyle(
                        color: Color(0xFFF5E7D9),
                        fontSize: 8,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                'Inbox',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Good rentals start with a conversation.',
                style: TextStyle(color: Color(0xFFD8C9BC), fontSize: 8),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF59483C),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Colors.white,
                    size: 16,
                  ),
                  hintText: 'Search messages',
                  hintStyle: const TextStyle(
                    color: Color(0xFFD8C9BC),
                    fontSize: 9,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 9),
                ),
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
              const SizedBox(height: 14),
              Row(
                children: ['All messages', 'Unread', 'Archived'].map((filter) {
                  final selected = selectedFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 5),
                    child: ChoiceChip(
                      label: Text(filter),
                      selected: selected,
                      onSelected: (_) =>
                          setState(() => selectedFilter = filter),
                      selectedColor: const Color(0xFFE9E6DF),
                      backgroundColor: const Color(0xFFF5F1EB),
                      labelStyle: TextStyle(
                        color: const Color(0xFF211A16),
                        fontWeight: FontWeight.w600,
                        fontSize: 8,
                      ),
                      side: BorderSide.none,
                      visualDensity: VisualDensity.compact,
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
                                color: Color(0xFFD8C9BC),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                widget.conversations.isEmpty
                                    ? 'No conversations yet'
                                    : 'No messages found',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                widget.conversations.isEmpty
                                    ? 'Message an owner to start a conversation.'
                                    : 'Try changing your search or message filter.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xFFD8C9BC),
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
                                        (item) => widget.savedListingIds
                                            .contains(item.id),
                                      ),
                                  canManageListing: widget.canManageListing,
                                  onUpdateListing: widget.onUpdateListing,
                                  onDeleteListing: widget.onDeleteListing,
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
                                color: Colors.transparent,
                                border: Border(
                                  bottom: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.13),
                                  ),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 25,
                                    backgroundColor: const Color(0xFF8A6448),
                                    child: Text(
                                      conversation.avatarText,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
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
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              _formatTime(
                                                conversation.lastUpdated,
                                              ),
                                              style: const TextStyle(
                                                color: Color(0xFFD9C4B2),
                                                fontSize: 7,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          conversation.itemName,
                                          style: const TextStyle(
                                            color: Color(0xFFD9C4B2),
                                            fontSize: 7,
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
                                                  color: Color(0xFFF0E8E1),
                                                  fontSize: 8,
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
                                                  borderRadius:
                                                      BorderRadius.all(
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
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF59402D),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.verified_user_outlined,
                      color: Color(0xFFF5E7D9),
                      size: 14,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Keep it on RentIt',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Chat and pay here for a safer rental experience.',
                            style: TextStyle(
                              color: Color(0xFFD8C9BC),
                              fontSize: 7,
                            ),
                          ),
                        ],
                      ),
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
    required this.canManageListing,
    required this.onUpdateListing,
    required this.onDeleteListing,
    this.onToggleSaved,
    required this.onConversationUpdated,
    required this.onMessageOwner,
  });

  final Conversation conversation;
  final RentalListing? listing;
  final bool isSaved;
  final bool Function(RentalListing) canManageListing;
  final ValueChanged<RentalListing> onUpdateListing;
  final ValueChanged<RentalListing> onDeleteListing;
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
                  canManage: widget.canManageListing(
                    widget.listing ??
                        sampleListings.firstWhere(
                          (item) => item.name == widget.conversation.itemName,
                        ),
                  ),
                  onUpdateListing: widget.onUpdateListing,
                  onDeleteListing: widget.onDeleteListing,
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
      rules: rulesController.text
          .split('\n')
          .map((rule) => rule.trim())
          .where((rule) => rule.isNotEmpty)
          .toList(),
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
    return _pageBody(
      SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _brandHeader(),
              const SizedBox(height: 17),
              const Text(
                'List Item',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Turn your everyday things into extra income.',
                style: TextStyle(color: Color(0xFFD8C9BC), fontSize: 8),
              ),
              const SizedBox(height: 14),
              const Text(
                'Item photos',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF38271C),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF72513A)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 46,
                      decoration: BoxDecoration(
                        color: const Color(0xFF59534E),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: imageBytes == null
                          ? const Icon(
                              Icons.camera_alt_rounded,
                              color: Colors.white,
                              size: 22,
                            )
                          : Image.memory(imageBytes!, fit: BoxFit.cover),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _pickImage,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFF8A6448)),
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.add_photo_alternate_outlined,
                              size: 15,
                            ),
                            Text(
                              imageBytes == null
                                  ? 'Add photos'
                                  : 'Change photo',
                              style: const TextStyle(fontSize: 8),
                            ),
                            const Text(
                              'Show every angle',
                              style: TextStyle(
                                color: Color(0xFFD8C9BC),
                                fontSize: 7,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 9),
              TextField(
                controller: titleController,
                style: const TextStyle(color: Colors.white, fontSize: 9),
                decoration: _designInputDecoration('Item name *'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: category,
                      decoration: _designInputDecoration('Category *'),
                      dropdownColor: const Color(0xFF38271C),
                      style: const TextStyle(color: Colors.white, fontSize: 9),
                      items: rentalCategories
                          .where((value) => value != 'All')
                          .map((value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          })
                          .toList(),
                      onChanged: (value) =>
                          setState(() => category = value ?? 'Tech'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: conditionController,
                      style: const TextStyle(color: Colors.white, fontSize: 9),
                      decoration: _designInputDecoration('Condition *'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white, fontSize: 9),
                decoration: _designInputDecoration('Daily rate (₱) *'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descriptionController,
                maxLines: 2,
                style: const TextStyle(color: Colors.white, fontSize: 9),
                decoration: _designInputDecoration('Description *'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: rulesController,
                maxLines: 3,
                style: const TextStyle(color: Colors.white, fontSize: 9),
                decoration: _designInputDecoration('Rental rules').copyWith(
                  hintText: 'Enter one rule per line',
                  helperText: 'Shown to renters on your listing.',
                  helperStyle: const TextStyle(
                    color: Color(0xFFD8C9BC),
                    fontSize: 7,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: locationController,
                style: const TextStyle(color: Colors.white, fontSize: 9),
                decoration: _designInputDecoration('Pickup location *')
                    .copyWith(
                      suffixIcon: const Icon(
                        Icons.location_on_outlined,
                        color: Color(0xFFD8C9BC),
                        size: 15,
                      ),
                    ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: isPublishing ? null : _publish,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFF4510B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
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
                      : const Text(
                          'Publish listing',
                          style: TextStyle(fontSize: 9),
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

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({
    super.key,
    required this.listings,
    required this.onMessageOwner,
  });

  final List<RentalListing> listings;
  final ValueChanged<RentalListing> onMessageOwner;

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  static const _allStatuses = [
    'All',
    'Pending',
    'Confirmed',
    'Completed',
    'Refund requested',
  ];

  final TextEditingController _searchController = TextEditingController();
  String _selectedStatus = 'All';
  final List<_ActivityEntry> _activities = [
    _ActivityEntry(
      title: 'Sony Alpha a7 III Camera Kit',
      status: 'Pending',
      detail: 'Requested for 3 days · ₱1,800 total',
      listingId: 'cam-1',
    ),
    _ActivityEntry(
      title: 'Nintendo Switch OLED',
      status: 'Confirmed',
      detail: 'Pickup tomorrow · 4.8 rating',
      listingId: 'game-1',
    ),
    _ActivityEntry(
      title: 'Bosch Cordless Drill',
      status: 'Completed',
      detail: 'Returned on Oct 24 · Deposit refunded',
      listingId: 'tool-1',
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_ActivityEntry> get _visibleActivities {
    final query = _searchController.text.trim().toLowerCase();
    return _activities.where((activity) {
      final matchesStatus =
          _selectedStatus == 'All' || activity.status == _selectedStatus;
      final matchesSearch =
          query.isEmpty ||
          activity.title.toLowerCase().contains(query) ||
          activity.status.toLowerCase().contains(query) ||
          activity.detail.toLowerCase().contains(query);
      return matchesStatus && matchesSearch;
    }).toList();
  }

  Future<void> _deleteActivity(_ActivityEntry activity) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete activity?'),
        content: Text('Remove “${activity.title}” from your activity?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _activities.remove(activity));
  }

  void _showActivityDetails(_ActivityEntry activity) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(activity.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status: ${activity.status}'),
            const SizedBox(height: 8),
            Text(activity.detail),
            if (activity.review case final review?) ...[
              const SizedBox(height: 12),
              Text('Your review: ${review.rating.toStringAsFixed(0)}/5'),
              const SizedBox(height: 4),
              Text(review.comment),
            ],
          ],
        ),
        actions: [
          if (activity.status == 'Pending')
            TextButton(
              onPressed: () =>
                  _updateActivityStatus(dialogContext, activity, 'Confirmed'),
              child: const Text('Confirm rental'),
            ),
          if (activity.status == 'Confirmed')
            TextButton(
              onPressed: () =>
                  _updateActivityStatus(dialogContext, activity, 'Completed'),
              child: const Text('Mark completed'),
            ),
          if (activity.status == 'Confirmed' || activity.status == 'Completed')
            TextButton(
              onPressed: () => _updateActivityStatus(
                dialogContext,
                activity,
                'Refund requested',
              ),
              child: const Text('Request a refund'),
            ),
          if (activity.status == 'Completed')
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _showReviewDialog(activity);
              },
              child: Text(
                activity.review == null ? 'Write a review' : 'Edit review',
              ),
            ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _showReviewDialog(_ActivityEntry activity) async {
    final review = await showDialog<Review>(
      context: context,
      builder: (context) => _CreateReviewDialog(
        rentalName: activity.title,
        initialReview: activity.review,
      ),
    );
    if (review == null || !mounted) return;
    setState(() => activity.review = review);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Your review has been saved.')),
    );
  }

  void _updateActivityStatus(
    BuildContext dialogContext,
    _ActivityEntry activity,
    String status,
  ) {
    setState(() => activity.status = status);
    Navigator.pop(dialogContext);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Activity status updated to $status.')),
    );
  }

  void _messageOwner(_ActivityEntry activity) {
    final matches = widget.listings.where(
      (listing) => listing.id == activity.listingId,
    );
    if (matches.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This listing is no longer available.')),
      );
      return;
    }
    widget.onMessageOwner(matches.first);
  }

  @override
  Widget build(BuildContext context) {
    return _pageBody(
      SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _brandHeader(),
              const SizedBox(height: 17),
              const Text(
                'Activity',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Every rental, all in one place.',
                style: TextStyle(color: Color(0xFFD8C9BC), fontSize: 8),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF51473F),
                  prefixIcon: const Icon(Icons.search, color: Colors.white),
                  hintText: 'Search activity...',
                  hintStyle: const TextStyle(
                    color: Color(0xFFD4CCC6),
                    fontSize: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF75685F)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 34,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _allStatuses.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 8),
                  itemBuilder: (_, index) {
                    final status = _allStatuses[index];
                    final selected = status == _selectedStatus;
                    return ChoiceChip(
                      label: Text(status),
                      selected: selected,
                      onSelected: (_) =>
                          setState(() => _selectedStatus = status),
                      labelStyle: TextStyle(
                        color: selected
                            ? const Color(0xFF211A16)
                            : Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                      selectedColor: const Color(0xFFFFB27F),
                      backgroundColor: const Color(0xFF51473F),
                      side: BorderSide.none,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: _visibleActivities.isEmpty
                    ? const Center(
                        child: Text(
                          'No matching activity.',
                          style: TextStyle(color: Color(0xFFD8C9BC)),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _visibleActivities.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (_, index) {
                          final activity = _visibleActivities[index];
                          return _ActivityCard(
                            title: activity.title,
                            status: activity.status,
                            detail: activity.detail,
                            review: activity.review,
                            onTap: () => _showActivityDetails(activity),
                            onMessageOwner: () => _messageOwner(activity),
                            onReview: () => _showReviewDialog(activity),
                            onDelete: () => _deleteActivity(activity),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityEntry {
  _ActivityEntry({
    required this.title,
    required this.status,
    required this.detail,
    required this.listingId,
  });

  final String title;
  String status;
  final String detail;
  final String listingId;
  Review? review;
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    super.key,
    required this.title,
    required this.status,
    required this.detail,
    required this.review,
    required this.onTap,
    required this.onMessageOwner,
    required this.onReview,
    required this.onDelete,
  });

  final String title;
  final String status;
  final String detail;
  final Review? review;
  final VoidCallback onTap;
  final VoidCallback onMessageOwner;
  final VoidCallback onReview;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'Confirmed' => const Color(0xFF6E8B75),
      'Completed' => const Color(0xFF8B5A38),
      'Refund requested' => const Color(0xFFB36B9A),
      _ => const Color(0xFFF4510B),
    };

    return Material(
      color: const Color(0xFF493A2F),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
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
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          detail,
                          style: const TextStyle(color: Color(0xFFD8C9BC)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
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
                  IconButton(
                    tooltip: 'Delete activity',
                    onPressed: onDelete,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Color(0xFFD8C9BC),
                      size: 18,
                    ),
                  ),
                ],
              ),
              if (review != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Your review · ${review!.rating.toStringAsFixed(0)}/5 · ${review!.comment}',
                      style: const TextStyle(
                        color: Color(0xFFD8C9BC),
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              Wrap(
                spacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: onMessageOwner,
                    icon: const Icon(Icons.chat_bubble_outline, size: 16),
                    label: const Text('Message owner'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFFFB27F),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  if (status == 'Completed')
                    TextButton.icon(
                      onPressed: onReview,
                      icon: const Icon(Icons.star_outline_rounded, size: 16),
                      label: Text(
                        review == null ? 'Write a review' : 'Edit review',
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFFFB27F),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateReviewDialog extends StatefulWidget {
  const _CreateReviewDialog({required this.rentalName, this.initialReview});

  final String rentalName;
  final Review? initialReview;

  @override
  State<_CreateReviewDialog> createState() => _CreateReviewDialogState();
}

class _CreateReviewDialogState extends State<_CreateReviewDialog> {
  late final TextEditingController _commentController;
  late int _rating;
  bool _showValidation = false;

  @override
  void initState() {
    super.initState();
    _rating = widget.initialReview?.rating.round() ?? 0;
    _commentController = TextEditingController(
      text: widget.initialReview?.comment ?? '',
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _saveReview() {
    final comment = _commentController.text.trim();
    if (_rating == 0 || comment.isEmpty) {
      setState(() => _showValidation = true);
      return;
    }

    Navigator.pop(
      context,
      Review(reviewerName: 'You', comment: comment, rating: _rating.toDouble()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.initialReview == null
            ? 'Review your rental'
            : 'Edit your review',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.rentalName),
            const SizedBox(height: 16),
            const Text(
              'Rate your experience',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                5,
                (index) => IconButton(
                  tooltip: '${index + 1} star${index == 0 ? '' : 's'}',
                  onPressed: () => setState(() {
                    _rating = index + 1;
                    _showValidation = false;
                  }),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                  icon: Icon(
                    index < _rating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: const Color(0xFFFFB27F),
                    size: 32,
                  ),
                ),
              ),
            ),
            TextField(
              controller: _commentController,
              minLines: 3,
              maxLines: 5,
              maxLength: 500,
              onChanged: (_) {
                if (_showValidation) setState(() => _showValidation = false);
              },
              decoration: const InputDecoration(
                labelText: 'Comment',
                hintText: 'How was your rental experience?',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            if (_showValidation)
              const Text(
                'Select a star rating and enter a comment.',
                style: TextStyle(color: Color(0xFFB3261E), fontSize: 12),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saveReview,
          child: Text(widget.initialReview == null ? 'Submit review' : 'Save'),
        ),
      ],
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.name,
    required this.email,
    required this.location,
    required this.canManageListing,
    required this.onUpdateListing,
    required this.onDeleteListing,
    required this.savedListings,
    required this.myListings,
    required this.onUpdate,
    required this.onToggleSaved,
    required this.onMessageOwner,
  });

  final String name;
  final String email;
  final String location;
  final bool Function(RentalListing) canManageListing;
  final ValueChanged<RentalListing> onUpdateListing;
  final ValueChanged<RentalListing> onDeleteListing;
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
                              canManage: canManageListing(listing),
                              onUpdateListing: onUpdateListing,
                              onDeleteListing: onDeleteListing,
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
    return _pageBody(
      SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          children: [
            _brandHeader(),
            const SizedBox(height: 17),
            const Text(
              'Profile',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Your account, your rental community.',
              style: TextStyle(color: Color(0xFFD8C9BC), fontSize: 8),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF493A2F),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: const Color(0xFF70543F)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 23,
                    backgroundColor: const Color(0xFF9B633D),
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
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          email,
                          style: const TextStyle(
                            color: Color(0xFFD8C9BC),
                            fontSize: 7,
                          ),
                        ),
                        Text(
                          location,
                          style: const TextStyle(
                            color: Color(0xFFD8C9BC),
                            fontSize: 7,
                          ),
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
            const SizedBox(height: 14),
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
              title: 'Saved items',
              trailing: '${savedListings.length} saved',
              onTap: () => _showListings(
                context,
                title: 'Saved items',
                listings: savedListings,
                allowSave: true,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('You have been logged out.')),
                  );
                },
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Log out'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFF9A7456)),
                ),
              ),
            ),
          ],
        ),
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
        color: const Color(0xFF493A2F),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      fontSize: 9,
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
                      color: Color(0xFFD8C9BC),
                      fontSize: 7,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFFD8C9BC),
                  size: 15,
                ),
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
