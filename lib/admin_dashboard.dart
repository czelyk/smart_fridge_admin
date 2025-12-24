import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;
  bool _isLoading = false;
  
  // FİLTRELEME İÇİN
  bool _showRealUsersOnly = false; 

  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      const MarketAnalysisPage(),
      const SizedBox.shrink(), // Placeholder for UserTrackingPage
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
      
      for (var doc in snapshot.docs) {
        await _deleteSubCollection(doc.reference, 'fridge_status');
        await _deleteSubCollection(doc.reference, 'platforms');
        await _deleteSubCollection(doc.reference, 'recipes');
        await _deleteSubCollection(doc.reference, 'shopping_list');
        await _deleteSubCollection(doc.reference, 'consumption_logs');
        await _deleteSubCollection(doc.reference, 'fridge_inventory');
        
        await doc.reference.delete();
        deletedCount++;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('🗑️ Deleted $deletedCount fake users!'), backgroundColor: Colors.redAccent),
        );
        setState(() {});
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
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

  // --- SAHTE VERİ MOTORU ---
  Future<void> _generateFakeData({bool simulatePowerOutage = false}) async {
    setState(() => _isLoading = true);
    final firestore = FirebaseFirestore.instance;
    final random = Random();

    final fakeUsers = [
      {'email': 'hans.mueller@example.com', 'type': 'Family', 'country': 'DE', 'lang': 'de'},
      {'email': 'ayse.yilmaz@test.com', 'type': 'Student', 'country': 'TR', 'lang': 'tr'},
      {'email': 'john.doe@usa.com', 'type': 'Single', 'country': 'US', 'lang': 'en'},
      {'email': 'chef.luigi@pizza.it', 'type': 'Restaurant', 'country': 'IT', 'lang': 'it'},
      {'email': 'student.dorm@uni.edu', 'type': 'Shared', 'country': 'US', 'lang': 'en'},
      {'email': 'family.smith@uk.co', 'type': 'Family', 'country': 'GB', 'lang': 'en'},
      {'email': 'vegan.lisa@green.org', 'type': 'Vegan', 'country': 'US', 'lang': 'en'},
      {'email': 'bbq.master@meat.com', 'type': 'Carnivore', 'country': 'BR', 'lang': 'pt'},
      {'email': 'cafe.central@business.com', 'type': 'Business', 'country': 'FR', 'lang': 'fr'},
      {'email': 'grandma.betty@home.com', 'type': 'Elderly', 'country': 'CA', 'lang': 'en'}
    ];

    final categories = ['Vegetables', 'Fruits', 'Beverages', 'Meat & Fish', 'Dairy', 'Snacks', 'Staples'];
    final itemNames = {
      'Vegetables': ['Tomato', 'Cucumber', 'Lettuce', 'Carrot', 'Spinach'],
      'Fruits': ['Apple', 'Banana', 'Orange', 'Strawberry'],
      'Beverages': ['Milk', 'Cola', 'Juice', 'Water', 'Beer'],
      'Meat & Fish': ['Chicken Breast', 'Steak', 'Salmon', 'Sausage'],
      'Dairy': ['Cheese', 'Yogurt', 'Butter', 'Cream'],
      'Snacks': ['Chips', 'Chocolate', 'Cookies'],
      'Staples': ['Rice', 'Pasta', 'Bread', 'Eggs']
    };

    final recipeSamples = [
      {'name': 'Tomato Soup', 'calories': 200, 'time': '30 min'},
      {'name': 'Grilled Chicken', 'calories': 450, 'time': '45 min'},
      {'name': 'Fruit Salad', 'calories': 150, 'time': '10 min'},
      {'name': 'Pasta Carbonara', 'calories': 600, 'time': '20 min'},
      {'name': 'Vegetable Stir Fry', 'calories': 300, 'time': '25 min'},
    ];

    try {
      for (var userMap in fakeUsers) {
        String email = userMap['email']!;
        
        DocumentReference userRef = await firestore.collection('users').add({
          'email': email,
          'profileType': userMap['type'],
          'countryCode': userMap['country'], 
          'languageCode': userMap['lang'],
          'createdAt': FieldValue.serverTimestamp(),
          'isFake': true,
        });

        // Fridge Status
        bool isPowerOut = simulatePowerOutage && (random.nextDouble() < 0.3);
        double temp;
        double humidity = 30 + random.nextDouble() * 50;
        dynamic timestampValue = FieldValue.serverTimestamp();

        if (isPowerOut) {
          temp = 8.0 + random.nextDouble() * 6.0; 
          timestampValue = Timestamp.fromDate(DateTime.now().subtract(Duration(hours: 2 + random.nextInt(10))));
        } else {
          bool isBroken = random.nextDouble() < 0.15;
          temp = isBroken ? (11 + random.nextDouble() * 5) : (2 + random.nextDouble() * 5);
        }

        await userRef.collection('fridge_status').doc('current_status').set({
          'temperature': temp,
          'humidity': humidity,
          'updatedAt': timestampValue,
        });

        // Platforms
        for (int i = 1; i <= 3; i++) {
          String category = categories[random.nextInt(categories.length)];
          await userRef.collection('platforms').doc('platform$i').set({
            'name': 'Shelf $i',
            'weight': (0.5 + random.nextDouble() * 4.5), 
            'category': category,
          });
        }

        // Recipes
        int recipeCount = 2 + random.nextInt(4);
        for(int i=0; i<recipeCount; i++) {
           var recipe = recipeSamples[random.nextInt(recipeSamples.length)];
           await userRef.collection('recipes').add({
             'name': recipe['name'],
             'calories': recipe['calories'],
             'cookingTime': recipe['time'],
             'isFavorite': random.nextBool(),
           });
        }

        // Shopping List
         int shopCount = 3 + random.nextInt(6);
         for(int i=0; i<shopCount; i++) {
            String category = categories[random.nextInt(categories.length)];
            String itemName = itemNames[category]![random.nextInt(itemNames[category]!.length)];
            await userRef.collection('shopping_list').add({
              'name': itemName,
              'category': category,
              'isBought': random.nextBool(),
            });
         }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Data Populated!'), backgroundColor: Colors.teal));
        setState(() {});
      }
    } catch (e) {
      print(e);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Sayfa seçimi
    Widget bodyContent;
    switch (_selectedIndex) {
      case 0:
        bodyContent = const MarketAnalysisPage();
        break;
      case 1:
        // Real User filtresini parametre olarak geçiyoruz
        bodyContent = UserTrackingPage(showRealUsersOnly: _showRealUsersOnly);
        break;
      case 2:
        bodyContent = const AlertsPage();
        break;
      default:
        bodyContent = const MarketAnalysisPage();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Fridge Admin'),
        centerTitle: true,
        backgroundColor: Colors.teal.shade900,
        actions: [
          // FİLTRE BUTONU (Sadece Users sekmesinde göster)
          if (_selectedIndex == 1)
            IconButton(
              icon: Icon(_showRealUsersOnly ? Icons.filter_alt : Icons.filter_alt_off),
              tooltip: _showRealUsersOnly ? "Show All Users" : "Show Real Users Only",
              onPressed: () {
                setState(() {
                  _showRealUsersOnly = !_showRealUsersOnly;
                });
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(_showRealUsersOnly ? "Showing Real Users Only" : "Showing All Users"),
                  duration: const Duration(seconds: 1),
                ));
              },
            ),

          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'normal') _generateFakeData(simulatePowerOutage: false);
              if (value == 'power_out') _generateFakeData(simulatePowerOutage: true);
              if (value == 'delete') _deleteFakeData();
            },
            itemBuilder: (BuildContext context) {
              return [
                const PopupMenuItem(value: 'normal', child: Row(children: [Icon(Icons.cloud_upload, color: Colors.teal), SizedBox(width: 8), Text("Populate DB")])),
                const PopupMenuItem(value: 'power_out', child: Row(children: [Icon(Icons.flash_off, color: Colors.red), SizedBox(width: 8), Text("Simulate Power Outage")])),
                const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_forever, color: Colors.redAccent), SizedBox(width: 8), Text("Delete Fake Data")])),
              ];
            },
            icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.settings, color: Colors.white),
          ),
        ],
      ),
      body: bodyContent,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.pie_chart_outline), selectedIcon: Icon(Icons.pie_chart), label: 'Analysis'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Users'),
          NavigationDestination(icon: Icon(Icons.warning_amber_outlined), selectedIcon: Icon(Icons.warning_amber), label: 'Alerts'),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 1. MARKET ANALYSIS
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
          final data = doc.data();
          final category = data['category'] as String? ?? 'Other';
          counts[category] = (counts[category] ?? 0) + 1;
          total++;
        }
      }
    } catch (e) {
      print("Error: $e");
    }
    if (mounted) setState(() { _categoryData = counts; _totalItems = total; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_categoryData.isEmpty) return Center(child: TextButton(onPressed: _fetchAnalysisData, child: const Text("Load Data")));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
           Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
             const Text("Shopping List Distribution", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
             IconButton(onPressed: _fetchAnalysisData, icon: const Icon(Icons.refresh))
           ]),
           const SizedBox(height: 20),
           SizedBox(height: 300, child: PieChart(PieChartData(sections: _generateSections(), centerSpaceRadius: 40))),
           const SizedBox(height: 20),
           Wrap(spacing: 16, runSpacing: 8, children: _categoryData.keys.map((cat) => _LegendItem(color: _getColorForCategory(cat), text: '$cat (${_categoryData[cat]!.toInt()})')).toList()),
        ],
      ),
    );
  }

  List<PieChartSectionData> _generateSections() {
    return _categoryData.entries.map((entry) {
      return PieChartSectionData(
        color: _getColorForCategory(entry.key),
        value: entry.value,
        title: '${((entry.value / _totalItems) * 100).toStringAsFixed(0)}%',
        radius: 50,
        titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
      );
    }).toList();
  }

  Color _getColorForCategory(String category) {
    switch (category) {
      case 'Vegetables': return Colors.green;
      case 'Fruits': return Colors.redAccent;
      case 'Beverages': return Colors.blue;
      case 'Meat & Fish': return Colors.brown;
      case 'Dairy': return Colors.yellow.shade700;
      case 'Snacks': return Colors.purple;
      case 'Staples': return Colors.orange;
      default: return Colors.grey;
    }
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String text;
  const _LegendItem({required this.color, required this.text});
  @override
  Widget build(BuildContext context) {
    return Row(children: [Container(width: 12, height: 12, color: color), const SizedBox(width: 4), Text(text)]);
  }
}

