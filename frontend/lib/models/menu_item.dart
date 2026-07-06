// lib/models/menu_item.dart

class AddOn {
  final String id;
  final String label;
  final double price;

  AddOn({
    required this.id,
    required this.label,
    required this.price,
  });

  factory AddOn.fromJson(Map<String, dynamic> json) {
    return AddOn(
      id: json['_id'] ?? json['id'] ?? '',
      label: json['label'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'price': price,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AddOn && other.id == id && other.label == label;
  }

  @override
  int get hashCode => id.hashCode ^ label.hashCode;
}

class MenuItem {
  final String id;
  final String restaurantId;
  final String name;
  final String description;
  final double price;
  final String? imageUrl;
  final bool isVeg;
  final bool isAvailable;
  final List<String> tags;
  final List<AddOn> addOns;

  MenuItem({
    required this.id,
    required this.restaurantId,
    required this.name,
    required this.description,
    required this.price,
    this.imageUrl,
    required this.isVeg,
    required this.isAvailable,
    required this.tags,
    required this.addOns,
  });

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    return MenuItem(
      id: json['_id'] ?? json['id'] ?? '',
      restaurantId: json['restaurantId'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      imageUrl: json['imageUrl'],
      isVeg: json['isVeg'] ?? false,
      isAvailable: json['isAvailable'] ?? true,
      tags: List<String>.from(json['tags'] ?? []),
      addOns: (json['addOns'] as List<dynamic>?)
              ?.map((addOn) => AddOn.fromJson(addOn))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'restaurantId': restaurantId,
      'name': name,
      'description': description,
      'price': price,
      'imageUrl': imageUrl,
      'isVeg': isVeg,
      'isAvailable': isAvailable,
      'tags': tags,
      'addOns': addOns.map((addOn) => addOn.toJson()).toList(),
    };
  }
}

class MenuCategory {
  final String name;
  final List<MenuItem> items;

  MenuCategory({
    required this.name,
    required this.items,
  });

  factory MenuCategory.fromJson(Map<String, dynamic> json) {
    return MenuCategory(
      name: json['name'] ?? '',
      items: (json['items'] as List<dynamic>?)
              ?.map((item) => MenuItem.fromJson(item))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'items': items.map((item) => item.toJson()).toList(),
    };
  }
}