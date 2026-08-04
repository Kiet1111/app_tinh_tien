import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'create_order_screen.dart';
import 'order_detail_screen.dart';

class TableMapScreen extends StatelessWidget {
  const TableMapScreen({Key? key}) : super(key: key);

  void _showOrderSelectionDialog(BuildContext context, String tableName, List<QueryDocumentSnapshot> orders) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Danh Sách Đơn - $tableName', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ...orders.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final total = (data['totalAmount'] ?? 0).toDouble();
                return ListTile(
                  leading: const Icon(Icons.receipt_long, color: Colors.deepOrange),
                  title: Text('Mã đơn: #${doc.id.substring(0, 5)}'),
                  subtitle: Text('Tổng tiền: ${total.toStringAsFixed(0)} VNĐ'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => OrderDetailScreen(orderId: doc.id, tableName: tableName),
                      ),
                    );
                  },
                );
              }).toList(),
              const Divider(),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => CreateOrderScreen(tableName: tableName)),
                  );
                },
                icon: const Icon(Icons.add),
                label: Text('TẠO THÊM ĐƠN MỚI CHO $tableName'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<String> tables = List.generate(12, (index) => 'Bàn ${index + 1}');

    return Scaffold(
      appBar: AppBar(title: const Text('Sơ Đồ Bàn Ăn'), centerTitle: true),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('orders').where('status', isEqualTo: 'pending').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          Map<String, List<QueryDocumentSnapshot>> tableOrdersMap = {};
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            String tName = data['tableName'] ?? '';
            if (tName.isNotEmpty) {
              tableOrdersMap.putIfAbsent(tName, () => []).add(doc);
            }
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 12, mainAxisSpacing: 12),
            itemCount: tables.length,
            itemBuilder: (context, index) {
              final tableName = tables[index];
              final orders = tableOrdersMap[tableName] ?? [];
              final isOccupied = orders.isNotEmpty;

              return InkWell(
                onTap: () {
                  if (isOccupied) {
                    _showOrderSelectionDialog(context, tableName, orders);
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => CreateOrderScreen(tableName: tableName)),
                    );
                  }
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: isOccupied ? Colors.red.shade100 : Colors.green.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isOccupied ? Colors.red : Colors.green, width: 2),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(isOccupied ? Icons.table_restaurant : Icons.event_seat, color: isOccupied ? Colors.red : Colors.green, size: 32),
                      const SizedBox(height: 4),
                      Text(tableName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                        isOccupied ? '${orders.length} Đơn đang ăn' : 'Trống',
                        style: TextStyle(fontSize: 11, color: isOccupied ? Colors.red.shade900 : Colors.green.shade900),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
