import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:faker/faker.dart' hide Color; // DÜZELTME 1: Renk çakışmasını engelle
import 'dart:math';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;
  bool _isLoading = false;
  bool _showRealUsersOnly = false; 

  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      const MarketAnalysisPage(),
      const SizedBox.shrink(), // UserTrackingPage (Parametreli)
      const GlobalInsightsPage(), 
      const AlertsPage(),
    ];
  }

  // --- TEMİZLİK ---
  Future<void> _deleteFakeData() async {
    setState(() => _isLoading = true);
    final firestore = FirebaseFirestore.instance;
    int deletedCount = 0;
    try {
      final snapshot = await firestore.collection('users').where('isFake', isEqualTo: true).get();
      // Batch delete
      WriteBatch batch = firestore.batch();
      int batchCount = 0;

      for (var doc in snapshot.docs) {
        await _deleteSubCollection(doc.reference, 'fridge_status');
        await _deleteSubCollection(doc.reference, 'platforms');
        await _deleteSubCollection(doc.reference, 'recipes');
        await _deleteSubCollection(doc.reference, 'shopping_list');
        await _deleteSubCollection(doc.reference, 'consumption_logs');
        await _deleteSubCollection(doc.reference, 'fridge_inventory');
        
        batch.delete(doc.reference);
        batchCount++;

        if (batchCount >= 500) {
          await batch.commit();
          batch = firestore.batch();
          batchCount = 0;
        }
        deletedCount++;
      }
      if (batchCount > 0) await batch.commit();

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('🗑️ Deleted $deletedCount fake users!'), backgroundColor: Colors.redAccent));
    } catch (e) {
      print(e);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteSubCollection(DocumentReference docRef, String subCollection) async {
    final snapshot = await docRef.collection(subCollection).get();
    for (var doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }

  // --- GELİŞMİŞ FAKER MOTORU (100+ Kullanıcı) ---
  Future<void> _generateFakeData({bool simulatePowerOutage = false}) async {
    setState(() => _isLoading = true);
    final firestore = FirebaseFirestore.instance;
    final faker = Faker();
    final random = Random();

    // 1. KÜLTÜREL PROFİLLER VE ÜRÜNLER
    final countryProfiles = {
      'DE': {
        'cats': ['Beverages', 'Meat & Fish', 'Snacks'],
        'items': ['German Beer', 'Bratwurst', 'Pretzel', 'Schnitzel', 'Potato Salad', 'Rye Bread', 'Sauerkraut', 'Mustard', 'Currywurst']
      },
      'TR': {
        'cats': ['Vegetables', 'Dairy', 'Staples'],
        'items': ['Turkish Tea', 'Feta Cheese', 'Olives', 'Simit', 'Yoghurt', 'Tomato', 'Cucumber', 'Baklava', 'Sucuk', 'Pastirma']
      },
      'IT': {
        'cats': ['Staples', 'Vegetables', 'Dairy'],
        'items': ['Spaghetti', 'Mozzarella', 'Tomato Sauce', 'Olive Oil', 'Pizza Dough', 'Chianti Wine', 'Parmesan', 'Basil', 'Lasagna Sheets']
      },
      'US': {
        'cats': ['Snacks', 'Meat & Fish', 'Beverages'],
        'items': ['Burger Patties', 'Cola', 'Potato Chips', 'Bagels', 'Cheddar Cheese', 'Donuts', 'BBQ Sauce', 'Peanut Butter', 'Hot Dogs']
      },
      'FR': {
        'cats': ['Dairy', 'Beverages', 'Staples'],
        'items': ['Baguette', 'Camembert', 'Red Wine', 'Croissant', 'Butter', 'Champagne', 'Dijon Mustard', 'Escargot', 'Macarons']
      },
      'JP': {
        'cats': ['Meat & Fish', 'Staples', 'Vegetables'],
        'items': ['Sushi Rice', 'Miso Paste', 'Tofu', 'Salmon', 'Green Tea', 'Soy Sauce', 'Seaweed', 'Ramen Noodles', 'Wasabi']
      },
      'MX': {
        'cats': ['Vegetables', 'Staples', 'Meat & Fish'],
        'items': ['Tortillas', 'Avocado', 'Salsa', 'Black Beans', 'Chorizo', 'Corn', 'Jalapeno', 'Tequila', 'Lime']
      },
      'BR': {
        'cats': ['Meat & Fish', 'Fruits', 'Staples'],
        'items': ['Picanha Beef', 'Black Beans', 'Rice', 'Acai', 'Cassava Flour', 'Coffee', 'Papaya', 'Guarana', 'Condensed Milk']
      },
    };
    
    final allCountries = countryProfiles.keys.toList();
    final allCategories = ['Vegetables', 'Fruits', 'Beverages', 'Meat & Fish', 'Dairy', 'Snacks', 'Staples'];

    final genericItemNames = {
      'Vegetables': ['Tomato', 'Cucumber', 'Lettuce', 'Carrot', 'Spinach', 'Onion', 'Garlic'],
      'Fruits': ['Apple', 'Banana', 'Orange', 'Strawberry', 'Grape', 'Mango'],
      'Beverages': ['Milk', 'Cola', 'Juice', 'Water', 'Beer', 'Soda', 'Iced Tea'],
      'Meat & Fish': ['Chicken Breast', 'Steak', 'Salmon', 'Sausage', 'Beef', 'Tuna'],
      'Dairy': ['Cheese', 'Yogurt', 'Butter', 'Cream', 'Milk'],
      'Snacks': ['Chips', 'Chocolate', 'Cookies', 'Popcorn', 'Nuts'],
      'Staples': ['Rice', 'Pasta', 'Bread', 'Eggs', 'Flour', 'Sugar']
    };

    int totalUsersToCreate = 100;
    int batchSize = 25;
    int batches = totalUsersToCreate ~/ batchSize;

    try {
      for (int b = 0; b < batches; b++) {
        WriteBatch batch = firestore.batch();

        for (int i = 0; i < batchSize; i++) {
          String country = allCountries[random.nextInt(allCountries.length)];
          var profile = countryProfiles[country]!;
          
          String firstName = faker.person.firstName();
          String lastName = faker.person.lastName();
          String email = '${firstName.toLowerCase()}.${lastName.toLowerCase()}@${faker.internet.domainName()}';
          
          DocumentReference userRef = firestore.collection('users').doc();
          batch.set(userRef, {
            'email': email,
            'profileType': random.nextBool() ? 'Family' : (random.nextBool() ? 'Single' : 'Shared'),
            'countryCode': country,
            'languageCode': country.toLowerCase(),
            'createdAt': FieldValue.serverTimestamp(),
            'isFake': true,
          });

          bool isPowerOut = simulatePowerOutage && (random.nextDouble() < 0.3);
          double temp = isPowerOut ? (8 + random.nextDouble()*6) : (2 + random.nextDouble()*5);
          DocumentReference statusRef = userRef.collection('fridge_status').doc('current_status');
          batch.set(statusRef, {
            'temperature': temp,
            'humidity': 30 + random.nextDouble() * 50,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          for (int p = 1; p <= 3; p++) {
            DocumentReference platformRef = userRef.collection('platforms').doc('platform$p');
            batch.set(platformRef, {
              'name': 'Shelf $p',
              'weight': (0.5 + random.nextDouble() * 4.5),
              'category': allCategories[random.nextInt(allCategories.length)],
            });
          }

          int shopCount = 4 + random.nextInt(6); 
          for (int s = 0; s < shopCount; s++) {
            DocumentReference shopRef = userRef.collection('shopping_list').doc();
            String category;
            String itemName;
            
            if (random.nextDouble() < 0.75) {
               List<String> favCats = profile['cats'] as List<String>;
               category = favCats[random.nextInt(favCats.length)];
               
               if (random.nextDouble() < 0.60) {
                  List<String> localItems = profile['items'] as List<String>;
                  itemName = localItems[random.nextInt(localItems.length)];
               } else {
                  List<String> list = genericItemNames[category] ?? [];
                  itemName = list.isNotEmpty ? list[random.nextInt(list.length)] : faker.food.dish();
               }
            } else {
               category = allCategories[random.nextInt(allCategories.length)];
               List<String> list = genericItemNames[category] ?? [];
               itemName = list.isNotEmpty ? list[random.nextInt(list.length)] : faker.food.dish();
            }

            batch.set(shopRef, {
              'name': itemName,
              'category': category,
              'isBought': random.nextBool(),
            });
          }
          
          for (int r = 0; r < 3; r++) {
            DocumentReference recipeRef = userRef.collection('recipes').doc();
            batch.set(recipeRef, {
              'name': faker.food.dish(), 
              'calories': 200 + random.nextInt(800),
              'cookingTime': '${15 + random.nextInt(90)} min',
              'isFavorite': random.nextBool(),
            });
          }
        }
        
        await batch.commit();
        await Future.delayed(const Duration(milliseconds: 100)); 
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Created 100 Realistic Users with Cultural Data!'), backgroundColor: Colors.teal));
        setState(() {});
      }
    } catch (e) {
      print(e);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget bodyContent;
    switch (_selectedIndex) {
      case 0: bodyContent = const MarketAnalysisPage(); break;
      case 1: bodyContent = UserTrackingPage(showRealUsersOnly: _showRealUsersOnly); break;
      case 2: bodyContent = const GlobalInsightsPage(); break;
      case 3: bodyContent = const AlertsPage(); break;
      default: bodyContent = const MarketAnalysisPage();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Fridge Admin'),
        centerTitle: true,
        backgroundColor: Colors.teal.shade900,
        actions: [
          if (_selectedIndex == 1)
            IconButton(
              icon: Icon(_showRealUsersOnly ? Icons.filter_alt : Icons.filter_alt_off),
              tooltip: "Real User Filter",
              onPressed: () => setState(() => _showRealUsersOnly = !_showRealUsersOnly),
            ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'normal') _generateFakeData(simulatePowerOutage: false);
              if (value == 'power_out') _generateFakeData(simulatePowerOutage: true);
              if (value == 'delete') _deleteFakeData();
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(value: 'normal', child: Row(children: [Icon(Icons.people, color: Colors.teal), SizedBox(width: 8), Text("Add 100 Users (Mass)")])),
              const PopupMenuItem(value: 'power_out', child: Row(children: [Icon(Icons.flash_off, color: Colors.red), SizedBox(width: 8), Text("Simulate Power Outage")])),
              const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_forever, color: Colors.redAccent), SizedBox(width: 8), Text("Delete Fake Data")])),
            ],
            icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.settings, color: Colors.white),
          ),
        ],
      ),
      body: bodyContent,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (int index) => setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.pie_chart), label: 'Market'),
          NavigationDestination(icon: Icon(Icons.people), label: 'Users'),
          NavigationDestination(icon: Icon(Icons.public), label: 'Global'), 
          NavigationDestination(icon: Icon(Icons.warning), label: 'Alerts'),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 3. GLOBAL INSIGHTS