// -----------------------------------------------------------------------------
// 2. USER TRACKING (Sıralama Kaldırıldı)
// -----------------------------------------------------------------------------
class UserTrackingPage extends StatelessWidget {
  final bool showRealUsersOnly;
  const UserTrackingPage({super.key, this.showRealUsersOnly = false});

  String _getFlagEmoji(String countryCode) {
    if (countryCode.isEmpty) return '🌍';
    try {
      int flagOffset = 0x1F1E6;
      int asciiOffset = 0x41;
      return String.fromCharCode(flagOffset + countryCode.codeUnitAt(0) - asciiOffset) +
             String.fromCharCode(flagOffset + countryCode.codeUnitAt(1) - asciiOffset);
    } catch (e) {
      return '🌍';
    }
  }

  @override
  Widget build(BuildContext context) {
    // DÜZELTME: orderBy('createdAt') KALDIRILDI.
    // Böylece tarihi eksik olan gerçek kullanıcılar da listelenir.
    Query query = FirebaseFirestore.instance.collection('users');
    
    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        var users = snapshot.data!.docs;
        
        if (showRealUsersOnly) {
          users = users.where((doc) {
             final data = doc.data() as Map<String, dynamic>;
             return data['isFake'] != true;
          }).toList();
        }

        if (users.isEmpty) return const Center(child: Text("No users found."));

        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final userDoc = users[index];
            final userData = userDoc.data() as Map<String, dynamic>;
            final email = userData['email'] ?? 'Unknown User';
            final profileType = userData['profileType'] ?? 'Standard';
            final countryCode = userData['countryCode'] ?? '';
            final languageCode = userData['languageCode'] ?? '';

            bool isFake = userData['isFake'] == true;
            bool isRealUser = !isFake;

            return Card(
              elevation: isRealUser ? 4 : 1,
              shape: isRealUser 
                ? RoundedRectangleBorder(side: const BorderSide(color: Colors.amber, width: 2), borderRadius: BorderRadius.circular(12))
                : null,
              color: isFake ? Colors.teal.shade900.withOpacity(0.3) : Colors.grey.shade800,
              
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ExpansionTile(
                leading: CircleAvatar(
                  backgroundColor: isRealUser ? Colors.amber.shade800 : Colors.teal.shade800,
                  child: isRealUser 
                    ? const Icon(Icons.person, color: Colors.white) 
                    : Text(_getFlagEmoji(countryCode), style: const TextStyle(fontSize: 20)),
                ),
                title: Row(
                  children: [
                    Expanded(child: Text(email, style: TextStyle(fontWeight: FontWeight.bold, color: isRealUser ? Colors.amberAccent : Colors.white))),
                    if (isRealUser) const Chip(label: Text("REAL", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)), backgroundColor: Colors.amber, padding: EdgeInsets.all(0), labelPadding: EdgeInsets.symmetric(horizontal: 8))
                  ],
                ),
                subtitle: Text("$profileType • $countryCode / $languageCode", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                children: [
                  _FridgeStatusWidget(userId: userDoc.id),
                  const Divider(color: Colors.white24, thickness: 1, indent: 16, endIndent: 16),
                  _FridgePlatformsWidget(userId: userDoc.id),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _FridgeStatusWidget extends StatelessWidget {
  final String userId;
  const _FridgeStatusWidget({required this.userId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(userId).collection('fridge_status').doc('current_status').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox.shrink();

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final temp = (data['temperature'] ?? 0).toDouble();
        final Timestamp? updatedAt = data['updatedAt'] as Timestamp?;

        bool isOffline = false;
        String statusText = "Online";
        Color statusColor = Colors.green;

        if (updatedAt != null) {
          final diff = DateTime.now().difference(updatedAt.toDate());
          if (diff.inHours > 1) {
            isOffline = true;
            statusText = "OFFLINE (${diff.inHours}h)";
            statusColor = Colors.grey;
          }
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(children: [
                Icon(Icons.thermostat, color: isOffline ? Colors.grey : (temp > 10 ? Colors.red : Colors.green)),
                Text("${temp.toStringAsFixed(1)}°C", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isOffline ? Colors.grey : Colors.white)),
                const Text("Temperature", style: TextStyle(fontSize: 10, color: Colors.white70)),
              ]),
              Column(children: [
                Icon(isOffline ? Icons.power_off : Icons.wifi, color: statusColor),
                Text(statusText, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: statusColor)),
                const Text("Status", style: TextStyle(fontSize: 10, color: Colors.white70)),
              ]),
            ],
          ),
        );
      },
    );
  }
}

