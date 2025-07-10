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
  Map<String, TextEditingController> commentControllers = {};
  String? selectedCategory;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
 
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
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> loadGroceryData() async {
    try {
      List<Grocery> groceryList = await groceryService.fetchGroceryJson();

      // Initialize controllers for comments
      commentControllers = {};
      for (var grocery in groceryList) {
        commentControllers[grocery.name] = TextEditingController(text: grocery.comment);
      }

      // Group groceries by category
      final grouped = <String, List<Grocery>>{};
      final lowStockItems = <Grocery>[];

      for (var grocery in groceryList) {
        // Add low stock items to the "Items to Buy" list
        if (grocery.stock == 0 && grocery.restockRequired) {
          lowStockItems.add(grocery);
        }else if (grocery.stock >=0 && grocery.restockRequired) {
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
    String name = _nameController.text.trim();
    String comment = _commentController.text.trim();
    String imageUrl = _imageUrlController.text.trim();

    if (name.isNotEmpty && selectedCategory != null && imageUrl.isNotEmpty) {
      // Create new Grocery object
      final newGrocery = Grocery(
        name: name,
        stock: 0, // Example stock, could be an input field as well
        image: imageUrl, // Use the URL provided by the user
        category: selectedCategory!, // User input for category
        restockRequired: true, // Set restock required flag as needed
        comment: comment, // User input for comment
      );

      // Add the new grocery to Firestore
      await groceryService.addNewGrocery(newGrocery);

      // Clear the form
      _nameController.clear();
      _commentController.clear();
      _imageUrlController.clear(); // Clear the URL field
      setState(() {
        selectedCategory = null; // Reset dropdown
      });
      // Refresh the grocery list
      loadGroceryData();
    } else {
      // You can show a Snackbar here if needed
      print('Please fill all fields.');
    }
  }

  // Function to update the comment for a grocery item
  void updateComment(Grocery grocery, String newComment) {
    setState(() {
      grocery.comment = newComment; // Directly update the model in state
    });
    // Ensure Firestore is updated after comment change
    groceryService.updateStockInFirestore(grocery);
  }

  Widget buildGroceryTile(Grocery grocery) {
    return Column(
      children: [
        CheckboxListTile(
          title: Row(
            children: [
              Expanded(child: Text(grocery.name)),
            ],
          ),
          value: grocery.restockRequired,
          onChanged: (isChecked) {
            toggleItemToBuy(grocery, isChecked!);
          },
          secondary: grocery.image.isNotEmpty
              ? Image.network(
                  grocery.image,
                  width: 60,
                  height: 150,
                  fit: BoxFit.cover,
                )
              : null,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: TextField(
            controller: commentControllers[grocery.name],
            decoration: InputDecoration(labelText: 'Enter a comment'),
            onChanged: (comment) {
              updateComment(grocery, comment);
            },
          ),
        ),
      ],
    );
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
        // actions: [
        //   IconButton(
        //     icon: Icon(Icons.close),
        //     onPressed: () {
        //       // Close the app when pressed
        //       SystemChannels.platform.invokeMethod('SystemNavigator.pop');
        //     },
        //   ),
        // ],
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
                                return CheckboxListTile(
                                  contentPadding: EdgeInsets.symmetric(vertical: 1.0, horizontal: 6.0),
                                  title: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.name,
                                        style: TextStyle(fontSize: 16),
                                      ),
                                      // if (item.restockRequired && item.stock > 0)
                                      //   Padding(
                                      //     padding: const EdgeInsets.only(top: 1.0),
                                      //     child: Text(
                                      //       'Stock: ${item.stock}',
                                      //       style: TextStyle(fontSize: 14),
                                      //     ),
                                      //   ),
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
                                  value: item.restockRequired,
                                  onChanged: (checked) {
                                    toggleItemToBuy(item, checked ?? false);
                                  },
                                  secondary: item.image.isNotEmpty
                                      ? Image.network(
                                          item.image,
                                          width: 60,
                                          height: 60,
                                          fit: BoxFit.cover,
                                        )
                                      : null,
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
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          labelText: 'Search by name',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    Expanded(
                      child: _searchQuery.isEmpty
                      ? ListView(
                          children: categorizedGroceries.keys.map((category) {
                            final items = categorizedGroceries[category]!;
                            return ExpansionTile(
                              title: Text(category, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              children: items.map((grocery) {
                                return buildGroceryTile(grocery);
                              }).toList(),
                            );
                          }).toList(),
                        )
                      : ListView(
                          children: groceries
                              .where((grocery) => grocery.name.toLowerCase().contains(_searchQuery))
                              .map((grocery) => buildGroceryTile(grocery))
                              .toList(),
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
                        DropdownButtonFormField<String>(
                          decoration: InputDecoration(labelText: 'Category'),
                          value: selectedCategory,
                          items: categorizedGroceries.keys.map((category) {
                            return DropdownMenuItem<String>(
                              value: category,
                              child: Text(category),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedCategory = value!;
                            });
                          },
                          validator: (value) => value == null ? 'Please select a category' : null,
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
                          onPressed: (_nameController != null && selectedCategory != null && _imageUrlController != null)
                            ? addNewItem
                            : null,
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
