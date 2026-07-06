// lib/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // 🔗 LIVE BACKEND (Render)
  static const String baseUrl = "https://trace-payment-server.onrender.com/api";

  /* ----------------------
      AUTH
  ----------------------- */
  static Future<Map<String, dynamic>> login(
      String email, String password) async {
    final url = Uri.parse("$baseUrl/auth/login");
    final res = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email, "password": password}),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> signup(
      String name, String email, String phone, String password) async {
    final url = Uri.parse("$baseUrl/auth/signup");
    final res = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "name": name,
        "email": email,
        "phone": phone,
        "password": password,
      }),
    );
    return jsonDecode(res.body);
  }

  /* ----------------------
      TOKEN HEADER
  ----------------------- */
  static Future<Map<String, String>> _authHeader() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';

    print("🔐 Using JWT Token: $token");

    return {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    };
  }

  /* ----------------------
      USER DATA
  ----------------------- */
  static Future<Map<String, dynamic>> getUserProfile() async {
    final url = Uri.parse("$baseUrl/user/profile");
    final res = await http.get(url, headers: await _authHeader());
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> getUserStats() async {
    final url = Uri.parse("$baseUrl/user/stats");
    final res = await http.get(url, headers: await _authHeader());
    return jsonDecode(res.body);
  }

  /* ----------------------
      UPDATE FCM TOKEN
  ----------------------- */
  static Future<Map<String, dynamic>> updateFCMToken(String token) async {
    final url = Uri.parse("$baseUrl/user/fcm-token");

    final res = await http.post(
      url,
      headers: await _authHeader(),
      body: jsonEncode({"token": token}),
    );

    return jsonDecode(res.body);
  }

  /* ----------------------
      🔥 RIDE HISTORY (FULL LOGGING)
  ----------------------- */
  static Future<List<dynamic>> getRideHistory() async {
    final url = Uri.parse("$baseUrl/cabride/history");

    final headers = await _authHeader();
    print("📡 Calling Ride History with headers: $headers");

    final res = await http.get(url, headers: headers);

    print("📡 RESPONSE STATUS: ${res.statusCode}");
    print("📡 RAW RESPONSE: ${res.body}");

    Map<String, dynamic> json;
    try {
      json = jsonDecode(res.body);
    } catch (e) {
      print("❌ JSON PARSE ERROR: $e");
      return [];
    }

    if (json['success'] != true) {
      print("❌ Backend Error: ${json['message']}");
      return [];
    }

    if (json['rides'] == null) {
      print("⚠️ No 'rides' array in backend response!");
      return [];
    }

    print("✅ Fetched ${json['rides'].length} rides");
    return json['rides'];
  }

  /* ----------------------
      CREATE RIDE
  ----------------------- */
  static Future<Map<String, dynamic>> createRide({
    required double pickupLat,
    required double pickupLng,
    required double dropLat,
    required double dropLng,
    required double distanceKm,
    required int etaMin,
    required int foodStops,
  }) async {
    final url = Uri.parse("$baseUrl/cabride/create");

    final body = {
      "pickup": {"label": "Pickup", "lat": pickupLat, "lon": pickupLng},
      "drop": {"label": "Drop", "lat": dropLat, "lon": dropLng},
      "distanceKm": distanceKm,
      "etaMin": etaMin,
      "foodStops": foodStops,
      "selectedSuggestions": [],
    };

    final res = await http.post(
      url,
      headers: await _authHeader(),
      body: jsonEncode(body),
    );

    return jsonDecode(res.body);
  }

  /* ----------------------
      UPDATE RIDE STATUS
  ----------------------- */
  static Future<Map<String, dynamic>> updateRideStatus(
      String rideId, String status) async {
    final url = Uri.parse("$baseUrl/cabride/update-status");

    final res = await http.patch(
      url,
      headers: await _authHeader(),
      body: jsonEncode({"rideId": rideId, "status": status}),
    );

    return jsonDecode(res.body);
  }

  /* ----------------------
      CANCEL RIDE
  ----------------------- */
  static Future<Map<String, dynamic>> cancelRide(String rideId) async {
    final url = Uri.parse("$baseUrl/cabride/cancel");

    final res = await http.post(
      url,
      headers: await _authHeader(),
      body: jsonEncode({"rideId": rideId}),
    );

    return jsonDecode(res.body);
  }

  /* ----------------------
      COMPLETE RIDE
  ----------------------- */
  static Future<Map<String, dynamic>> completeRide(String rideId) async {
    final url = Uri.parse("$baseUrl/cabride/complete");

    final res = await http.post(
      url,
      headers: await _authHeader(),
      body: jsonEncode({"rideId": rideId}),
    );

    return jsonDecode(res.body);
  }

  /* ----------------------
      RAZORPAY KEY
  ----------------------- */
  static Future<String?> getRazorpayKey() async {
    final url = Uri.parse("$baseUrl/payment/key");

    final res = await http.get(url, headers: await _authHeader());

    final data = jsonDecode(res.body);
    if (data['success'] == true) {
      return (data['keyId'] ?? data['key'] ?? '').toString();
    }
    return null;
  }

  /* ----------------------
      CREATE PAYMENT ORDER
  ----------------------- */
  static Future<Map<String, dynamic>> createPaymentOrder(String rideId) async {
    final url = Uri.parse("$baseUrl/payment/create-order");

    final res = await http.post(
      url,
      headers: await _authHeader(),
      body: jsonEncode({"rideId": rideId}),
    );

    return jsonDecode(res.body);
  }

  /* ----------------------
      VERIFY PAYMENT
  ----------------------- */
  static Future<Map<String, dynamic>> verifyPayment({
    required String paymentId,
    required String orderId,
    required String signature,
    required String rideId,
  }) async {
    final url = Uri.parse("$baseUrl/payment/verify");

    final body = {
      "paymentId": paymentId,
      "orderId": orderId,
      "signature": signature,
      "rideId": rideId,
    };

    final res = await http.post(
      url,
      headers: await _authHeader(),
      body: jsonEncode(body),
    );

    return jsonDecode(res.body);
  }
  static Future<Map<String, dynamic>> getRestaurants({double? lat, double? lon, bool vegOnly = false}) async {
  final queryParams = <String, String>{};
  if (lat != null) queryParams['lat'] = lat.toString();
  if (lon != null) queryParams['lon'] = lon.toString();
  if (vegOnly) queryParams['vegOnly'] = 'true';
  
  final url = Uri.parse("$baseUrl/food/restaurants").replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);
  final res = await http.get(url);
  return jsonDecode(res.body);
}

static Future<Map<String, dynamic>> getRestaurantDetails(String id) async {
  final url = Uri.parse("$baseUrl/food/restaurants/$id");
  final res = await http.get(url);
  return jsonDecode(res.body);
}

static Future<Map<String, dynamic>> getFoodOrderHistory() async {
  final url = Uri.parse("$baseUrl/food/orders");
  final res = await http.get(url, headers: await _authHeader());
  return jsonDecode(res.body);
}

static Future<Map<String, dynamic>> getNearbyResaleOrders({required double lat, required double lon, double radius = 5}) async {
  final url = Uri.parse("$baseUrl/food/resell/nearby").replace(queryParameters: {'lat': lat.toString(), 'lon': lon.toString(), 'radius': radius.toString()});
  final res = await http.get(url, headers: await _authHeader());
  return jsonDecode(res.body);
}

static Future<Map<String, dynamic>> claimResaleOrder(String orderId) async {
  final url = Uri.parse("$baseUrl/food/resell/$orderId/claim");
  final res = await http.post(url, headers: await _authHeader(), body: jsonEncode({}));
  return jsonDecode(res.body);
}
}