// Platform Widget (Aynı)
class _FridgePlatformsWidget extends StatelessWidget {
  final String userId;
  const _FridgePlatformsWidget({required this.userId});

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Vegetables': return Icons.eco;
      case 'Fruits': return Icons.apple;
      case 'Beverages': return Icons.local_drink;
      case 'Meat & Fish': return Icons.restaurant;
      case 'Dairy': return Icons.local_pizza;
      case 'Snacks': return Icons.cookie;
      case 'Staples': return Icons.rice_bowl;
      default: return Icons.inventory_2;
    }
  }

  void _showEditWeightDialog(BuildContext context, DocumentReference platformRef, String name, double currentWeight) {
    final TextEditingController _controller = TextEditingController(text: currentWeight.toString());
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Edit Weight: $name"),
          content: TextField(
            controller: _controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: "New Weight (kg)",
              suffixText: "kg",
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                String text = _controller.text.replaceAll(',', '.');
                double? newVal = double.tryParse(text);
                
                if (newVal != null) {
                  platformRef.update({'weight': newVal});
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Weight updated successfully!"), backgroundColor: Colors.green));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid number!"), backgroundColor: Colors.red));
                }
              },
              child: const Text("Save"),
            )
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(userId).collection('platforms').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: LinearProgressIndicator(minHeight: 2));
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
           return const Padding(padding: EdgeInsets.all(16), child: Text("No platforms found.", style: TextStyle(color: Colors.grey)));
        }

        final platforms = snapshot.data!.docs;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 16, top: 8, bottom: 4),
              child: Text("PLATFORMS (EDITABLE)", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.tealAccent, letterSpacing: 1.0)),
            ),
            ...platforms.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final name = data['name'] ?? 'Shelf';
              final weight = (data['weight'] ?? 0).toDouble();
              final category = data['category'] ?? 'Other';

              return ListTile(
                dense: true,
                leading: Icon(_getCategoryIcon(category), color: Colors.teal.shade200, size: 20),
                title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(category, style: const TextStyle(fontSize: 12, color: Colors.white70)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("${weight.toStringAsFixed(2)} kg", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.edit, size: 18, color: Colors.orangeAccent),
                      tooltip: 'Edit Weight',
                      onPressed: () => _showEditWeightDialog(context, doc.reference, name, weight),
                    ),
                  ],
                ),
              );
            }).toList(),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// 3. ALERTS (Aynı)
