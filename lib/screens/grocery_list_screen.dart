import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/grocery_service.dart';
import 'package:flutter_application_1/models/grocery.dart';

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

  // Create a map to store controllers for each grocery item
  Map<String, TextEditingController> commentControllers = {};

  @override
  void initState() {
    super.initState();
    loadGroceryData();
    _tabController = TabController(length: 2, vsync: this); // Two tabs: Items to Buy, Grocery List
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
        if (grocery.stock == 0) {
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

  void updateComment(Grocery grocery, String comment) {
    setState(() {
      grocery.comment = comment;
    });
    groceryService.updateStockInFirestore(grocery); // Update the comment in Firestore
  }


  void updateStock(Grocery grocery, int delta) {
    setState(() {
      grocery.stock += delta;
      if (grocery.stock < 0) {
        grocery.stock = 0; // Prevent negative stock
      }

      //Update the restock_required field
      grocery.restockRequired = grocery.stock == 0;

      if (grocery.stock == 0 && !itemsToBuy.contains(grocery)) {
        itemsToBuy.add(grocery); // Add to "Items to Buy" if stock is zero
      } else if (grocery.stock > 0 && itemsToBuy.contains(grocery)) {
        itemsToBuy.remove(grocery); // Remove from "Items to Buy" if stock is replenished
      }

      // Update stock in Firestore after modification
      groceryService.updateStockInFirestore(grocery);
    });
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
          ],
        ),
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
                                    secondary: Image.asset(
                                      'assets/${grocery.image}',
                                      width: 70,
                                      height: 70,
                                      fit: BoxFit.cover,
                                    ),
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
                            }).toList(),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}