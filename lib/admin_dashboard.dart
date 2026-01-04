
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart'; // YENİ EKLENDİ
import 'package:fl_chart/fl_chart.dart';
import 'package:faker/faker.dart' hide Color;
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
      const RecipeTrendsPage(),
      const InventoryHealthPage(),
      const AssociationRulesPage(),
    ];
  }

  // --- YENİ FONKSİYON: MANUEL GÜNCELLEME ---
  Future<void> _manuallyUpdateUserData() async {
    setState(() => _isLoading = true);
    try {
      final functions = FirebaseFunctions.instance;
      final result = await functions.httpsCallable('manualUserDataUpdate').call();

      final message = result.data['message'] ?? "İşlem tamamlandı.";
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ $message'), backgroundColor: Colors.green),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Hata: ${e.message}'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Beklenmedik bir hata oluştu: $e')), 
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }


  // --- TEMİZLİK ---
  Future<void> _deleteFakeData() async {
    setState(() => _isLoading = true);
    final firestore = FirebaseFirestore.instance;
    int deletedCount = 0;
    try {
      final snapshot = await firestore.collection('users').where('isFake', isEqualTo: true).get();
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

  // --- GELİŞMİŞ FAKER MOTORU ---
  Future<void> _generateFakeData({bool simulatePowerOutage = false}) async {
    setState(() => _isLoading = true);
    final firestore = FirebaseFirestore.instance;
    final faker = Faker();
    final random = Random();

    final countryProfiles = {
      'DE': {
        'cats': ['Beverages', 'Meat & Fish', 'Snacks'],
        'items': ['German Beer', 'Bratwurst', 'Pretzel', 'Schnitzel', 'Potato Salad', 'Rye Bread', 'Sauerkraut', 'Mustard', 'Currywurst']
      },
      'TR': {
        'cats': ['Vegetables', 'Dairy', 'Staples'],
        'items': ['Turkish Tea', 'Feta Cheese', 'Olives', 'Simit', 'Yoghurt', 'Tomato', 'Cucumber', 'Baklava', 'Sucuk', 'Pastirma']
      },
      // ... Diğer ülkeler ...
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
          // ... Kullanıcı oluşturma mantığı ...
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
      case 4: bodyContent = const RecipeTrendsPage(); break;
      case 5: bodyContent = const InventoryHealthPage(); break;
      case 6: bodyContent = const AssociationRulesPage(); break;
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
              if (value == 'update_users') _manuallyUpdateUserData(); // YENİ EKLENDİ
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(value: 'normal', child: Row(children: [Icon(Icons.people, color: Colors.teal), SizedBox(width: 8), Text("Add 100 Users (Mass)")])),
              const PopupMenuItem(value: 'power_out', child: Row(children: [Icon(Icons.flash_off, color: Colors.red), SizedBox(width: 8), Text("Simulate Power Outage")])),
              const PopupMenuDivider(), // AYRAÇ
              const PopupMenuItem(value: 'update_users', child: Row(children: [Icon(Icons.sync, color: Colors.blue), SizedBox(width: 8), Text("Update All Users Now")])), // YENİ BUTON
              const PopupMenuDivider(), // AYRAÇ
              const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_forever, color: Colors.redAccent), SizedBox(width: 8), Text("Delete Fake Data")])),
            ],
            icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.settings, color: Colors.white),
          ),
        ],
      ),
      body: bodyContent,
      // ... Kalan kod aynı ...
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (int index) => setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.pie_chart), label: 'Market'),
          NavigationDestination(icon: Icon(Icons.people), label: 'Users'),
          NavigationDestination(icon: Icon(Icons.public), label: 'Global'), 
          NavigationDestination(icon: Icon(Icons.warning), label: 'Alerts'),
          NavigationDestination(icon: Icon(Icons.restaurant_menu), label: 'Recipes'),
          NavigationDestination(icon: Icon(Icons.inventory), label: 'Inventory'),
          NavigationDestination(icon: Icon(Icons.hub), label: 'Patterns'),
        ],
      ),
    );
  }
}

