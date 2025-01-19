import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/grocery_service.dart';
import 'package:flutter_application_1/models/grocery.dart';
import 'package:flutter/services.dart';

class GroceryListScreen extends StatefulWidget {
  @override
  _GroceryListScreenState createState() => _GroceryListScreenState();
}

class _GroceryListScreenState extends State<GroceryListScreen> with SingleTickerProviderStateMixin {
  final GroceryService groceryService = GroceryService();
  List<Grocery> groceries = [];
  Map<String, List<Grocery>> categorizedGroceries = {};
  List<Grocery> itemsToBuy = [];
  late TabController _tabController;

  // Controllers for the form inputs
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _imageUrlController = TextEditingController(); // New controller for URL

  @override
  void initState() {
    super.initState();
    loadGroceryData();
    _tabController = TabController(length: 3, vsync: this); // Three tabs now: Items to Buy, Grocery List, Add Item
  }

  Future<void> loadGroceryData() async {
    try {
      List<Grocery> groceryList = await groceryService.fetchGroceryJson();

      // Group groceries by category
      final grouped = <String, List<Grocery>>{};
      final lowStockItems = <Grocery>[];

      for (var grocery in groceryList) {
        // Add low stock items to the "Items to Buy" list
        if (grocery.stock == 0 || grocery.restockRequired) {
          lowStockItems.add(grocery);
        }

        if (!grouped.containsKey(grocery.category)) {
          grouped[grocery.category] = [];
        }
        grouped[grocery.category]!.add(grocery);
      }

      setState(() {
        groceries = groceryList;
        categorizedGroceries = grouped;
        itemsToBuy = lowStockItems;
      });
    } catch (e) {
      print('Error loading groceries: $e');
    }
  }

  void toggleItemToBuy(Grocery grocery, bool isChecked) {
    setState(() {
      if (isChecked) {
        if (!itemsToBuy.contains(grocery)) {
          itemsToBuy.add(grocery);
        }
        grocery.restockRequired = true;
      } else {
        itemsToBuy.remove(grocery);
        grocery.restockRequired = false;
      }

      // Ensure we update the Firestore document
      groceryService.updateStockInFirestore(grocery);
    });
  }

  void updateStock(Grocery grocery, int delta) {
    setState(() {
      grocery.stock += delta;
      
      if (grocery.stock < 0) {
        grocery.stock = 0; // Prevent negative stock
      }

      // Update the restock_required field
      if (grocery.stock == 0 && !itemsToBuy.contains(grocery) && !grocery.restockRequired) {
        itemsToBuy.add(grocery); // Add to "Items to Buy" if stock is zero
        grocery.restockRequired = true;
      } else if (grocery.stock > 0 && itemsToBuy.contains(grocery) && grocery.restockRequired) {
        itemsToBuy.remove(grocery); // Remove from "Items to Buy" if stock is replenished
        grocery.restockRequired = false;
      }

      // Update stock in Firestore after modification
      groceryService.updateStockInFirestore(grocery);
    });
  }

  // Add new grocery item
  Future<void> addNewItem() async {
    String name = _nameController.text;
    String category = _categoryController.text;
    String comment = _commentController.text;
    String imageUrl = _imageUrlController.text; // Get URL from the user

    if (imageUrl.isNotEmpty && name.isNotEmpty && category.isNotEmpty) {
      // Create new Grocery object
      final newGrocery = Grocery(
        name: name,
        stock: 0, // Example stock, could be an input field as well
        image: imageUrl, // Use the URL provided by the user
        category: category, // User input for category
        restockRequired: true, // Set restock required flag as needed
        comment: comment, // User input for comment
      );

      // Add the new grocery to Firestore
      await groceryService.addNewGrocery(newGrocery);

      // Clear the form
      _nameController.clear();
      _categoryController.clear();
      _commentController.clear();
      _imageUrlController.clear(); // Clear the URL field

      // Refresh the grocery list
      loadGroceryData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Grocery List'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Items to Buy'),
            Tab(text: 'Grocery List'),
            Tab(text: 'Add Item'),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.close),
            onPressed: () {
              // Close the app when pressed
              SystemChannels.platform.invokeMethod('SystemNavigator.pop');
            },
          ),
        ],
      ),
      body: groceries.isEmpty
          ? Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                // First Tab - "Items to Buy"
                Column(
                  children: [
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              'Items to Buy',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                          ),
                          Expanded(
                            child: ListView.builder(
                              itemCount: itemsToBuy.length,
                              itemBuilder: (context, index) {
                                final item = itemsToBuy[index];
                                return ListTile(
                                  contentPadding: EdgeInsets.symmetric(vertical: 1.0, horizontal: 6.0),
                                  title: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.name,
                                        style: TextStyle(fontSize: 16),
                                      ),
                                      if (item.restockRequired && item.stock > 0)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 1.0),
                                          child: Text(
                                            'Stock: ${item.stock}',
                                            style: TextStyle(fontSize: 14),
                                          ),
                                        ),
                                      if (item.comment.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 1.0),
                                          child: Text(
                                            'Comment: ${item.comment}',
                                            style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // Second Tab - "Grocery List to Manage Stock"
                Column(
                  children: [
                    Expanded(
                      flex: 5,
                      child: ListView(
                        children: categorizedGroceries.keys.map((category) {
                          final items = categorizedGroceries[category]!;
                          return ExpansionTile(
                            title: Text(category, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            children: items.map((grocery) {
                              return Column(
                                children: [
                                  CheckboxListTile(
                                    title: Row(
                                      children: [
                                        Expanded(child: Text(grocery.name)),
                                        IconButton(
                                          icon: Icon(Icons.remove),
                                          onPressed: () => updateStock(grocery, -1),
                                        ),
                                        Text('${grocery.stock}', style: TextStyle(fontSize: 16)),
                                        IconButton(
                                          icon: Icon(Icons.add),
                                          onPressed: () => updateStock(grocery, 1),
                                        ),
                                      ],
                                    ),
                                    subtitle: Text('Stock: ${grocery.stock}'),
                                    value: itemsToBuy.contains(grocery),
                                    onChanged: (isChecked) {
                                      toggleItemToBuy(grocery, isChecked!);
                                    },
                                    secondary: Image.network(
                                      grocery.image, // Load the image from URL
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
                // Third Tab - Add New Grocery Item
                SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Text('Add New Item', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                        SizedBox(height: 20),
                        TextField(
                          controller: _nameController,
                          decoration: InputDecoration(labelText: 'Name'),
                        ),
                        TextField(
                          controller: _categoryController,
                          decoration: InputDecoration(labelText: 'Category'),
                        ),
                        TextField(
                          controller: _commentController,
                          decoration: InputDecoration(labelText: 'Comment'),
                        ),
                        TextField(
                          controller: _imageUrlController, // Input field for image URL
                          decoration: InputDecoration(labelText: 'Image URL'),
                        ),
                        SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: addNewItem,
                          child: Text('Add Item'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