// -----------------------------------------------------------------------------
class GlobalInsightsPage extends StatefulWidget {
  const GlobalInsightsPage({super.key});

  @override
  State<GlobalInsightsPage> createState() => _GlobalInsightsPageState();
}

class _GlobalInsightsPageState extends State<GlobalInsightsPage> {
  bool _loading = true;
  Map<String, Map<String, int>> _countryData = {};
  String _selectedCategoryForComparison = 'Beverages';
  final List<String> _categories = ['Vegetables', 'Fruits', 'Beverages', 'Meat & Fish', 'Dairy', 'Snacks', 'Staples'];

  @override
  void initState() {
    super.initState();
    _fetchGlobalData();
  }

  Future<void> _fetchGlobalData() async {
    final firestore = FirebaseFirestore.instance;
    Map<String, Map<String, int>> tempCountryData = {};

    try {
      final usersSnapshot = await firestore.collection('users').get();
      
      for (var userDoc in usersSnapshot.docs) {
        final userData = userDoc.data();
        if (userData['isFake'] != true) continue;

        String country = userData['countryCode'] ?? 'Unknown';
        if (country.isEmpty) country = 'Unknown';

        if (!tempCountryData.containsKey(country)) {
          tempCountryData[country] = {};
        }

        final listSnapshot = await userDoc.reference.collection('shopping_list').get();
        for (var itemDoc in listSnapshot.docs) {
          String cat = itemDoc.data()['category'] ?? 'Other';
          tempCountryData[country]![cat] = (tempCountryData[country]![cat] ?? 0) + 1;
        }
      }
    } catch (e) {
      print(e);
    }

    if (mounted) {
      setState(() {
        _countryData = tempCountryData;
        _loading = false;
      });
    }
  }