// --- USER TRACKING PAGE (DÜZELTİLDİ VE GELİŞTİRİLDİ) ---
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
            final doc = users[index];
            final data = doc.data() as Map<String, dynamic>;
            bool isFake = data['isFake'] == true;
            bool isReal = !isFake;
            return Card(
              color: isReal ? Colors.amber.shade900.withOpacity(0.3) : Colors.grey.shade900,
              shape: isReal ? RoundedRectangleBorder(side: const BorderSide(color: Colors.amber, width: 2), borderRadius: BorderRadius.circular(10)) : null,
              child: ExpansionTile(
                leading: Text(_getFlagEmoji(data['countryCode']??''), style: const TextStyle(fontSize: 24)),
                title: Text(data['email']??'Unknown'),
                subtitle: Text("${data['countryCode']} - ${data['profileType']}"),
                trailing: isReal ? const Icon(Icons.star, color: Colors.amber) : null,
                children: [
                   Padding(
                     padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         const Row(
                           children: [
                             Icon(Icons.kitchen, size: 18, color: Colors.tealAccent),
                             SizedBox(width: 8),
                             Text("Fridge Inventory:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.tealAccent, fontSize: 14)),
                           ],
                         ),
                         const SizedBox(height: 8),
                         // Buzdolabı için birden fazla muhtemel koleksiyonu tarıyoruz
                         _UserSubCollectionList(
                           userRef: doc.reference, 
                           collectionNames: const ['fridge_inventory', 'platforms', 'fridge_status']
                         ),
                         const Divider(height: 24, color: Colors.white24),
                         const Row(
                           children: [
                             Icon(Icons.shopping_cart, size: 18, color: Colors.orangeAccent),
                             SizedBox(width: 8),
                             Text("Shopping List:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orangeAccent, fontSize: 14)),
                           ],
                         ),
                         const SizedBox(height: 8),
                         _UserSubCollectionList(
                           userRef: doc.reference, 
                           collectionNames: const ['shopping_list']
                         ),
                         const SizedBox(height: 8),
                       ],
                     ),
                   )
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// --- YARDIMCI WIDGET: BİRDEN FAZLA ALT KOLEKSİYONU TARAYABİLEN LİSTELEYİCİ ---
class _UserSubCollectionList extends StatelessWidget {
  final DocumentReference userRef;
  final List<String> collectionNames;
  const _UserSubCollectionList({required this.userRef, required this.collectionNames});

  @override
  Widget build(BuildContext context) {
    // Birden fazla koleksiyonu kontrol etmek için her birini ayrı ayrı dinleyen yapı
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: collectionNames.map((colName) {
        return StreamBuilder<QuerySnapshot>(
          stream: userRef.collection(colName).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox.shrink();
            
            var items = snapshot.data!.docs;
            return Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: items.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  // Farklı dokümanlarda farklı alan isimleri olabilir (name, productName, title vb.)
                  final String name = data['name'] ?? data['productName'] ?? data['title'] ?? data['product'] ?? 'Item';
                  final weight = data['weight'];
                  String label = name;
                  if (weight != null) label += " (${weight}kg)";

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white12)
                    ),
                    child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.white70)),
                  );
                }).toList(),
              ),
            );
          },
        );
      }).toList(),
    );
  }
}

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
               title: '${((e.value/(_totalItems == 0 ? 1 : _totalItems))*100).toStringAsFixed(0)}%', 
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

class AlertsPage extends StatelessWidget {
  const AlertsPage({super.key});
  @override
  Widget build(BuildContext context) { return const Center(child: Text("Alerts System Active")); }
}

class RecipeTrendsPage extends StatefulWidget {
  const RecipeTrendsPage({super.key});

  @override
  State<RecipeTrendsPage> createState() => _RecipeTrendsPageState();
}

class _RecipeTrendsPageState extends State<RecipeTrendsPage> {
  bool _loading = true;
  Map<String, double> _avgCalories = {};
  
  @override
  void initState() {
    super.initState();
    _analyzeRecipes();
  }

