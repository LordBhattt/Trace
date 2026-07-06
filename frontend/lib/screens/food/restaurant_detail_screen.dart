// lib/screens/food/restaurant_detail_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/food_api_service.dart';
import '../../services/cart_manager.dart';
import 'cart_screen.dart';

class RestaurantDetailScreen extends StatefulWidget {
  final String restaurantId;
  final Map<String, dynamic> deliveryAddress; // ADDED

  const RestaurantDetailScreen({
    super.key,
    required this.restaurantId,
    required this.deliveryAddress, // ADDED
  });

  @override
  State<RestaurantDetailScreen> createState() =>
      _RestaurantDetailScreenState();
}

class _RestaurantDetailScreenState extends State<RestaurantDetailScreen> {
  Map<String, dynamic>? restaurant;
  List<dynamic> menu = [];
  bool loading = true;

  final cartManager = CartManager();

  Map<String, dynamic>? resellDeal;
  Timer? _resellTimer;
  Duration? _dealRemaining;

  @override
  void initState() {
    super.initState();
    _loadRestaurant();
    _loadResellDeal();
    
    // Force refresh of cart display
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _resellTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadRestaurant() async {
    setState(() => loading = true);

    try {
      final res = await FoodApiService.getRestaurantDetails(widget.restaurantId);

      if (res['success'] == true) {
        setState(() {
          restaurant = res['restaurant'];
          menu = restaurant!['menu'] ?? [];
          
          // Set restaurant name in cart if it has items
          final cart = cartManager.getCart(widget.restaurantId);
          if (cart.items.isNotEmpty && cart.restaurantName == null) {
            cart.restaurantName = restaurant!['name'];
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading restaurant: $e');
    }

    setState(() => loading = false);
  }

  Future<void> _loadResellDeal() async {
    try {
      final res = await FoodApiService.getNearbyResellOrders(
        lat: 19.0760,
        lon: 72.8777,
      );

      final deal = res.firstWhere(
        (d) => d['restaurantId'] == widget.restaurantId,
        orElse: () => null,
      );

      if (deal != null) {
        setState(() {
          resellDeal = deal;
          final expireAt = DateTime.parse(deal['expiresAt']);
          _dealRemaining = expireAt.difference(DateTime.now());
          _startDealTimer();
        });
      }
    } catch (e) {
      debugPrint("No resell deals found: $e");
    }
  }

  void _startDealTimer() {
    _resellTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (!mounted) return;

        setState(() {
          final expireAt = DateTime.parse(resellDeal!['expiresAt']);
          _dealRemaining = expireAt.difference(DateTime.now());

          if (_dealRemaining!.inSeconds <= 0) {
            resellDeal = null;
            timer.cancel();
          }
        });
      },
    );
  }

  void _updateCart(Map<String, dynamic> itemData, int quantityChange) async {
    final itemId = itemData['_id'] ?? '';
    final cart = cartManager.getCart(widget.restaurantId);
    
    final existingItem = cart.items.firstWhere(
      (item) => item.id == itemId,
      orElse: () => CartItem(id: '', name: '', price: 0, quantity: 0),
    );
    
    final newQuantity = existingItem.quantity + quantityChange;

    if (newQuantity <= 0) {
      await cartManager.removeItem(widget.restaurantId, itemId);
    } else if (existingItem.id.isEmpty) {
      await cartManager.addItem(
        widget.restaurantId,
        CartItem(
          id: itemId,
          name: itemData['name'] ?? 'Item',
          price: (itemData['price'] ?? 0).toDouble(),
          quantity: newQuantity,
          imageUrl: itemData['imageUrl'],
          isVeg: itemData['isVeg'] ?? true,
          description: itemData['description'],
        ),
      );
      
      if (cart.restaurantName == null && restaurant != null) {
        cart.restaurantName = restaurant!['name'];
        cart.restaurantImage = restaurant!['coverImageUrl'];
        await cartManager.saveCarts();
      }
    } else {
      await cartManager.updateQuantity(widget.restaurantId, itemId, newQuantity);
    }

    if (mounted) setState(() {});
  }

  int _getItemQuantity(String itemId) {
    final cart = cartManager.getCart(widget.restaurantId);
    final item = cart.items.firstWhere(
      (item) => item.id == itemId,
      orElse: () => CartItem(id: '', name: '', price: 0, quantity: 0),
    );
    return item.quantity;
  }

  int get totalItems {
    return cartManager.getCart(widget.restaurantId).totalItems;
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0C2C2E),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFF4E4C1)),
        ),
      );
    }

    if (restaurant == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0C2C2E),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0C2C2E),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFFF4E4C1)),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(
          child: Text(
            'Restaurant not found',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    final name = restaurant!['name'] ?? 'Unknown';
    final description = restaurant!['description'] ?? '';
    final cuisines = (restaurant!['cuisines'] as List?)?.join(', ') ?? '';
    final rating = (restaurant!['avgRating'] ?? 4.0).toDouble();
    final coverImage = restaurant!['coverImageUrl'] ?? '';
    final isVegOnly = restaurant!['isVegOnly'] ?? false;

    return Scaffold(
      backgroundColor: const Color(0xFF0C2C2E),
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 240,
                pinned: true,
                backgroundColor: const Color(0xFF0C2C2E),
                leading: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: CachedNetworkImage(
                    imageUrl: coverImage,
                    fit: BoxFit.cover,
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[800],
                      child: const Icon(Icons.restaurant, size: 80),
                    ),
                  ),
                ),
              ),

              if (resellDeal != null)
                SliverToBoxAdapter(child: _buildResellBanner()),

              SliverToBoxAdapter(
                child: _buildRestaurantHeader(
                  name,
                  cuisines,
                  description,
                  isVegOnly,
                  rating,
                ),
              ),

              ...menu.map((category) => _buildMenuCategory(category)),

              const SliverToBoxAdapter(child: SizedBox(height: 100))
            ],
          ),

          if (totalItems > 0)
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: _buildCartButton(),
            ),
        ],
      ),
    );
  }

  Widget _buildResellBanner() {
    final amounts = resellDeal!['amounts'];
    final original = (amounts['originalPrice'] ?? 0).toInt();
    final discounted = (amounts['resellPrice'] ?? 0).toInt();

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CartScreen(
              restaurant: restaurant!,
              cartItems: [],
              resellDeal: resellDeal,
              deliveryAddress: widget.deliveryAddress, // PASS THE ADDRESS
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Colors.orange, Colors.deepOrange],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(Icons.local_fire_department,
                color: Colors.white, size: 34),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "🔥 Hot Deal Nearby!",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "Cancelled order at 50% OFF • ₹$discounted (was ₹$original)",
                    style: const TextStyle(color: Colors.white),
                  ),
                  if (_dealRemaining != null)
                    Text(
                      "⏳ Expires in ${_dealRemaining!.inMinutes}:${(_dealRemaining!.inSeconds % 60).toString().padLeft(2, '0')}",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 12,
                      ),
                    )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRestaurantHeader(
    String name,
    String cuisines,
    String description,
    bool isVegOnly,
    double rating,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    color: Color(0xFFF4E4C1),
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (isVegOnly)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'PURE VEG',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            cuisines,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 16,
            ),
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 14,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: rating >= 4.0 ? Colors.green : Colors.orange,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Text(
                      rating.toStringAsFixed(1),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.star, color: Colors.white, size: 16),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCategory(Map<String, dynamic> category) {
    final categoryName = category['name'] ?? 'Menu';
    final items = category['items'] as List? ?? [];

    if (items.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox());
    }

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
            child: Text(
              categoryName,
              style: const TextStyle(
                color: Color(0xFFD4AF37),
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ...items.map((item) => _buildMenuItem(item)),
        ],
      ),
    );
  }

  Widget _buildMenuItem(Map<String, dynamic> item) {
    final itemId = item['_id'];
    final name = item['name'] ?? 'Unknown';
    final description = item['description'] ?? '';
    final price = (item['price'] ?? 0).toInt();
    final imageUrl = item['imageUrl'] ?? '';
    final isVeg = item['isVeg'] ?? true;
    final tags = (item['tags'] as List?)?.cast<String>() ?? [];

    final quantity = _getItemQuantity(itemId);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A3A3C),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isVeg ? Colors.green : Colors.red,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.circle,
                        size: 12,
                        color: isVeg ? Colors.green : Colors.red,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (tags.contains("bestseller"))
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          "BESTSELLER",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  name,
                  style: const TextStyle(
                    color: Color(0xFFF4E4C1),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  '₹$price',
                  style: const TextStyle(
                    color: Color(0xFFD4AF37),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            children: [
              if (imageUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                    errorWidget: (context, url, error) => Container(
                      width: 100,
                      height: 100,
                      color: Colors.grey[800],
                      child: const Icon(Icons.restaurant),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              quantity == 0
                  ? ElevatedButton(
                      onPressed: () => _updateCart(item, 1),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD4AF37),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'ADD',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4AF37),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove, color: Colors.black),
                            onPressed: () => _updateCart(item, -1),
                            padding: const EdgeInsets.all(8),
                            constraints: const BoxConstraints(),
                          ),
                          Text(
                            '$quantity',
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add, color: Colors.black),
                            onPressed: () => _updateCart(item, 1),
                            padding: const EdgeInsets.all(8),
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCartButton() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFD4AF37), Color(0xFFF4E4C1)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD4AF37).withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: () async {
          if (restaurant == null) return;

          final cart = cartManager.getCart(widget.restaurantId);
          final cartItems = cart.items.map((item) => item.toApiFormat()).toList();

          // Navigate directly to CartScreen with address
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CartScreen(
                restaurant: {
                  '_id': restaurant!['_id'] ?? '',
                  'name': restaurant!['name'] ?? 'Restaurant',
                  'coverImageUrl': restaurant!['coverImageUrl'] ?? '',
                  'cuisines': restaurant!['cuisines'] ?? [],
                  'avgRating': restaurant!['avgRating'] ?? 4.0,
                },
                cartItems: cartItems,
                deliveryAddress: widget.deliveryAddress, // PASS THE ADDRESS
              ),
            ),
          );
          
          // Refresh cart display when returning
          if (mounted) setState(() {});
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$totalItems ${totalItems == 1 ? 'item' : 'items'}',
              style: const TextStyle(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 16),
            const Text(
              'View Cart',
              style: TextStyle(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.arrow_forward,
              color: Colors.black,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}