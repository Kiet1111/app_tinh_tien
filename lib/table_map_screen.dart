import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'create_order_screen.dart';

class TableMapScreen extends StatelessWidget {
  const TableMapScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Tạo danh sách 12 bàn mẫu
    final List<String> tables = List.generate(12, (index) => 'Bàn ${index + 1}');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sơ Đồ Bàn Ăn'),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Lắng nghe các hóa đơn đang phục vụ (chưa thanh toán)
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('status', isEqualTo: 'pending')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          Set<String> occupiedTables = {};
          if (snapshot.hasData) {
            for (var doc in snapshot.data!.docs) {
              final data = doc.data() as Map<String, dynamic>;
              if (data['tableName'] != null) {
                occupiedTables.add(data['tableName']);
              }
            }
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.0,
            ),
            itemCount: tables.length,
            itemBuilder: (context, index) {
              final tableName = tables[index];
              final isOccupied = occupiedTables.contains(tableName);

              return InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CreateOrderScreen(tableName: tableName),
                    ),
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: isOccupied ? Colors.red.shade100 : Colors.green.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isOccupied ? Colors.red : Colors.green,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isOccupied ? Icons.table_restaurant : Icons.event_seat,
                        size: 36,
                        color: isOccupied ? Colors.red : Colors.green,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        tableName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isOccupied ? Colors.red.shade900 : Colors.green.shade900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isOccupied ? 'Có khách' : 'Trống',
                        style: TextStyle(
                          fontSize: 12,
                          color: isOccupied ? Colors.red.shade700 : Colors.green.shade700,
                        ),
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