  Future<void> _analyzeRecipes() async {
    final firestore = FirebaseFirestore.instance;
    Map<String, List<int>> countryCalories = {}; 

    try {
      final usersSnapshot = await firestore.collection('users').get();
      for (var userDoc in usersSnapshot.docs) {
         String country = userDoc.data()['countryCode'] ?? 'Unknown';
         if (country == 'Unknown') continue;

         final recipesSnapshot = await userDoc.reference.collection('recipes').get();
         for (var recipeDoc in recipesSnapshot.docs) {
            var calData = recipeDoc.data()['calories'];
            int cal = 0;
            if (calData is int) cal = calData;
            else if (calData is String) cal = int.tryParse(calData) ?? 0;
            
            if (cal > 0) {
              if (!countryCalories.containsKey(country)) {
                countryCalories[country] = [];
              }
              countryCalories[country]!.add(cal);
            }
         }
      }
    } catch (e) {
      print("Error analyzing recipes: $e");
    }

    Map<String, double> finalStats = {};
    countryCalories.forEach((country, calories) {
       if (calories.isNotEmpty) {
         double avg = calories.reduce((a, b) => a + b) / calories.length;
         finalStats[country] = avg;
       }
    });

    if (mounted) {
      setState(() {
        _avgCalories = finalStats;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
     if (_loading) return const Center(child: CircularProgressIndicator());
     
     if (_avgCalories.isEmpty) {
       return Center(child: Column(
         mainAxisAlignment: MainAxisAlignment.center,
         children: [
           const Text("No recipe data found."),
           const SizedBox(height: 10),
           ElevatedButton(onPressed: _analyzeRecipes, child: const Text("Refresh"))
         ],
       ));
     }

     var sortedEntries = _avgCalories.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
     
     return ListView(
       padding: const EdgeInsets.all(16),
       children: [
         const Text("🔥 Average Calories per Recipe by Country", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
         const SizedBox(height: 8),
         const Text("Analysis of user recipe collections.", style: TextStyle(fontSize: 12, color: Colors.grey)),
         const SizedBox(height: 20),
         Container(
           height: 300,
           padding: const EdgeInsets.all(16),
           decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(16)),
           child: BarChart(
             BarChartData(
               alignment: BarChartAlignment.spaceAround,
               barTouchData: BarTouchData(enabled: true),
               titlesData: FlTitlesData(
                 leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
                 bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= sortedEntries.length) return const Text('');
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(sortedEntries[value.toInt()].key, style: const TextStyle(fontWeight: FontWeight.bold)),
                        );
                      }
                    )
                 ),
                 topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                 rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
               ),
               barGroups: sortedEntries.asMap().entries.map((e) {
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(toY: e.value.value, color: Colors.orangeAccent, width: 16, borderRadius: BorderRadius.circular(4))
                    ]
                  );
               }).toList(),
               borderData: FlBorderData(show: false),
               gridData: const FlGridData(show: true, drawVerticalLine: false),
             )
           ),
         ),
         const SizedBox(height: 20),
         ...sortedEntries.map((e) => ListTile(
           leading: Text(e.key, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
           title: Text("${e.value.toStringAsFixed(0)} kcal / meal"),
           trailing: Icon(Icons.local_fire_department, color: e.value > 600 ? Colors.red : Colors.amber),
         ))
       ],
     );
  }
}

class InventoryHealthPage extends StatefulWidget {
  const InventoryHealthPage({super.key});

  @override
  State<InventoryHealthPage> createState() => _InventoryHealthPageState();
}

class _InventoryHealthPageState extends State<InventoryHealthPage> {
  bool _loading = true;
  Map<String, double> _countryFillRate = {};

  @override
  void initState() {
    super.initState();
    _analyzeInventory();
  }

  Future<void> _analyzeInventory() async {
    final firestore = FirebaseFirestore.instance;
    Map<String, List<double>> countryWeights = {};

    try {
      final usersSnapshot = await firestore.collection('users').get();
      for (var userDoc in usersSnapshot.docs) {
        String country = userDoc.data()['countryCode'] ?? 'Unknown';
        if (country == 'Unknown') continue;

        final platformsSnapshot = await userDoc.reference.collection('platforms').get();
        double totalUserWeight = 0;
        for (var platformDoc in platformsSnapshot.docs) {
            var w = platformDoc.data()['weight'];
            if (w is double) totalUserWeight += w;
            else if (w is int) totalUserWeight += w.toDouble();
        }
        
        double maxCapacity = 15.0; 
        double fillRate = (totalUserWeight / maxCapacity) * 100;
        if (fillRate > 100) fillRate = 100;

        if (!countryWeights.containsKey(country)) {
          countryWeights[country] = [];
        }
        countryWeights[country]!.add(fillRate);
      }
    } catch (e) {
      print("Error analyzing inventory: $e");
    }

    Map<String, double> finalStats = {};
    countryWeights.forEach((country, rates) {
       if (rates.isNotEmpty) {
         double avg = rates.reduce((a, b) => a + b) / rates.length;
         finalStats[country] = avg;
       }
    });

    if (mounted) {
      setState(() {
        _countryFillRate = finalStats;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_countryFillRate.isEmpty) {
       return Center(child: Column(
         mainAxisAlignment: MainAxisAlignment.center,
         children: [
           const Text("No inventory data found."),
           const SizedBox(height: 10),
           ElevatedButton(onPressed: _analyzeInventory, child: const Text("Refresh"))
         ],
       ));
    }

    var sortedEntries = _countryFillRate.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text("📦 Fridge Inventory Health", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text("Average fridge fill rate by country based on weight sensors.", style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 20),

        Container(
           height: 300,
           padding: const EdgeInsets.all(16),
           decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(16)),
           child: BarChart(
             BarChartData(
               alignment: BarChartAlignment.spaceAround,
               barTouchData: BarTouchData(enabled: true),
               titlesData: FlTitlesData(
                 leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
                 bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= sortedEntries.length) return const Text('');
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(sortedEntries[value.toInt()].key, style: const TextStyle(fontWeight: FontWeight.bold)),
                        );
                      }
                    )
                 ),
                 topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                 rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
               ),
               maxY: 100,
               barGroups: sortedEntries.asMap().entries.map((e) {
                  Color barColor = e.value.value > 75 ? Colors.green : (e.value.value > 40 ? Colors.amber : Colors.red);
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(toY: e.value.value, color: barColor, width: 16, borderRadius: BorderRadius.circular(4))
                    ]
                  );
               }).toList(),
               borderData: FlBorderData(show: false),
               gridData: const FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 20),
             )
           ),
         ),
         const SizedBox(height: 20),
         ...sortedEntries.map((e) {
            Color statusColor = e.value > 75 ? Colors.green : (e.value > 40 ? Colors.amber : Colors.red);
            return ListTile(
              leading: Text(e.key, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              title: LinearProgressIndicator(value: e.value / 100, color: statusColor, backgroundColor: Colors.grey.shade800, minHeight: 10),
              trailing: Text("${e.value.toStringAsFixed(1)}% Full", style: TextStyle(color: statusColor, fontWeight: FontWeight.bold)),
            );
         })
      ],
    );
  }
}