  List<BarChartGroupData> _getBarGroups() {
    List<BarChartGroupData> groups = [];
    int x = 0;
    
    var sortedCountries = _countryData.keys.toList()..sort();

    for (var country in sortedCountries) {
      var categories = _countryData[country]!;
      double value = (categories[_selectedCategoryForComparison] ?? 0).toDouble();
      
      groups.add(BarChartGroupData(
        x: x,
        barRods: [
          BarChartRodData(toY: value, color: _getCountryColor(country), width: 14, borderRadius: BorderRadius.circular(4))
        ],
      ));
      x++;
    }
    return groups;
  }
  
  Color _getCountryColor(String country) {
    if (country == 'DE') return Colors.orange; 
    if (country == 'TR') return Colors.red;    
    if (country == 'IT') return Colors.green;  
    if (country == 'US') return Colors.blue;   
    if (country == 'FR') return Colors.purple;
    if (country == 'JP') return Colors.pinkAccent;
    if (country == 'BR') return Colors.yellow;
    if (country == 'MX') return Colors.tealAccent;
    return Colors.grey;
  }

  String _getTopCategoryForCountry(String country) {
    if (_countryData[country] == null || _countryData[country]!.isEmpty) return "None";
    var entries = _countryData[country]!.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value));
    return "${entries.first.key} (${entries.first.value})";
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_countryData.isEmpty) return const Center(child: Text("No data. Please Populate DB."));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("🌍 Cultural Consumption Trends", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 8),
          const Text("Compare specific categories across countries based on shopping lists.", style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 20),
          
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _categories.map((cat) {
                bool isSelected = _selectedCategoryForComparison == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(cat),
                    selected: isSelected,
                    onSelected: (bool selected) => setState(() => _selectedCategoryForComparison = cat),
                    selectedColor: Colors.tealAccent.shade700,
                    labelStyle: TextStyle(color: isSelected ? Colors.black : Colors.white),
                  ),
                );
              }).toList(),
            ),
          ),
          
          const SizedBox(height: 20),

          Container(
            height: 300,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(16)),
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                barTouchData: BarTouchData(
                  enabled: true,
                  // DÜZELTME 2: tooltipBgColor veya getTooltipColor hatalıydı, kaldırdık.
                ),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        var sortedCountries = _countryData.keys.toList()..sort();
                        if (value.toInt() >= sortedCountries.length) return const Text('');
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(sortedCountries[value.toInt()], style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                gridData: const FlGridData(show: true, drawVerticalLine: false),
                barGroups: _getBarGroups(),
              ),
            ),
          ),

          const SizedBox(height: 30),
          
          const Text("💡 AI Insights", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.amberAccent)),
          const SizedBox(height: 10),
          // DÜZELTME 3: Spread syntax hatası düzeltildi
          ...(_countryData.keys.toList()..sort()).map((country) {
            return _buildInsightCard(country);
          }), 
        ],
      ),
    );
  }

  Widget _buildInsightCard(String country) {
      String topCat = _getTopCategoryForCountry(country);
      String emoji = "🏳️";
      if(country == 'DE') emoji = "🍺";
      if(country == 'TR') emoji = "🍵";
      if(country == 'IT') emoji = "🍕";
      if(country == 'US') emoji = "🍔";
      if(country == 'FR') emoji = "🍷";
      if(country == 'JP') emoji = "🍣";
      if(country == 'BR') emoji = "🥩";
      if(country == 'MX') emoji = "🌮";

      return Card(
        color: Colors.teal.shade900.withOpacity(0.4),
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: Text(country, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          title: Text("Top Category: $topCat"),
          trailing: Text(emoji, style: const TextStyle(fontSize: 24)),
        ),
      );
  }
}

