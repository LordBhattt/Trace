// lib/services/cart_manager.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CartManager {
  static const String _cartKey = 'food_carts';
  
  // Singleton pattern
  static final CartManager _instance = CartManager._internal();
  factory CartManager() => _instance;
  CartManager._internal();

  // In-memory cache of all carts
  Map<String, RestaurantCart> _carts = {};

  /// Initialize - load carts from storage
  Future<void> initialize() async {
    await _loadCarts();
  }

  /// Load all carts from SharedPreferences
  Future<void> _loadCarts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartsJson = prefs.getString(_cartKey);
      
      if (cartsJson != null) {
        final Map<String, dynamic> decoded = jsonDecode(cartsJson);
        _carts = decoded.map((key, value) => 
          MapEntry(key, RestaurantCart.fromJson(value))
        );
      }
    } catch (e) {
      print('Error loading carts: $e');
      _carts = {};
    }
  }

  /// Save all carts to SharedPreferences - NOW PUBLIC
  Future<void> saveCarts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartsJson = jsonEncode(
        _carts.map((key, value) => MapEntry(key, value.toJson()))
      );
      await prefs.setString(_cartKey, cartsJson);
    } catch (e) {
      print('Error saving carts: $e');
    }
  }

  /// Get cart for a specific restaurant
  RestaurantCart getCart(String restaurantId) {
    if (!_carts.containsKey(restaurantId)) {
      _carts[restaurantId] = RestaurantCart(restaurantId: restaurantId);
    }
    return _carts[restaurantId]!;
  }

  /// Add item to restaurant cart
  Future<void> addItem(String restaurantId, CartItem item) async {
    final cart = getCart(restaurantId);
    cart.addItem(item);
    await saveCarts();
  }

  /// Update item quantity
  Future<void> updateQuantity(String restaurantId, String itemId, int quantity) async {
    final cart = getCart(restaurantId);
    cart.updateQuantity(itemId, quantity);
    
    // Remove cart if empty
    if (cart.isEmpty) {
      _carts.remove(restaurantId);
    }
    
    await saveCarts();
  }

  /// Remove item from cart
  Future<void> removeItem(String restaurantId, String itemId) async {
    final cart = getCart(restaurantId);
    cart.removeItem(itemId);
    
    // Remove cart if empty
    if (cart.isEmpty) {
      _carts.remove(restaurantId);
    }
    
    await saveCarts();
  }

  /// Clear cart for a restaurant
  Future<void> clearCart(String restaurantId) async {
    _carts.remove(restaurantId);
    await saveCarts();
  }

  /// Clear all carts
  Future<void> clearAllCarts() async {
    _carts.clear();
    await saveCarts();
  }

  /// Get all restaurant IDs that have items in cart
  List<String> getRestaurantsWithCarts() {
    return _carts.keys.where((id) => !_carts[id]!.isEmpty).toList();
  }

  /// Check if restaurant has items in cart
  bool hasCart(String restaurantId) {
    return _carts.containsKey(restaurantId) && !_carts[restaurantId]!.isEmpty;
  }

  /// Get total items across all carts
  int getTotalItemsAcrossAllCarts() {
    return _carts.values.fold(0, (sum, cart) => sum + cart.totalItems);
  }

  /// Get number of restaurants with items
  int getRestaurantCount() {
    return _carts.values.where((cart) => !cart.isEmpty).length;
  }

  /// Get all carts with items
  List<RestaurantCart> getAllCartsWithItems() {
    return _carts.values.where((cart) => !cart.isEmpty).toList();
  }
}

/// Represents a cart for a single restaurant
class RestaurantCart {
  final String restaurantId;
  String? restaurantName;
  String? restaurantImage;
  List<CartItem> items;

  RestaurantCart({
    required this.restaurantId,
    this.restaurantName,
    this.restaurantImage,
    this.items = const [],
  });

  /// Add or update item in cart
  void addItem(CartItem newItem) {
    final existingIndex = items.indexWhere((item) => item.id == newItem.id);
    
    if (existingIndex != -1) {
      items[existingIndex] = items[existingIndex].copyWith(
        quantity: items[existingIndex].quantity + newItem.quantity,
      );
    } else {
      items = [...items, newItem];
    }
  }

  /// Update item quantity
  void updateQuantity(String itemId, int quantity) {
    if (quantity <= 0) {
      removeItem(itemId);
      return;
    }

    final index = items.indexWhere((item) => item.id == itemId);
    if (index != -1) {
      items[index] = items[index].copyWith(quantity: quantity);
    }
  }

  /// Remove item from cart
  void removeItem(String itemId) {
    items = items.where((item) => item.id != itemId).toList();
  }

  /// Clear all items
  void clear() {
    items = [];
  }

  /// Check if cart is empty
  bool get isEmpty => items.isEmpty;

  /// Get total items count
  int get totalItems => items.fold(0, (sum, item) => sum + item.quantity);

  /// Get subtotal
  double get subtotal => items.fold(0.0, (sum, item) => sum + item.total);

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'restaurantId': restaurantId,
      'restaurantName': restaurantName,
      'restaurantImage': restaurantImage,
      'items': items.map((item) => item.toJson()).toList(),
    };
  }

  /// Create from JSON
  factory RestaurantCart.fromJson(Map<String, dynamic> json) {
    return RestaurantCart(
      restaurantId: json['restaurantId'] ?? '',
      restaurantName: json['restaurantName'],
      restaurantImage: json['restaurantImage'],
      items: (json['items'] as List?)
          ?.map((item) => CartItem.fromJson(item))
          .toList() ?? [],
    );
  }
}

/// Represents a single item in the cart
class CartItem {
  final String id;
  final String name;
  final double price;
  final int quantity;
  final String? imageUrl;
  final bool isVeg;
  final String? description;

  CartItem({
    required this.id,
    required this.name,
    required this.price,
    this.quantity = 1,
    this.imageUrl,
    this.isVeg = true,
    this.description,
  });

  double get total => price * quantity;

  CartItem copyWith({
    String? id,
    String? name,
    double? price,
    int? quantity,
    String? imageUrl,
    bool? isVeg,
    String? description,
  }) {
    return CartItem(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      imageUrl: imageUrl ?? this.imageUrl,
      isVeg: isVeg ?? this.isVeg,
      description: description ?? this.description,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'quantity': quantity,
      'imageUrl': imageUrl,
      'isVeg': isVeg,
      'description': description,
    };
  }

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      quantity: json['quantity'] ?? 1,
      imageUrl: json['imageUrl'],
      isVeg: json['isVeg'] ?? true,
      description: json['description'],
    );
  }

  /// Convert to API format
  Map<String, dynamic> toApiFormat() {
    return {
      'menuItemId': id,
      'itemId': id,
      '_id': id,
      'name': name,
      'price': price,
      'quantity': quantity,
    };
  }
}