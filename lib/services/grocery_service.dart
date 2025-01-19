import 'package:flutter_application_1/models/grocery.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GroceryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Fetch all grocery data from Firestore
  Future<List<Grocery>> fetchGroceryJson() async {
    try {
      QuerySnapshot querySnapshot = await _firestore.collection('Grocery_List').get();
      return querySnapshot.docs.map((doc) => Grocery.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Error fetching data: $e');
    }
  }

  // Add a new grocery item to Firestore
  Future<void> addNewGrocery(Grocery grocery) async {
    try {
      await _firestore.collection('Grocery_List').add(grocery.toMap());
    } catch (e) {
      print("Error adding new grocery: $e");
    }
  }

  // Update stock information in Firestore
  Future<void> updateStockInFirestore(Grocery grocery) async {
    try {
      QuerySnapshot snapshot = await _firestore.collection('Grocery_List')
          .where('name', isEqualTo: grocery.name)
          .get();

      if (snapshot.docs.isNotEmpty) {
        DocumentSnapshot doc = snapshot.docs.first;
        await doc.reference.update({
          'stock': grocery.stock,
          'restock_required': grocery.restockRequired,
          'comment': grocery.comment,
        });
      } else {
        print("No document found for ${grocery.name}");
      }
    } catch (e) {
      print("Error updating stock in Firestore: $e");
    }
  }
}
