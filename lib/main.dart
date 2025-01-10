import 'package:flutter/material.dart';
import 'package:flutter_application_1/screens/grocery_list_screen.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();  // Ensure Flutter bindings are initialized
  await Firebase.initializeApp(
    options: FirebaseOptions(
      apiKey: "AIzaSyDqJiIxEWGCjxfHKnH42_Bu25HkZ3Cgmqc",
      authDomain: "grocerylist-1d885.firebaseapp.com",
      databaseURL: "https://grocerylist-1d885-default-rtdb.firebaseio.com",
      projectId: "grocerylist-1d885",
      storageBucket: "grocerylist-1d885.firebasestorage.app",
      messagingSenderId: "1017300834595",
      appId: "1:1017300834595:web:12c0e261f128db65721496",
      measurementId: "G-JMYJRD0FE0"
    ),
  );
  runApp(GroceryListApp());
}

class GroceryListApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Grocery List Appflutter buil',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: GroceryListScreen(),
    );
  }
}
