import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/grocery_service.dart';
import 'package:flutter_application_1/models/grocery.dart';

class GroceryListScreen extends StatefulWidget {
  @override
  _GroceryListScreenState createState() => _GroceryListScreenState();
}

class _GroceryListScreenState extends State<GroceryListScreen> {
  final GroceryService groceryService = GroceryService();
  List<Grocery> groceries = [];
  Map<String, List<Grocery>> categorizedGroceries = {};
  List<Grocery> itemsToBuy = [];

  @override
  void initState() {
    super.initState();
    loadGroceryData();
  }

  Future<void> loadGroceryData() async {
    try {
      List<Grocery> groceryList = await groceryService.fetchGroceryJson();

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
      } else {
        itemsToBuy.remove(grocery);
      }
    });
  }

  void updateStock(Grocery grocery, int delta) {
    setState(() {
      grocery.stock += delta;
      if (grocery.stock < 0) {
        grocery.stock = 0; // Prevent negative stock
      }

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
      ),
      body: groceries.isEmpty
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Items to Buy Section
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
                              contentPadding: EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0), // Reduce spacing
                              title: Text(
                                item.name,
                                style: TextStyle(fontSize: 16),  // Decrease font size
                              ),
                              subtitle: item.stock > 0
                                ? Text(
                                    'Stock: ${item.stock}',
                                    style: TextStyle(fontSize: 14),  // Decrease font size for subtitle
                                  )
                                : null,  // If stock is 0, show no subtitle
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(),
                // Grocery List Section
                Expanded(
                  flex: 3,
                  child: ListView(
                    children: categorizedGroceries.keys.map((category) {
                      final items = categorizedGroceries[category]!;
                      return ExpansionTile(
                        title: Text(category, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        children: items.map((grocery) {
                          return CheckboxListTile(
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
                              'assets/${grocery.image}', // Use local assets path
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                            ),
                          );
                        }).toList(),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
    );
  }
}
