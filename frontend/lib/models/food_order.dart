// lib/models/food_order.dart

class FoodOrder {
  final String id;
  final String userId;
  final String? linkedRideId;
  final String deliveryMode; // 'detour_cab' or 'dedicated_delivery'
  final String restaurantId;
  final List<OrderItem> items;
  final OrderAmounts amounts;
  final DeliveryLocation locationDelivery;
  final String status;
  final String? assignedDriverId;
  final String? otpPickup;
  final String? otpDrop;
  final bool isCancelled;
  final String? cancellationReason;
  final bool originalCustomerPaysFull;
  
  // Resale fields
  final bool isResellable;
  final String resellStatus;
  final double resellPrice;
  final String? resellBuyerId;
  
  // Payment fields
  final String? razorpayOrderId;
  final String? razorpayPaymentId;
  final String? razorpaySignature;
  final bool isPaid;
  
  // Timestamps
  final DateTime createdAt;
  final DateTime? acceptedAt;
  final DateTime? preparingAt;
  final DateTime? readyForPickupAt;
  final DateTime? pickedUpAt;
  final DateTime? onTheWayAt;
  final DateTime? deliveredAt;
  final DateTime? cancelledAt;
  final DateTime? resellListedAt;
  final DateTime? resellClaimedAt;

  // Populated fields
  final RestaurantBasic? restaurant;
  final DriverBasic? driver;

  FoodOrder({
    required this.id,
    required this.userId,
    this.linkedRideId,
    required this.deliveryMode,
    required this.restaurantId,
    required this.items,
    required this.amounts,
    required this.locationDelivery,
    required this.status,
    this.assignedDriverId,
    this.otpPickup,
    this.otpDrop,
    required this.isCancelled,
    this.cancellationReason,
    required this.originalCustomerPaysFull,
    required this.isResellable,
    required this.resellStatus,
    required this.resellPrice,
    this.resellBuyerId,
    this.razorpayOrderId,
    this.razorpayPaymentId,
    this.razorpaySignature,
    required this.isPaid,
    required this.createdAt,
    this.acceptedAt,
    this.preparingAt,
    this.readyForPickupAt,
    this.pickedUpAt,
    this.onTheWayAt,
    this.deliveredAt,
    this.cancelledAt,
    this.resellListedAt,
    this.resellClaimedAt,
    this.restaurant,
    this.driver,
  });

  factory FoodOrder.fromJson(Map<String, dynamic> json) {
    return FoodOrder(
      id: json['_id'] ?? '',
      userId: json['userId'] ?? '',
      linkedRideId: json['linkedRideId'],
      deliveryMode: json['deliveryMode'] ?? 'dedicated_delivery',
      restaurantId: json['restaurantId'] is String 
          ? json['restaurantId'] 
          : (json['restaurantId']?['_id'] ?? ''),
      items: (json['items'] as List?)
              ?.map((i) => OrderItem.fromJson(i))
              .toList() ??
          [],
      amounts: OrderAmounts.fromJson(json['amounts'] ?? {}),
      locationDelivery: DeliveryLocation.fromJson(json['locationDelivery'] ?? {}),
      status: json['status'] ?? 'placed',
      assignedDriverId: json['assignedDriverId'],
      otpPickup: json['otpPickup'],
      otpDrop: json['otpDrop'],
      isCancelled: json['isCancelled'] ?? false,
      cancellationReason: json['cancellationReason'],
      originalCustomerPaysFull: json['originalCustomerPaysFull'] ?? false,
      isResellable: json['isResellable'] ?? false,
      resellStatus: json['resellStatus'] ?? 'none',
      resellPrice: (json['resellPrice'] ?? 0).toDouble(),
      resellBuyerId: json['resellBuyerId'],
      razorpayOrderId: json['razorpayOrderId'],
      razorpayPaymentId: json['razorpayPaymentId'],
      razorpaySignature: json['razorpaySignature'],
      isPaid: json['isPaid'] ?? false,
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      acceptedAt: json['acceptedAt'] != null ? DateTime.parse(json['acceptedAt']) : null,
      preparingAt: json['preparingAt'] != null ? DateTime.parse(json['preparingAt']) : null,
      readyForPickupAt: json['readyForPickupAt'] != null ? DateTime.parse(json['readyForPickupAt']) : null,
      pickedUpAt: json['pickedUpAt'] != null ? DateTime.parse(json['pickedUpAt']) : null,
      onTheWayAt: json['onTheWayAt'] != null ? DateTime.parse(json['onTheWayAt']) : null,
      deliveredAt: json['deliveredAt'] != null ? DateTime.parse(json['deliveredAt']) : null,
      cancelledAt: json['cancelledAt'] != null ? DateTime.parse(json['cancelledAt']) : null,
      resellListedAt: json['resellListedAt'] != null ? DateTime.parse(json['resellListedAt']) : null,
      resellClaimedAt: json['resellClaimedAt'] != null ? DateTime.parse(json['resellClaimedAt']) : null,
      restaurant: json['restaurantId'] is Map 
          ? RestaurantBasic.fromJson(json['restaurantId']) 
          : null,
      driver: json['assignedDriverId'] is Map 
          ? DriverBasic.fromJson(json['assignedDriverId']) 
          : null,
    );
  }

