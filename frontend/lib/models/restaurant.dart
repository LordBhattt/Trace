// lib/models/restaurant.dart

class Restaurant {
  final String id;
  final String name;
  final String description;
  final String coverImageUrl;
  final String? logoImageUrl;
  final RestaurantLocation location;
  final List<String> cuisines;
  final double avgRating;
  final int totalRatings;
  final bool isVegOnly;
  final bool isActive;
  final double deliveryRadiusKm;
  final OpeningHours openingHours;
  final String? offers;
  final int preparationTimeMinutes;
  final double? distanceKm; // Calculated field

  Restaurant({
    required this.id,
    required this.name,
    required this.description,
    required this.coverImageUrl,
    this.logoImageUrl,
    required this.location,
    required this.cuisines,
    required this.avgRating,
    required this.totalRatings,
    required this.isVegOnly,
    required this.isActive,
    required this.deliveryRadiusKm,
    required this.openingHours,
    this.offers,
    required this.preparationTimeMinutes,
    this.distanceKm,
  });

  factory Restaurant.fromJson(Map<String, dynamic> json) {
    return Restaurant(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      coverImageUrl: json['coverImageUrl'] ?? '',
      logoImageUrl: json['logoImageUrl'],
      location: RestaurantLocation.fromJson(json['location'] ?? {}),
      cuisines: List<String>.from(json['cuisines'] ?? []),
      avgRating: (json['avgRating'] ?? 0).toDouble(),
      totalRatings: json['totalRatings'] ?? 0,
      isVegOnly: json['isVegOnly'] ?? false,
      isActive: json['isActive'] ?? true,
      deliveryRadiusKm: (json['deliveryRadiusKm'] ?? 10).toDouble(),
      openingHours: OpeningHours.fromJson(json['openingHours'] ?? {}),
      offers: json['offers'],
      preparationTimeMinutes: json['preparationTimeMinutes'] ?? 30,
      distanceKm: json['distanceKm'] != null 
          ? (json['distanceKm'] as num).toDouble() 
          : null,
    );
  }
}

class RestaurantLocation {
  final double lat;
  final double lon;
  final String address;

  RestaurantLocation({
    required this.lat,
    required this.lon,
    required this.address,
  });

  factory RestaurantLocation.fromJson(Map<String, dynamic> json) {
    return RestaurantLocation(
      lat: (json['lat'] ?? 0).toDouble(),
      lon: (json['lon'] ?? 0).toDouble(),
      address: json['address'] ?? '',
    );
  }
}

class OpeningHours {
  final String open;
  final String close;

  OpeningHours({required this.open, required this.close});

  factory OpeningHours.fromJson(Map<String, dynamic> json) {
    return OpeningHours(
      open: json['open'] ?? '09:00',
      close: json['close'] ?? '23:00',
    );
  }
}