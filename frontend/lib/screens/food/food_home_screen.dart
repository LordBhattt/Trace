// lib/screens/food/food_home_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import '../../services/food_api_service.dart';
import 'restaurant_detail_screen.dart';
import 'address_selection_screen.dart';

class FoodHomeScreen extends StatefulWidget {
  final Map<String, dynamic>? selectedAddress;

  const FoodHomeScreen({super.key, this.selectedAddress});

  @override
  State<FoodHomeScreen> createState() => _FoodHomeScreenState();
}

class _FoodHomeScreenState extends State<FoodHomeScreen> {
  List<dynamic> restaurants = [];
  bool loading = true;
  String selectedFilter = 'All';
  String searchQuery = '';
  String? selectedCategoryTag;

  // Current delivery address
  Map<String, dynamic>? currentAddress;

  late Razorpay _razorpay;
  String? _pendingResaleOrderId;

  final List<Map<String, dynamic>> categories = [
    {'name': 'Pizza', 'icon': '🍕', 'tag': 'pizza'},
    {'name': 'Burger', 'icon': '🍔', 'tag': 'burger'},
    {'name': 'Biryani', 'icon': '🍛', 'tag': 'biryani'},
    {'name': 'North Indian', 'icon': '🍲', 'tag': 'north indian'},
    {'name': 'South Indian', 'icon': '🥘', 'tag': 'south indian'},
  ];

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handleResalePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handleResalePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    
    // Set current address from widget or load from storage
    currentAddress = widget.selectedAddress;
    _loadAddressAndRestaurants();
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  Future<void> _loadAddressAndRestaurants() async {
    // If no address passed, try to load from storage
    if (currentAddress == null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final savedAddressJson = prefs.getString('selected_delivery_address');
        
        if (savedAddressJson != null) {
          currentAddress = jsonDecode(savedAddressJson) as Map<String, dynamic>;
        } else {
          // No address selected - redirect to address selection
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => AddressSelectionScreen(), // REMOVED const
              ),
            );
          }
          return;
        }
      } catch (e) {
        debugPrint('Error loading address: $e');
      }
    } else {
      // Save the passed address
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'selected_delivery_address',
          jsonEncode(currentAddress),
        );
      } catch (e) {
        debugPrint('Error saving address: $e');
      }
    }

    setState(() {});
    await _loadRestaurants();
  }

  Future<void> _loadRestaurants() async {
    if (currentAddress == null) return;

    setState(() => loading = true);

    try {
      final res = await FoodApiService.getRestaurants(
        lat: currentAddress!['lat'],
        lon: currentAddress!['lon'],
        vegOnly: selectedFilter == 'Veg Only',
      );

      setState(() {
        restaurants = res;
      });
    } catch (e) {
      debugPrint('Error loading restaurants: $e');
    }

    setState(() => loading = false);
  }

  List<dynamic> get filteredRestaurants {
    Iterable<dynamic> list = restaurants;

    if (selectedCategoryTag != null) {
      final tag = selectedCategoryTag!.toLowerCase();
      list = list.where((r) {
        final cuisinesRaw = r['cuisines'] ?? [];
        final cuisines = (cuisinesRaw is List ? cuisinesRaw : <dynamic>[])
            .map((e) => e.toString().toLowerCase())
            .toList();

        final joined = cuisines.join(' ');
        return joined.contains(tag);
      });
    }

    if (selectedFilter == 'Rating 4.0+') {
      list = list.where((r) {
        final rating = (r['avgRating'] ?? 0).toDouble();
        return rating >= 4.0;
      });
    }

    if (searchQuery.isNotEmpty) {
      list = list.where((r) {
        final name = (r['name'] ?? '').toString().toLowerCase();
        final cuisines = (r['cuisines'] ?? []).toString().toLowerCase();
        final query = searchQuery.toLowerCase();

        return name.contains(query) || cuisines.contains(query);
      });
    }

    return list.toList();
  }

  void _changeAddress() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => AddressSelectionScreen(), // REMOVED const
      ),
    );
  }

  Future<void> _claimResaleOrder(String orderId) async {
    if (currentAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select delivery address first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final deliveryLocation = {
        'lat': currentAddress!['lat'],
        'lon': currentAddress!['lon'],
        'address': currentAddress!['display_name'] ?? 'Delivery Location',
      };

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
        ),
      );

      final response = await FoodApiService.claimResellOrder(
        orderId,
        deliveryLocation,
      );

      Navigator.pop(context);

      final paymentAmount = (response['paymentAmount'] as num).toDouble();
      _startResalePayment(orderId, paymentAmount);
    } catch (e) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to claim order: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _startResalePayment(String orderId, double amount) async {
    try {
      final razorpayKey = await ApiService.getRazorpayKey();
      _pendingResaleOrderId = orderId;

      var options = {
        'key': razorpayKey,
        'amount': (amount * 100).toInt(),
        'name': 'TRACE Food - Resale',
        'description': '50% off cancelled order',
        'theme': {'color': '#D4AF37'},
      };

      _razorpay.open(options);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _handleResalePaymentSuccess(PaymentSuccessResponse response) async {
    try {
      await FoodApiService.verifyResellPayment(
        orderId: _pendingResaleOrderId!,
        razorpayPaymentId: response.paymentId!,
        razorpayOrderId: response.orderId ?? '',
        razorpaySignature: response.signature!,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order claimed successfully! 🎉'),
          backgroundColor: Colors.green,
        ),
      );

      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Verification failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _handleResalePaymentError(PaymentFailureResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Payment failed: ${response.message}'),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('External wallet: ${response.walletName}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (currentAddress == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0C2C2E),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFF4E4C1)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0C2C2E),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildAddressBar(),
            _buildSearchBar(),
            _buildResaleBanner(),
            _buildCategoryPills(),
            _buildFilters(),
            Expanded(
              child: loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFF4E4C1),
                      ),
                    )
                  : filteredRestaurants.isEmpty
                      ? _buildEmptyState()
                      : _buildRestaurantList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFFF4E4C1)),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          const Text(
            'Order Food',
            style: TextStyle(
              color: Color(0xFFF4E4C1),
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressBar() {
    return GestureDetector(
      onTap: _changeAddress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: const Color(0xFF1A3A3C),
        child: Row(
          children: [
            const Icon(Icons.location_on, color: Color(0xFFD4AF37), size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Delivering to',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    currentAddress!['display_name'] ?? 'Select Address',
                    style: const TextStyle(
                      color: Color(0xFFF4E4C1),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_drop_down,
              color: Color(0xFFD4AF37),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A3A3C),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        onChanged: (value) {
          setState(() {
            searchQuery = value;
          });
        },
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Search for restaurants or cuisines',
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
          prefixIcon: const Icon(Icons.search, color: Color(0xFFF4E4C1)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }

  Widget _buildCategoryPills() {
    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final cat = categories[index];
          final String tag = cat['tag'] as String;
          final bool isSelected = selectedCategoryTag == tag;

          return GestureDetector(
            onTap: () {
              setState(() {
                if (isSelected) {
                  selectedCategoryTag = null;
                } else {
                  selectedCategoryTag = tag;
                }
              });
            },
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              child: Chip(
                label: Row(
                  children: [
                    Text(cat['icon'] as String),
                    const SizedBox(width: 4),
                    Text(cat['name'] as String),
                  ],
                ),
                backgroundColor:
                    isSelected ? const Color(0xFFD4AF37) : const Color(0xFF1A3A3C),
                labelStyle: TextStyle(
                  color: isSelected ? Colors.black : const Color(0xFFF4E4C1),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                side: BorderSide.none,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildResaleBanner() {
    if (currentAddress == null) return const SizedBox();

    return FutureBuilder<List<dynamic>>(
      future: FoodApiService.getNearbyResellOrders(
        lat: currentAddress!['lat'],
        lon: currentAddress!['lon'],
        radiusKm: 5,
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox();
        }

        final resaleOrders = snapshot.data!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.local_fire_department,
                      color: Colors.orange, size: 24),
                  SizedBox(width: 8),
                  Text(
                    'Recently Cancelled - 50% Off!',
                    style: TextStyle(
                      color: Color(0xFFD4AF37),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 180,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: resaleOrders.length,
                itemBuilder: (context, index) {
                  final order = resaleOrders[index];
                  final restaurant = order['restaurantId'] ?? {};
                  final distance = (order['distance'] as num? ?? 0.0).toDouble();
                  final minutesLeft = (order['minutesLeft'] as num? ?? 0).toInt();
                  final resellPrice = (order['resellPrice'] as num? ?? 0).toInt();
                  final originalPrice =
                      (order['amounts']?['finalPayableAmount'] as num? ?? 0).toInt();

                  return GestureDetector(
                    onTap: () => _claimResaleOrder(order['_id']),
                    child: Container(
                      width: 280,
                      margin: const EdgeInsets.only(right: 16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.orange.shade700, Colors.red.shade900],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.orange.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '$minutesLeft min left',
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '${distance.toStringAsFixed(1)} km away',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              restaurant['name']?.toString() ?? 'Restaurant',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${(order['items'] as List?)?.length ?? 0} items',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                            const Spacer(),
                            Row(
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '₹$resellPrice',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      '₹$originalPrice',
                                      style: const TextStyle(
                                        color: Colors.white60,
                                        fontSize: 14,
                                        decoration: TextDecoration.lineThrough,
                                      ),
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                ElevatedButton(
                                  onPressed: () => _claimResaleOrder(order['_id']),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.red,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 10,
                                    ),
                                  ),
                                  child: const Text(
                                    'CLAIM',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  Widget _buildFilters() {
    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _filterChip('All'),
          _filterChip('Veg Only'),
          _filterChip('Rating 4.0+'),
          _filterChip('Fast Delivery'),
        ],
      ),
    );
  }

  Widget _filterChip(String label) {
    final isSelected = selectedFilter == label;
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            selectedFilter = selected ? label : 'All';
            _loadRestaurants();
          });
        },
        backgroundColor: const Color(0xFF1A3A3C),
        selectedColor: const Color(0xFFD4AF37),
        labelStyle: TextStyle(
          color: isSelected ? Colors.black : const Color(0xFFF4E4C1),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        side: BorderSide.none,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.restaurant_outlined,
            size: 80,
            color: Colors.white.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No restaurants found',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your filters',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRestaurantList() {
    return RefreshIndicator(
      onRefresh: _loadRestaurants,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filteredRestaurants.length,
        itemBuilder: (context, index) {
          final restaurant = filteredRestaurants[index] as Map<String, dynamic>;
          return _buildRestaurantCard(restaurant);
        },
      ),
    );
  }

  Widget _buildRestaurantCard(Map<String, dynamic> restaurant) {
    final name = restaurant['name']?.toString() ?? 'Unknown';
    final cuisines = (restaurant['cuisines'] as List?)?.join(', ') ?? '';
    final rating = (restaurant['avgRating'] ?? 4.0).toDouble();
    final distance = restaurant['distance']?.toDouble() ?? 0.0;
    final discount = restaurant['discount'] ?? 0;
    final imageUrl = restaurant['coverImageUrl'] ?? '';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RestaurantDetailScreen(
              restaurantId: restaurant['_id'],
              deliveryAddress: currentAddress!,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A3A3C),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      height: 180,
                      color: Colors.grey[800],
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: 180,
                      color: Colors.grey[800],
                      child: const Icon(Icons.restaurant, size: 50),
                    ),
                  ),
                ),
                if (discount > 0)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$discount% OFF',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: Color(0xFFF4E4C1),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    cuisines,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: rating >= 4.0 ? Colors.green : Colors.orange,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Text(
                              rating.toStringAsFixed(1),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.star,
                              color: Colors.white,
                              size: 12,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      if (distance > 0) ...[
                        Icon(
                          Icons.location_on,
                          size: 16,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${distance.toStringAsFixed(1)} km',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ],
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