// -----------------------------------------------------------------------------
class AlertsPage extends StatelessWidget {
  const AlertsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final users = snapshot.data!.docs;
        
        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final userId = users[index].id;
            final userData = users[index].data() as Map<String, dynamic>;
            final userEmail = userData['email'] ?? 'User';
            final countryCode = userData['countryCode'] ?? '';

            return StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(userId).collection('fridge_status').doc('current_status').snapshots(),
              builder: (context, statusSnapshot) {
                if (!statusSnapshot.hasData || !statusSnapshot.data!.exists) return const SizedBox.shrink();
                
                final data = statusSnapshot.data!.data() as Map<String, dynamic>;
                final double temp = (data['temperature'] ?? 0).toDouble();
                final Timestamp? updatedAt = data['updatedAt'] as Timestamp?;

                bool isHighTemp = temp > 10.0;
                bool isOffline = false;

                if (updatedAt != null) {
                  if (DateTime.now().difference(updatedAt.toDate()).inHours > 1) isOffline = true;
                }

                if (!isHighTemp && !isOffline) return const SizedBox.shrink();

                String locationText = countryCode.isNotEmpty ? "($countryCode)" : "";

                return Card(
                  color: isOffline ? Colors.grey.shade900 : Colors.red.shade900.withOpacity(0.6),
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    leading: Icon(isOffline ? Icons.power_off : Icons.warning_amber, color: isOffline ? Colors.grey : Colors.redAccent, size: 40),
                    title: Text(isOffline ? "Lost Connection $locationText" : "High Temperature $locationText", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    subtitle: Text(
                      isOffline ? "$userEmail (Power Outage?)" : "$userEmail (${temp.toStringAsFixed(1)}°C)", 
                      style: const TextStyle(color: Colors.white70)
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
