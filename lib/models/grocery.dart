import 'package:cloud_firestore/cloud_firestore.dart';

class Grocery {
  final String name;
  int stock;
  final String image;
  final String category;
  bool restockRequired;
  String comment;

  // Constructor
  Grocery({
    required this.name,
    required this.stock,
    required this.image,
    required this.category,
    required this.restockRequired,
    required this.comment,
  });

  // Method to create a Grocery object from a JSON Map (for Firebase Realtime Database)
  factory Grocery.fromJson(Map<String, dynamic> json) {
    return Grocery(
      name: json['name'],
      stock: json['stock'],
      image: json['image'],
      category: json['category'],
      restockRequired: json['restock_required'],
      comment: json['comment'],
    );
  }

  // Method to create a Grocery object from Firestore DocumentSnapshot
  factory Grocery.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Grocery(
      name: data['name'] ?? '', // Default value in case 'name' is null
      stock: data['stock'] ?? 0, // Default to 0 if 'stock' is null
      image: data['image'] ?? '', // Default to empty string if 'image' is null
      category: data['category'] ?? '', // Default to empty string if 'category' is null
      restockRequired: data['restock_required'] ?? false, // Default to false if 'restock_required' is null
      comment: data['comment'] ?? '',
    );
  }

  // Method to convert Grocery object to a Map (for Firestore updates)
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'stock': stock,
      'image': image,
      'category': category,
      'restock_required': restockRequired,
      'comment': comment,
    };
  }
}
