import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/menu_item.dart';

/// Service for accessing the `menu_items` Firestore collection.
///
/// Uses real-time listeners (`snapshots()`) — not polling — per AGENTS.md:
///   "ทุก state ของออร์เดอร์ต้อง sync ผ่าน Firestore real-time listener ไม่ใช่ polling"
class MenuService {
  MenuService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('menu_items');

  // ── Real-time streams ───────────────────────────────────────────────────

  /// Stream of all available menu items, sorted by name.
  ///
  /// Uses a single-field query on `is_available` (auto-indexed) and sorts
  /// client-side to avoid requiring a composite Firestore index.
  Stream<List<MenuItem>> watchAll() {
    return _collection
        .snapshots()
        .map((snapshot) {
      final items = snapshot.docs
          .map((doc) => MenuItem.fromSnapshot(doc))
          .where((item) => item.isAvailable)
          .toList();
      items.sort((a, b) => a.name.compareTo(b.name));
      return items;
    });
  }

  /// Stream of menu items filtered by [category], sorted by name.
  ///
  /// Uses a single-field query on `category` (auto-indexed by Firestore)
  /// and filters `is_available` client-side to avoid composite index.
  Stream<List<MenuItem>> watchByCategory(String category) {
    return _collection
        .where('category', isEqualTo: category)
        .snapshots()
        .timeout(
          const Duration(seconds: 8),
          onTimeout: (sink) => sink.addError(Exception('Firestore stream timeout: could not fetch menu items')),
        )
        .map((snapshot) {
      final items = snapshot.docs
          .map((doc) => MenuItem.fromSnapshot(doc))
          .where((item) => item.isAvailable)
          .toList();
      items.sort((a, b) => a.name.compareTo(b.name));
      return items;
    });
  }

  /// Stream of distinct categories from the menu.
  Stream<List<String>> watchCategories() {
    return _collection.snapshots().map((snapshot) {
      final categories = snapshot.docs
          .map((doc) => doc.data()['category'] as String? ?? '')
          .where((c) => c.isNotEmpty)
          .toSet()
          .toList();
      categories.sort();
      return categories;
    });
  }

  // ── One-shot reads ──────────────────────────────────────────────────────

  /// Fetch a single menu item by document ID.
  Future<MenuItem?> getById(String id) async {
    final doc = await _collection.doc(id).get();
    if (!doc.exists) return null;
    return MenuItem.fromSnapshot(doc);
  }

  // ── Writes (for seeding / admin) ────────────────────────────────────────

  /// Add or update a menu item.
  Future<void> upsert(MenuItem item) async {
    if (item.id != null) {
      await _collection.doc(item.id).set(item.toJson());
    } else {
      await _collection.add(item.toJson());
    }
  }

  /// Delete all documents in the collection.
  Future<void> deleteAll() async {
    final snapshot = await _collection.get();
    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  /// Seed the collection with initial menu data (idempotent — skips if
  /// the collection already has documents).
  Future<bool> seedIfEmpty() async {
    try {
      final snapshot = await _collection.limit(1).get().timeout(const Duration(seconds: 8));
      if (snapshot.docs.isNotEmpty) return false;

      final batch = _firestore.batch();
      for (final item in _seedItems) {
        batch.set(_collection.doc(), item.toJson());
      }
      await batch.commit();
      return true;
    } catch (e) {
      debugPrint('seedIfEmpty failed: $e');
      return false;
    }
  }

  /// Force re-seed: delete all existing items and insert fresh seed data.
  Future<void> reseed() async {
    await deleteAll();
    final batch = _firestore.batch();
    for (final item in _seedItems) {
      batch.set(_collection.doc(), item.toJson());
    }
    await batch.commit();
  }
}

// ── Seed data ─────────────────────────────────────────────────────────────
// Used only by [MenuService.seedIfEmpty] — prices are stored in Firestore,
// never hardcoded in UI code (per AGENTS.md rules).

final List<MenuItem> _seedItems = [
  // ── Hot Coffee ────────────────────────────────────────────────────────
  MenuItem(
    name: 'Hot Latte',
    category: 'hot_coffee',
    price: 45,
    isAvailable: true,
    description: 'Rich espresso with steamed milk',
    imageUrl: 'assets/images/hot_coffee.png',
  ),
  MenuItem(
    name: 'Cappuccino',
    category: 'hot_coffee',
    price: 50,
    isAvailable: true,
    description: 'Espresso with thick milk foam',
    imageUrl: 'assets/images/hot_coffee.png',
  ),
  MenuItem(
    name: 'Americano',
    category: 'hot_coffee',
    price: 40,
    isAvailable: true,
    description: 'Espresso diluted with hot water',
    imageUrl: 'assets/images/hot_coffee.png',
  ),

  // ── Cold Brew ─────────────────────────────────────────────────────────
  MenuItem(
    name: 'Classic Cold Brew',
    category: 'cold_brew',
    price: 55,
    isAvailable: true,
    description: 'Slow-steeped for 12 hours',
    imageUrl: 'assets/images/cold_brew.png',
  ),
  MenuItem(
    name: 'Iced Mocha',
    category: 'cold_brew',
    price: 60,
    isAvailable: true,
    description: 'Cold brew with chocolate and milk',
    imageUrl: 'assets/images/cold_brew.png',
  ),

  // ── Non-Coffee ────────────────────────────────────────────────────────
  MenuItem(
    name: 'Matcha Latte',
    category: 'non_coffee',
    price: 75,
    isAvailable: true,
    description: 'Ceremonial grade matcha with milk',
    imageUrl: 'assets/images/matcha_latte.png',
  ),
  MenuItem(
    name: 'Thai Tea',
    category: 'non_coffee',
    price: 50,
    isAvailable: true,
    description: 'Classic Thai iced tea',
    imageUrl: 'assets/images/matcha_latte.png',
  ),

  // ── Bakery ────────────────────────────────────────────────────────────
  MenuItem(
    name: 'Almond Croissant',
    category: 'bakery',
    price: 65,
    isAvailable: true,
    description: 'Flaky pastry with almond filling',
    imageUrl: 'assets/images/almond_croissant.png',
  ),
  MenuItem(
    name: 'Banana Bread',
    category: 'bakery',
    price: 55,
    isAvailable: true,
    description: 'Homemade with walnuts',
    imageUrl: 'assets/images/almond_croissant.png',
  ),
];
