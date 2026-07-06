// lib/providers/food_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/restaurant.dart';
import '../models/menu_item.dart';
import '../models/food_order.dart';
import '../services/food_api_service.dart';

/* ----------------------
    CART ITEM CLASS
----------------------- */
class CartItem {
  final MenuItem menuItem;
  int quantity;
  List<AddOn> selectedAddOns;

  CartItem({
    required this.menuItem,
    this.quantity = 1,
    this.selectedAddOns = const [],
  });

  double get total {
    double basePrice = menuItem.price * quantity;
    double addOnsPrice = selectedAddOns.fold(
      0.0,
      (sum, addOn) => sum + (addOn.price * quantity),
    );
    return basePrice + addOnsPrice;
  }

  CartItem copyWith({
    int? quantity,
    List<AddOn>? selectedAddOns,
  }) {
    return CartItem(
      menuItem: menuItem,
      quantity: quantity ?? this.quantity,
      selectedAddOns: selectedAddOns ?? this.selectedAddOns,
    );
  }
}

/* ----------------------
    CART STATE NOTIFIER
----------------------- */
class CartNotifier extends StateNotifier<List<CartItem>> {
  CartNotifier() : super([]);

  String? currentRestaurantId;
  String? currentRestaurantName;

  void addItem(MenuItem item, {List<AddOn> addOns = const []}) {
    // Check if different restaurant
    if (currentRestaurantId != null && currentRestaurantId != item.restaurantId) {
      throw Exception('Cannot add items from different restaurants');
    }

    currentRestaurantId = item.restaurantId;

    // Check if item already in cart
    final existingIndex = state.indexWhere((cartItem) =>
        cartItem.menuItem.id == item.id &&
        _addOnsMatch(cartItem.selectedAddOns, addOns));

    if (existingIndex != -1) {
      // Increase quantity
      final updated = [...state];
      updated[existingIndex] = updated[existingIndex].copyWith(
        quantity: updated[existingIndex].quantity + 1,
      );
      state = updated;
    } else {
      // Add new item
      state = [
        ...state,
        CartItem(
          menuItem: item,
          quantity: 1,
          selectedAddOns: addOns,
        ),
      ];
    }
  }

  void updateQuantity(int index, int quantity) {
    if (quantity <= 0) {
      removeItem(index);
      return;
    }

    final updated = [...state];
    updated[index] = updated[index].copyWith(quantity: quantity);
    state = updated;
  }

  void removeItem(int index) {
    final updated = [...state];
    updated.removeAt(index);
    state = updated;

    if (updated.isEmpty) {
      currentRestaurantId = null;
      currentRestaurantName = null;
    }
  }

  void clear() {
    state = [];
    currentRestaurantId = null;
    currentRestaurantName = null;
  }

  double get subtotal {
    return state.fold(0.0, (sum, item) => sum + item.total);
  }

  int get totalItems {
    return state.fold(0, (sum, item) => sum + item.quantity);
  }

  bool _addOnsMatch(List<AddOn> a, List<AddOn> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].label != b[i].label) return false;
    }
    return true;
  }
}

final cartProvider = StateNotifierProvider<CartNotifier, List<CartItem>>((ref) {
  return CartNotifier();
});

/* ----------------------
    RESTAURANTS PROVIDER
----------------------- */
final restaurantsProvider = FutureProvider.family<List<Restaurant>, Map<String, dynamic>>((ref, params) async {
  final results = await FoodApiService.getRestaurants(
    lat: params['lat'],
    lon: params['lon'],
    cuisine: params['cuisine'],
    vegOnly: params['vegOnly'],
    search: params['search'],
    sortBy: params['sortBy'],
  );

  return results.map((json) => Restaurant.fromJson(json)).toList();
});

/* ----------------------
    RESTAURANT DETAILS PROVIDER
----------------------- */
final restaurantDetailsProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, restaurantId) async {
  return await FoodApiService.getRestaurantDetails(restaurantId);
});

/* ----------------------
    ORDER HISTORY PROVIDER
----------------------- */
final orderHistoryProvider = FutureProvider<List<FoodOrder>>((ref) async {
  final results = await FoodApiService.getOrderHistory();
  return results.map((json) => FoodOrder.fromJson(json)).toList();
});

/* ----------------------
    RESELL ORDERS PROVIDER
----------------------- */
final resellOrdersProvider = FutureProvider.family<List<FoodOrder>, Map<String, double>>((ref, location) async {
  final results = await FoodApiService.getNearbyResellOrders(
    lat: location['lat']!,
    lon: location['lon']!,
  );
  return results.map((json) => FoodOrder.fromJson(json)).toList();
});

/* ----------------------
    CURRENT ORDER PROVIDER
----------------------- */
final currentOrderProvider = StateProvider<FoodOrder?>((ref) => null);

/* ----------------------
    SELECTED DELIVERY LOCATION
----------------------- */
class DeliveryLocationState {
  final double? lat;
  final double? lon;
  final String? address;

  DeliveryLocationState({this.lat, this.lon, this.address});

  bool get isSet => lat != null && lon != null && address != null;

  Map<String, dynamic> toJson() {
    return {
      'lat': lat,
      'lon': lon,
      'address': address,
    };
  }
}

final deliveryLocationProvider = StateProvider<DeliveryLocationState>((ref) {
  return DeliveryLocationState();
});