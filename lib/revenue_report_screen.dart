import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RevenueReportScreen extends StatelessWidget {
  const RevenueReportScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Doanh Thu & Lợi Nhuận'), centerTitle: true),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('orders').where('status', isEqualTo: 'completed').snapshots(),
        builder: (context, orderSnap) {
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('expenses').snapshots(),
            builder: (context, expenseSnap) {
              if (!orderSnap.hasData || !expenseSnap.hasData) return const Center(child: CircularProgressIndicator());

              double totalRevenue = 0;
              for (var doc in orderSnap.data!.docs) {
                totalRevenue += (doc['totalAmount'] ?? 0).toDouble();
              }

              double totalExpense = 0;
              for (var doc in expenseSnap.data!.docs) {
                totalExpense += (doc['amount'] ?? 0).toDouble();
              }

              double profit = totalRevenue - totalExpense;

              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Card(
                      color: Colors.blue.shade50,
                      child: ListTile(
                        title: const Text('TỔNG DOANH THU'),
                        trailing: Text('${totalRevenue.toStringAsFixed(0)} VNĐ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue)),
                      ),
                    ),
                    Card(
                      color: Colors.red.shade50,
                      child: ListTile(
                        title: const Text('TỔNG CHI PHÍ NVL'),
                        trailing: Text('-${totalExpense.toStringAsFixed(0)} VNĐ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.red)),
                      ),
                    ),
                    const Divider(),
                    Card(
                      color: profit >= 0 ? Colors.green.shade100 : Colors.orange.shade100,
                      child: ListTile(
                        title: const Text('LỢI NHUẬN THỰC TẾ', style: TextStyle(fontWeight: FontWeight.bold)),
                        trailing: Text('${profit.toStringAsFixed(0)} VNĐ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: profit >= 0 ? Colors.green.shade900 : Colors.red)),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

