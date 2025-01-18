import 'dart:io';
import 'package:flutter_application_1/models/grocery.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path/path.dart' as path;

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

  // Save image to local storage and return the relative path
  Future<String?> saveImageToLocalStorage(File imageFile, String name) async {
    try {
      // Get the app's document directory to save images
      final directory = Directory.current.path;
      // print("Current directory: ${Directory.current.path}");
      // Save the image with a unique name (using timestamp)
      final imageName = 'assets/images/$name.jpg';
      final newImagePath = path.join(directory, imageName);
      // ignore: unused_local_variable
      final newImageFile = await imageFile.copy(newImagePath);
      print("Image Path: $newImagePath");
      // Return the relative path to be stored in Firestore
      return '$imageName';
    } catch (e) {
      print("Error saving image: $e");
      return null;
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