// -----------------------------------------------------------------------------
// DİĞER SAYFALAR
// -----------------------------------------------------------------------------

class MarketAnalysisPage extends StatefulWidget {
  const MarketAnalysisPage({super.key});
  @override
  State<MarketAnalysisPage> createState() => _MarketAnalysisPageState();
}

class _MarketAnalysisPageState extends State<MarketAnalysisPage> {
  Map<String, double> _categoryData = {};
  bool _loading = true;
  int _totalItems = 0;

  @override
  void initState() {
    super.initState();
    _fetchAnalysisData();
  }

  Future<void> _fetchAnalysisData() async {
    final firestore = FirebaseFirestore.instance;
    Map<String, double> counts = {};
    int total = 0;
    try {
      final usersSnapshot = await firestore.collection('users').get();
      for (var userDoc in usersSnapshot.docs) {
        final listSnapshot = await userDoc.reference.collection('shopping_list').get();
        for (var doc in listSnapshot.docs) {
          final category = doc.data()['category'] as String? ?? 'Other';
          counts[category] = (counts[category] ?? 0) + 1;
          total++;
        }
      }
    } catch (e) {}
    if (mounted) setState(() { _categoryData = counts; _totalItems = total; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
           Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
             const Text("Overall Market Distribution", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
             IconButton(onPressed: _fetchAnalysisData, icon: const Icon(Icons.refresh))
           ]),
           const SizedBox(height: 20),
           SizedBox(height: 300, child: PieChart(PieChartData(
             sections: _categoryData.entries.map((e) => PieChartSectionData(
               value: e.value, 
               color: _getColor(e.key), 
               title: '${((e.value/_totalItems)*100).toStringAsFixed(0)}%', 
               radius: 60,
               titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)
             )).toList(), centerSpaceRadius: 40
           ))),
           const SizedBox(height: 20),
           Wrap(spacing: 8, runSpacing: 8, children: _categoryData.keys.map((k) => Chip(label: Text(k), avatar: CircleAvatar(backgroundColor: _getColor(k)))).toList())
        ],
      ),
    );
  }
  
  Color _getColor(String c) {
    if(c=='Beverages') return Colors.blue;
    if(c=='Vegetables') return Colors.green;
    if(c=='Meat & Fish') return Colors.brown;
    if(c=='Dairy') return Colors.yellow.shade700;
    if(c=='Snacks') return Colors.purple;
    return Colors.grey;
  }
}

