
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
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
      const SizedBox.shrink(),
      const GlobalInsightsPage(),
      const AlertsPage(),
      const RecipeTrendsPage(),
      const InventoryHealthPage(),
      const AssociationRulesPage(),
    ];
  }

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

  Future<void> _generateFakeData({bool simulatePowerOutage = false}) async {
    // Faker data generation logic remains here...
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
              if (value == 'update_users') _manuallyUpdateUserData();
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(value: 'normal', child: Row(children: [Icon(Icons.people, color: Colors.teal), SizedBox(width: 8), Text("Add 100 Users (Mass)")])),
              const PopupMenuItem(value: 'power_out', child: Row(children: [Icon(Icons.flash_off, color: Colors.red), SizedBox(width: 8), Text("Simulate Power Outage")])),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'update_users', child: Row(children: [Icon(Icons.sync, color: Colors.blue), SizedBox(width: 8), Text("Update All Users Now")])),
              const PopupMenuDivider(),
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
          NavigationDestination(icon: Icon(Icons.restaurant_menu), label: 'Recipes'),
          NavigationDestination(icon: Icon(Icons.inventory), label: 'Inventory'),
          NavigationDestination(icon: Icon(Icons.hub), label: 'Patterns'),
        ],
      ),
    );
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

  void _showEditDialog(BuildContext context, DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final nameC = TextEditingController(text: data['name'] ?? data['productName'] ?? data['title'] ?? '');
    // Önce current_weight_kg'ye bakıyoruz
    final weightC = TextEditingController(text: (data['current_weight_kg'] ?? data['weight'] ?? '').toString());
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit Item"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameC, decoration: const InputDecoration(labelText: "Name")),
            TextField(controller: weightC, decoration: const InputDecoration(labelText: "Weight (kg)"), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              doc.reference.update({
                'name': nameC.text,
                'current_weight_kg': double.tryParse(weightC.text) ?? 0.0,
                'updatedAt': FieldValue.serverTimestamp(),
              });
              Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void _showAddDialog(BuildContext context, DocumentReference userRef, String col) {
    final nameC = TextEditingController();
    final weightC = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Add to ${col.replaceAll('_', ' ')}"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameC, decoration: const InputDecoration(labelText: "Name")),
            TextField(controller: weightC, decoration: const InputDecoration(labelText: "Weight (kg)"), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              if (nameC.text.isNotEmpty) {
                userRef.collection(col).add({
                  'name': nameC.text,
                  'current_weight_kg': double.tryParse(weightC.text) ?? 0.0,
                  'updatedAt': FieldValue.serverTimestamp(),
                });
                Navigator.pop(context);
              }
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
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
            bool isReal = data['isFake'] != true;
            return Card(
              color: isReal ? Colors.amber.shade900.withOpacity(0.3) : Colors.grey.shade900,
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: ExpansionTile(
                leading: Text(_getFlagEmoji(data['countryCode']??''), style: const TextStyle(fontSize: 24)),
                title: Text(data['email']??'Unknown'),
                subtitle: Text("${data['countryCode']} - ${data['profileType']}"),
                children: [
                   Padding(
                     padding: const EdgeInsets.all(12.0),
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         _buildSecHeader(context, "Fridge Inventory:", Colors.tealAccent, () => _showAddDialog(context, doc.reference, 'fridge_inventory')),
                         _UserSubCollectionList(
                           userRef: doc.reference, 
                           collectionNames: const ['fridge_inventory', 'platforms', 'fridge_status'],
                           onEdit: (item) => _showEditDialog(context, item),
                         ),
                         const Divider(height: 32, color: Colors.white24),
                         _buildSecHeader(context, "Shopping List:", Colors.orangeAccent, () => _showAddDialog(context, doc.reference, 'shopping_list')),
                         _UserSubCollectionList(
                           userRef: doc.reference, 
                           collectionNames: const ['shopping_list'],
                           onEdit: (item) => _showEditDialog(context, item),
                         ),
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

  Widget _buildSecHeader(BuildContext context, String title, Color color, VoidCallback onAdd) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(children: [Icon(Icons.kitchen, size: 18, color: color), const SizedBox(width: 8), Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14))]),
        IconButton(icon: const Icon(Icons.add_circle_outline, size: 20, color: Colors.white70), onPressed: onAdd),
      ],
    );
  }
}

class _UserSubCollectionList extends StatelessWidget {
  final DocumentReference userRef;
  final List<String> collectionNames;
  final Function(DocumentSnapshot) onEdit;
  const _UserSubCollectionList({required this.userRef, required this.collectionNames, required this.onEdit});

  @override
  Widget build(BuildContext context) {
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
                  final name = data['name'] ?? data['productName'] ?? data['title'] ?? 'Item';
                  // Ağırlık gösteriminde de current_weight_kg'ye öncelik veriyoruz
                  final weight = data['current_weight_kg'] ?? data['weight'];
                  String label = name;
                  if (weight != null) label += " (${weight}kg)";
                  return InputChip(
                    label: Text(label, style: const TextStyle(fontSize: 11)),
                    onPressed: () => onEdit(doc),
                    onDeleted: () => doc.reference.delete(),
                    deleteIconColor: Colors.redAccent,
                    backgroundColor: Colors.white.withOpacity(0.05),
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

// GlobalInsightsPage, MarketAnalysisPage and others...
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

class GlobalInsightsPage extends StatelessWidget {
  const GlobalInsightsPage({super.key});
  @override
  Widget build(BuildContext context) { return const Center(child: Text("Global Insights")); }
}

class AlertsPage extends StatelessWidget {
  const AlertsPage({super.key});
  @override
  Widget build(BuildContext context) { return const Center(child: Text("Alerts")); }
}

class RecipeTrendsPage extends StatelessWidget {
  const RecipeTrendsPage({super.key});
  @override
  Widget build(BuildContext context) { return const Center(child: Text("Recipe Trends")); }
}

class InventoryHealthPage extends StatelessWidget {
  const InventoryHealthPage({super.key});
  @override
  Widget build(BuildContext context) { return const Center(child: Text("Inventory Health")); }
}

class AssociationRulesPage extends StatelessWidget {
  const AssociationRulesPage({super.key});
  @override
  Widget build(BuildContext context) { return const Center(child: Text("Association Rules")); }
}
