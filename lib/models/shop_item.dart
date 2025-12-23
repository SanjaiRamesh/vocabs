import 'package:flutter/material.dart';

class ShopItem {
  String id;
  String name;
  String description;
  String iconName;
  String category; // 'pets', 'plants', 'aquarium'
  int price; // Cost in coins
  String rarity; // 'common', 'rare', 'epic', 'legendary'
  bool isOwned;
  DateTime? purchasedAt;
  bool isEquipped; // For active display
  String? animation; // Animation type for pets

  ShopItem({
    required this.id,
    required this.name,
    required this.description,
    required this.iconName,
    required this.category,
    required this.price,
    this.rarity = 'common',
    this.isOwned = false,
    this.purchasedAt,
    this.isEquipped = false,
    this.animation,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'icon_name': iconName,
      'category': category,
      'price': price,
      'rarity': rarity,
      'is_owned': isOwned ? 1 : 0,
      'purchased_at': purchasedAt?.toIso8601String(),
      'is_equipped': isEquipped ? 1 : 0,
      'animation': animation,
    };
  }

  factory ShopItem.fromMap(Map<String, dynamic> map) {
    return ShopItem(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      iconName: map['icon_name'] ?? 'pets',
      category: map['category'] ?? 'pets',
      price: map['price'] ?? 50,
      rarity: map['rarity'] ?? 'common',
      isOwned: (map['is_owned'] ?? 0) == 1,
      purchasedAt: map['purchased_at'] != null 
          ? DateTime.parse(map['purchased_at'])
          : null,
      isEquipped: (map['is_equipped'] ?? 0) == 1,
      animation: map['animation'],
    );
  }

  ShopItem copyWith({
    String? id,
    String? name,
    String? description,
    String? iconName,
    String? category,
    int? price,
    String? rarity,
    bool? isOwned,
    DateTime? purchasedAt,
    bool? isEquipped,
    String? animation,
  }) {
    return ShopItem(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      iconName: iconName ?? this.iconName,
      category: category ?? this.category,
      price: price ?? this.price,
      rarity: rarity ?? this.rarity,
      isOwned: isOwned ?? this.isOwned,
      purchasedAt: purchasedAt ?? this.purchasedAt,
      isEquipped: isEquipped ?? this.isEquipped,
      animation: animation ?? this.animation,
    );
  }

  Color get rarityColor {
    switch (rarity.toLowerCase()) {
      case 'common':
        return const Color(0xFF9E9E9E); // Grey
      case 'rare':
        return const Color(0xFF2196F3); // Blue
      case 'epic':
        return const Color(0xFF9C27B0); // Purple
      case 'legendary':
        return const Color(0xFFFF9800); // Orange/Gold
      default:
        return const Color(0xFF9E9E9E);
    }
  }

  @override
  String toString() {
    return 'ShopItem{id: $id, name: $name, price: $price, isOwned: $isOwned}';
  }
}