class UserTrackingPage extends StatelessWidget {
  final bool showRealUsersOnly;
  const UserTrackingPage({super.key, this.showRealUsersOnly = false});

  String _getFlagEmoji(String countryCode) {
    if (countryCode.isEmpty) return '🌍';
    try {
      int flagOffset = 0x1F1E6; int asciiOffset = 0x41;
      return String.fromCharCode(flagOffset + countryCode.codeUnitAt(0) - asciiOffset) + String.fromCharCode(flagOffset + countryCode.codeUnitAt(1) - asciiOffset);
    } catch (e) { return '🌍'; }
  }

  @override
  Widget build(BuildContext context) {
    Query query = FirebaseFirestore.instance.collection('users');
    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        var users = snapshot.data!.docs;
        if (showRealUsersOnly) users = users.where((doc) => (doc.data() as Map)['isFake'] != true).toList();
        
        if (users.isEmpty) return const Center(child: Text("No users found."));

        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final data = users[index].data() as Map<String, dynamic>;
            bool isFake = data['isFake'] == true;
            bool isReal = !isFake;
            return Card(
              color: isReal ? Colors.amber.shade900.withOpacity(0.3) : Colors.grey.shade900,
              shape: isReal ? RoundedRectangleBorder(side: BorderSide(color: Colors.amber, width: 2), borderRadius: BorderRadius.circular(10)) : null,
              child: ExpansionTile(
                leading: Text(_getFlagEmoji(data['countryCode']??''), style: const TextStyle(fontSize: 24)),
                title: Text(data['email']??'Unknown'),
                subtitle: Text("${data['countryCode']} - ${data['profileType']}"),
                trailing: isReal ? const Icon(Icons.star, color: Colors.amber) : null,
                children: [
                   ListTile(title: const Text("Recent Shopping:"), subtitle: Text("Click Analysis tab for details."))
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class AlertsPage extends StatelessWidget {
  const AlertsPage({super.key});
  @override
  Widget build(BuildContext context) { return const Center(child: Text("Alerts System Active")); }
}
