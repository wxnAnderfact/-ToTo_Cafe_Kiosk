import 'package:cloud_firestore/cloud_firestore.dart';

// ═══════════════════════════════════════════════════════════════════════════
// MenuItem — Firestore: menu_items/{item_id}
// ═══════════════════════════════════════════════════════════════════════════

class MenuItem {
  MenuItem({
    this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.isAvailable,
    this.description,
    this.imageUrl,
  });

  /// Firestore document ID (null before first write).
  final String? id;

  final String name;

  /// Category key — e.g. "hot_coffee", "cold_brew", "non_coffee", "bakery".
  final String category;

  /// Price in THB.
  final double price;

  /// Whether this item is currently available for ordering.
  final bool isAvailable;

  /// Optional short description shown on the product card.
  final String? description;

  /// Optional image URL for the product photo.
  final String? imageUrl;

  // ── Firestore serialization ─────────────────────────────────────────

  factory MenuItem.fromJson(Map<String, dynamic> json, {String? id}) {
    return MenuItem(
      id: id,
      name: json['name'] as String? ?? '',
      category: json['category'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      isAvailable: json['is_available'] as bool? ?? true,
      description: json['description'] as String?,
      imageUrl: json['image_url'] as String?,
    );
  }

  /// Construct from a Firestore [DocumentSnapshot].
  factory MenuItem.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    return MenuItem.fromJson(doc.data() ?? {}, id: doc.id);
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'category': category,
      'price': price,
      'is_available': isAvailable,
      if (description != null) 'description': description,
      if (imageUrl != null) 'image_url': imageUrl,
    };
  }

  MenuItem copyWith({
    String? id,
    String? name,
    String? category,
    double? price,
    bool? isAvailable,
    String? description,
    String? imageUrl,
  }) {
    return MenuItem(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      price: price ?? this.price,
      isAvailable: isAvailable ?? this.isAvailable,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}