  String get statusDisplay {
    switch (status) {
      case 'placed': return 'Order Placed';
      case 'accepted': return 'Restaurant Accepted';
      case 'preparing': return 'Preparing Food';
      case 'ready_for_pickup': return 'Ready for Pickup';
      case 'picked_up': return 'Picked Up';
      case 'on_the_way': return 'On The Way';
      case 'delivered': return 'Delivered';
      case 'cancelled': return 'Cancelled';
      default: return status;
    }
  }
}

class OrderItem {
  final String menuItemId;
  final String name;
  final int quantity;
  final double unitPrice;
  final List<AddOnItem> addOns;
  final double itemTotal;

  OrderItem({
    required this.menuItemId,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.addOns,
    required this.itemTotal,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      menuItemId: json['menuItemId'] ?? '',
      name: json['name'] ?? '',
      quantity: json['quantity'] ?? 1,
      unitPrice: (json['unitPrice'] ?? 0).toDouble(),
      addOns: (json['addOns'] as List?)
              ?.map((a) => AddOnItem.fromJson(a))
              .toList() ??
          [],
      itemTotal: (json['itemTotal'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'menuItemId': menuItemId,
      'name': name,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'addOns': addOns.map((a) => a.toJson()).toList(),
      'itemTotal': itemTotal,
    };
  }
}

class AddOnItem {
  final String label;
  final double price;

  AddOnItem({required this.label, required this.price});

  factory AddOnItem.fromJson(Map<String, dynamic> json) {
    return AddOnItem(
      label: json['label'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'label': label, 'price': price};
  }
}

class OrderAmounts {
  final double itemsTotal;
  final double platformFee;
  final double deliveryFee;
  final double distanceFee;
  final double discounts;
  final double gstAmount;
  final double finalPayableAmount;

  OrderAmounts({
    required this.itemsTotal,
    required this.platformFee,
    required this.deliveryFee,
    required this.distanceFee,
    required this.discounts,
    required this.gstAmount,
    required this.finalPayableAmount,
  });

  factory OrderAmounts.fromJson(Map<String, dynamic> json) {
    return OrderAmounts(
      itemsTotal: (json['itemsTotal'] ?? 0).toDouble(),
      platformFee: (json['platformFee'] ?? 0).toDouble(),
      deliveryFee: (json['deliveryFee'] ?? 0).toDouble(),
      distanceFee: (json['distanceFee'] ?? 0).toDouble(),
      discounts: (json['discounts'] ?? 0).toDouble(),
      gstAmount: (json['gstAmount'] ?? 0).toDouble(),
      finalPayableAmount: (json['finalPayableAmount'] ?? 0).toDouble(),
    );
  }
}

class DeliveryLocation {
  final double lat;
  final double lon;
  final String address;

  DeliveryLocation({
    required this.lat,
    required this.lon,
    required this.address,
  });

  factory DeliveryLocation.fromJson(Map<String, dynamic> json) {
    return DeliveryLocation(
      lat: (json['lat'] ?? 0).toDouble(),
      lon: (json['lon'] ?? 0).toDouble(),
      address: json['address'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'lat': lat, 'lon': lon, 'address': address};
  }
}

class RestaurantBasic {
  final String id;
  final String name;
  final String? coverImageUrl;
  final double? lat;
  final double? lon;

  RestaurantBasic({
    required this.id,
    required this.name,
    this.coverImageUrl,
    this.lat,
    this.lon,
  });

  factory RestaurantBasic.fromJson(Map<String, dynamic> json) {
    return RestaurantBasic(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      coverImageUrl: json['coverImageUrl'],
      lat: json['location']?['lat']?.toDouble(),
      lon: json['location']?['lon']?.toDouble(),
    );
  }
}

class DriverBasic {
  final String id;
  final String name;
  final String? phone;

  DriverBasic({
    required this.id,
    required this.name,
    this.phone,
  });

  factory DriverBasic.fromJson(Map<String, dynamic> json) {
    return DriverBasic(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      phone: json['phone'],
    );
  }
}