import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class FoodApiService {
  static const String baseUrl =
      "https://trace-payment-server.onrender.com/api/food";

  /* ----------------------
      AUTH HEADER
  ----------------------- */
  static Future<Map<String, String>> _authHeader() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';

    return {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    };
  }

  /* ----------------------
      GET RESTAURANTS
      Used on FoodHomeScreen
  ----------------------- */
  static Future<List<dynamic>> getRestaurants({
    double? lat,
    double? lon,
    String? cuisine,
    bool? vegOnly,
    String? search,
    String? sortBy,
  }) async {
    final queryParams = <String, String>{};

    if (lat != null) queryParams['lat'] = lat.toString();
    if (lon != null) queryParams['lon'] = lon.toString();
    if (cuisine != null && cuisine.isNotEmpty) {
      queryParams['cuisine'] = cuisine;
    }
    if (vegOnly != null) queryParams['vegOnly'] = vegOnly.toString();
    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }
    if (sortBy != null && sortBy.isNotEmpty) {
      queryParams['sortBy'] = sortBy;
    }

    final uri = Uri.parse('$baseUrl/restaurants')
        .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

    final res = await http.get(uri);

    if (res.statusCode == 200) {
      return jsonDecode(res.body) as List;
    }

    throw Exception('Failed to load restaurants: ${res.statusCode} ${res.body}');
  }

  /* ----------------------
      GET RESTAURANT DETAILS
  ----------------------- */
  static Future<Map<String, dynamic>> getRestaurantDetails(
    String restaurantId,
  ) async {
    final url = Uri.parse('$baseUrl/restaurants/$restaurantId');
    final res = await http.get(url);

    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }

    throw Exception('Failed to load restaurant details: ${res.statusCode} ${res.body}');
  }

  /* ----------------------
      SEARCH MENU ITEMS (optional)
  ----------------------- */
  static Future<List<dynamic>> searchMenuItems({
    String? keyword,
    String? tag,
    bool? vegOnly,
  }) async {
    final queryParams = <String, String>{};

    if (keyword != null && keyword.isNotEmpty) {
      queryParams['keyword'] = keyword;
    }
    if (tag != null && tag.isNotEmpty) {
      queryParams['tag'] = tag;
    }
    if (vegOnly != null) {
      queryParams['vegOnly'] = vegOnly.toString();
    }

    final uri = Uri.parse('$baseUrl/items/search')
        .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);
    final res = await http.get(uri);

    if (res.statusCode == 200) {
      return jsonDecode(res.body) as List;
    }

    throw Exception('Failed to search items: ${res.statusCode} ${res.body}');
  }

  /* ----------------------
      PRICE PREVIEW
  ----------------------- */
  static Future<Map<String, dynamic>> getPricePreview({
    required List<Map<String, dynamic>> items,
    required String restaurantId,
    required Map<String, dynamic> deliveryLocation,
    String preferredMode = 'dedicated_delivery',
  }) async {
    final url = Uri.parse('$baseUrl/orders/price-preview');

    // Normalize items to expected backend shape:
    final normalizedItems = items.map((i) {
      final menuItemId = i['menuItemId'] ??
          i['itemId'] ??
          i['_id'] ??
          i['id'] ??
          '';
      final quantity = (i['quantity'] is num)
          ? (i['quantity'] as num).toInt()
          : int.tryParse(i['quantity']?.toString() ?? '1') ?? 1;
      final addOnsRaw = i['addOns'] ?? i['addons'] ?? i['selectedAddOns'] ?? [];
      final addOnsList = (addOnsRaw is List)
          ? addOnsRaw.map((a) {
              if (a is Map<String, dynamic>) {
                return {
                  'label': a['label'] ?? a['name'] ?? '',
                  'price': (a['price'] ?? 0),
                  'id': a['_id'] ?? a['id'],
                };
              } else {
                return {'label': a.toString(), 'price': 0};
              }
            }).toList()
          : [];

      return {
        'menuItemId': menuItemId,
        'quantity': quantity,
        'addOns': addOnsList,
      };
    }).toList();

    final body = {
      'items': normalizedItems,
      'restaurantId': restaurantId,
      'deliveryLat': deliveryLocation['lat'],
      'deliveryLon': deliveryLocation['lon'],
      'deliveryMode': preferredMode,
    };

    final res = await http.post(
      url,
      headers: await _authHeader(),
      body: jsonEncode(body),
    );

    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }

    throw Exception('Failed to get price preview: ${res.statusCode} ${res.body}');
  }

  /* ----------------------
      CREATE FOOD ORDER
  ----------------------- */
  static Future<Map<String, dynamic>> createFoodOrder({
    required String restaurantId,
    required List<Map<String, dynamic>> items,
    required Map<String, dynamic> deliveryLocation,
    required String deliveryMode,
    required Map<String, dynamic> amounts,
  }) async {
    final url = Uri.parse('$baseUrl/orders');

    // Normalize items similar to price preview but keep extra fields if present
    final normalizedItems = items.map((i) {
      final menuItemId = i['menuItemId'] ?? i['itemId'] ?? i['_id'] ?? i['id'] ?? '';
      final quantity = (i['quantity'] is num)
          ? (i['quantity'] as num).toInt()
          : int.tryParse(i['quantity']?.toString() ?? '1') ?? 1;
      final name = i['name'] ?? i['label'] ?? '';
      final addOnsRaw = i['addOns'] ?? i['addons'] ?? i['selectedAddOns'] ?? [];
      final addOnsList = (addOnsRaw is List)
          ? addOnsRaw.map((a) {
              if (a is Map<String, dynamic>) {
                return {
                  'label': a['label'] ?? a['name'] ?? '',
                  'price': (a['price'] ?? 0),
                };
              } else {
                return {'label': a.toString(), 'price': 0};
              }
            }).toList()
          : [];

      return {
        'menuItemId': menuItemId,
        'quantity': quantity,
        'name': name,
        'addOns': addOnsList,
      };
    }).toList();

    final body = {
      'restaurantId': restaurantId,
      'items': normalizedItems,
      'deliveryLat': deliveryLocation['lat'],
      'deliveryLon': deliveryLocation['lon'],
      'deliveryAddress': deliveryLocation['address'] ?? '',
      'deliveryMode': deliveryMode,
      'amounts': amounts,
    };

    final res = await http.post(
      url,
      headers: await _authHeader(),
      body: jsonEncode(body),
    );

    if (res.statusCode == 200 || res.statusCode == 201) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }

    throw Exception('Failed to create order: ${res.statusCode} ${res.body}');
  }

  /* ----------------------
      CREATE RAZORPAY ORDER FOR FOOD
  ----------------------- */
  static Future<Map<String, dynamic>> createRazorpayOrderForFood({
    required String orderId,
    required double amount,
  }) async {
    final url =
        Uri.parse('$baseUrl/orders/$orderId/create-razorpay-order');

    final body = {
      'amount': amount,
    };

    final res = await http.post(
      url,
      headers: await _authHeader(),
      body: jsonEncode(body),
    );

    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }

    throw Exception('Failed to create Razorpay order: ${res.statusCode} ${res.body}');
  }

  /* ----------------------
      VERIFY PAYMENT (ONLINE)
  ----------------------- */
  static Future<Map<String, dynamic>> verifyFoodPayment({
    required String orderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    final url = Uri.parse('$baseUrl/orders/$orderId/verify-payment');

    final body = {
      'razorpayPaymentId': razorpayPaymentId,
      'razorpaySignature': razorpaySignature,
    };

    final res = await http.post(
      url,
      headers: await _authHeader(),
      body: jsonEncode(body),
    );

    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }

    throw Exception('Payment verification failed: ${res.statusCode} ${res.body}');
  }

  /* ----------------------
      GET ORDER DETAILS
  ----------------------- */
  static Future<Map<String, dynamic>> getOrderDetails(
    String orderId,
  ) async {
    final url = Uri.parse('$baseUrl/orders/$orderId');
    final res = await http.get(
      url,
      headers: await _authHeader(),
    );

    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }

    throw Exception('Failed to load order: ${res.statusCode} ${res.body}');
  }

  /* ----------------------
      GET ORDER HISTORY
  ----------------------- */
  static Future<List<dynamic>> getOrderHistory() async {
    final url = Uri.parse('$baseUrl/orders');
    final res = await http.get(
      url,
      headers: await _authHeader(),
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return (data['orders'] ?? []) as List<dynamic>;
    }

    throw Exception('Failed to load order history: ${res.statusCode} ${res.body}');
  }

  /* ----------------------
      CANCEL ORDER
  ----------------------- */
  static Future<Map<String, dynamic>> cancelOrder(
    String orderId,
    String reason,
  ) async {
    final url = Uri.parse('$baseUrl/orders/$orderId/cancel');

    final body = {'reason': reason};

    final res = await http.post(
      url,
      headers: await _authHeader(),
      body: jsonEncode(body),
    );

    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }

    throw Exception('Failed to cancel order: ${res.statusCode} ${res.body}');
  }

  /* ----------------------
      GET NEARBY RESELL ORDERS
  ----------------------- */
  static Future<List<dynamic>> getNearbyResellOrders({
    required double lat,
    required double lon,
    double radiusKm = 5,
  }) async {
    final queryParams = {
      'lat': lat.toString(),
      'lon': lon.toString(),
      'radius': radiusKm.toString(),
    };

    final uri = Uri.parse('$baseUrl/resell/nearby')
        .replace(queryParameters: queryParams);
    final res = await http.get(
      uri,
      headers: await _authHeader(),
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return (data['orders'] ?? []) as List<dynamic>;
    }

    throw Exception('Failed to load resell orders: ${res.statusCode} ${res.body}');
  }

  /* ----------------------
      CLAIM RESELL ORDER
  ----------------------- */
  static Future<Map<String, dynamic>> claimResellOrder(
    String orderId,
    Map<String, dynamic> deliveryLocation,
  ) async {
    final url = Uri.parse('$baseUrl/resell/$orderId/claim');

    final body = {
      'newDeliveryLat': deliveryLocation['lat'],
      'newDeliveryLon': deliveryLocation['lon'],
      'newDeliveryAddress': deliveryLocation['address'],
    };

    final res = await http.post(
      url,
      headers: await _authHeader(),
      body: jsonEncode(body),
    );

    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }

    throw Exception('Failed to claim order: ${res.statusCode} ${res.body}');
  }

  /* ----------------------
      VERIFY RESELL PAYMENT
  ----------------------- */
  static Future<Map<String, dynamic>> verifyResellPayment({
    required String orderId,
    required String razorpayPaymentId,
    required String razorpayOrderId,
    required String razorpaySignature,
  }) async {
    final url =
        Uri.parse('$baseUrl/resell/$orderId/verify-payment');

    final body = {
      'razorpayPaymentId': razorpayPaymentId,
      'razorpayOrderId': razorpayOrderId,
      'razorpaySignature': razorpaySignature,
    };

    final res = await http.post(
      url,
      headers: await _authHeader(),
      body: jsonEncode(body),
    );

    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }

    throw Exception('Resell payment verification failed: ${res.statusCode} ${res.body}');
  }
}
