import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_1/models/grocery.dart';

class GroceryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Fetch all grocery data from Firestore
  Future<List<Grocery>> fetchGroceryJson() async {
    try {
      // Fetch the grocery data collection from Firestore
      QuerySnapshot querySnapshot = await _firestore.collection('Grocery_List').get();

      // Convert each document into a Grocery object
      return querySnapshot.docs.map((doc) => Grocery.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Error fetching data: $e');
    }
  }

  Future<void> updateStockInFirestore(Grocery grocery) async {
    try {
      // Fetch the grocery item document by its name (name is unique)
      QuerySnapshot snapshot = await _firestore.collection('Grocery_List')
          .where('name', isEqualTo: grocery.name)
          .get();

      if (snapshot.docs.isNotEmpty) {
        // Document exists, update the stock field for the first document found
        DocumentSnapshot doc = snapshot.docs.first;
        
        // Print the doc data for debugging
        print('Found document: ${doc.data()}');

        // Update the stock
        await doc.reference.update({
          'stock': grocery.stock, // Update the stock field
          'restock_required' : grocery.restockRequired,
          'comment': grocery.comment,  // Update comment field
        });

        print("Stock updated successfully for ${grocery.name}.");
      } else {
        print("No document found for ${grocery.name}. Please check the Firestore data.");
      }
    } catch (e) {
      print("Error updating stock in Firestore: $e");
      throw e; // Rethrow exception for the calling code to handle
    }
  }

}