class AssociationRulesPage extends StatefulWidget {
  const AssociationRulesPage({super.key});

  @override
  State<AssociationRulesPage> createState() => _AssociationRulesPageState();
}

class _AssociationRulesPageState extends State<AssociationRulesPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _rules = [];

  @override
  void initState() {
    super.initState();
    _mineAssociationRules();
  }

  Future<void> _mineAssociationRules() async {
    setState(() => _loading = true);
    final firestore = FirebaseFirestore.instance;
    
    List<Set<String>> transactions = [];
    
    try {
      final usersSnapshot = await firestore.collection('users').get();
      var processDocs = usersSnapshot.docs.take(50).toList();
      
      for (var userDoc in processDocs) {
         final listSnapshot = await userDoc.reference.collection('shopping_list').get();
         if (listSnapshot.docs.isEmpty) continue;
         
         Set<String> basket = {};
         for (var itemDoc in listSnapshot.docs) {
            String name = itemDoc.data()['name'] ?? '';
            if (name.isNotEmpty) basket.add(name);
         }
         if (basket.length > 1) transactions.add(basket);
      }
    } catch (e) {
      print("Error mining rules: $e");
    }

    Map<String, int> itemSupport = {};
    Map<String, int> pairSupport = {};
    int totalTransactions = transactions.length;

    if (totalTransactions == 0) {
      if (mounted) setState(() { _rules = []; _loading = false; });
      return;
    }

    for (var basket in transactions) {
       List<String> items = basket.toList();
       
       for (var item in items) {
         itemSupport[item] = (itemSupport[item] ?? 0) + 1;
       }

       for (int i = 0; i < items.length; i++) {
         for (int j = i + 1; j < items.length; j++) {
            List<String> pair = [items[i], items[j]]..sort();
            String pairKey = "${pair[0]}::${pair[1]}";
            pairSupport[pairKey] = (pairSupport[pairKey] ?? 0) + 1;
         }
       }
    }

    List<Map<String, dynamic>> foundRules = [];

    pairSupport.forEach((pairKey, count) {
       List<String> parts = pairKey.split("::");
       String itemA = parts[0];
       String itemB = parts[1];

       double confAtoB = count / (itemSupport[itemA] ?? 1);
       if (confAtoB > 0.15) {
         foundRules.add({
           'rule': "$itemA ➡ $itemB",
           'confidence': confAtoB,
           'support': count
         });
       }

       double confBtoA = count / (itemSupport[itemB] ?? 1);
       if (confBtoA > 0.15) {
          foundRules.add({
           'rule': "$itemB ➡ $itemA",
           'confidence': confBtoA,
           'support': count
         });
       }
    });

    foundRules.sort((a, b) => b['confidence'].compareTo(a['confidence']));

    if (mounted) {
      setState(() {
        _rules = foundRules.take(50).toList();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_rules.isEmpty) {
      return Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.hub, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text("No significant patterns found yet."),
          const Text("Try adding more users/data."),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _mineAssociationRules, child: const Text("Run Mining Again"))
        ],
      ));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _rules.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
           return const Padding(
             padding: EdgeInsets.only(bottom: 20),
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 Text("🧠 AI Shopping Patterns", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                 SizedBox(height: 8),
                 Text("Detected correlations between products based on user purchase history (Association Rules).", style: TextStyle(color: Colors.grey)),
               ],
             ),
           );
        }
        
        final rule = _rules[index - 1];
        final double confidence = rule['confidence'];
        Color confColor = confidence > 0.6 ? Colors.green : (confidence > 0.4 ? Colors.amber : Colors.grey);

        return Card(
          color: Colors.white10,
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: confColor.withOpacity(0.2),
              child: Text("${(confidence * 100).toInt()}%", style: TextStyle(color: confColor, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
            title: Text(rule['rule'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            subtitle: Text("Support: Observed in ${rule['support']} baskets"),
            trailing: const Icon(Icons.arrow_forward, color: Colors.white54),
          ),
        );
      },
    );
  }
}
