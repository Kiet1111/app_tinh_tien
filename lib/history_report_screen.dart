import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HistoryReportScreen extends StatelessWidget {
  const HistoryReportScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Thống Kê & Lịch Sử'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.bar_chart), text: 'Doanh Thu'),
              Tab(icon: Icon(Icons.history), text: 'Lịch Sử Đơn'),
              Tab(icon: Icon(Icons.list_alt), text: 'Lật Sổ Thao Tác'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            RevenueTab(),
            OrderHistoryTab(),
            OperationLogsTab(),
          ],
        ),
      ),
    );
  }
}

// 1. Tab Doanh Thu Ngày & Tháng
class RevenueTab extends StatelessWidget {
  const RevenueTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    final monthStr = todayStr.substring(0, 7);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('orders').where('status', isEqualTo: 'completed').snapshots(),
      builder: (context, orderSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('expenses').snapshots(),
          builder: (context, expenseSnap) {
            if (!orderSnap.hasData || !expenseSnap.hasData) return const Center(child: CircularProgressIndicator());

            double todayRevenue = 0;
            double monthRevenue = 0;

            for (var doc in orderSnap.data!.docs) {
              final data = doc.data() as Map<String, dynamic>;
              final amt = (data['totalAmount'] ?? 0).toDouble();
              final date = data['dateString'] ?? '';

              if (date == todayStr) todayRevenue += amt;
              if (date.startsWith(monthStr)) monthRevenue += amt;
            }

            double monthExpense = 0;
            for (var doc in expenseSnap.data!.docs) {
              final data = doc.data() as Map<String, dynamic>;
              final amt = (data['amount'] ?? 0).toDouble();
              final date = data['dateString'] ?? '';
              if (date.startsWith(monthStr)) monthExpense += amt;
            }

            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Card(
                    color: Colors.green.shade50,
                    child: ListTile(
                      title: const Text('DOANH THU HÔM NAY'),
                      trailing: Text('${todayRevenue.toStringAsFixed(0)} VNĐ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green)),
                    ),
                  ),
                  Card(
                    color: Colors.blue.shade50,
                    child: ListTile(
                      title: const Text('DOANH THU THÁNG NÀY'),
                      trailing: Text('${monthRevenue.toStringAsFixed(0)} VNĐ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue)),
                    ),
                  ),
                  Card(
                    color: Colors.red.shade50,
                    child: ListTile(
                      title: const Text('CHI PHÍ NVL THÁNG NÀY'),
                      trailing: Text('-${monthExpense.toStringAsFixed(0)} VNĐ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.red)),
                    ),
                  ),
                  const Divider(),
                  Card(
                    color: Colors.amber.shade100,
                    child: ListTile(
                      title: const Text('LỢI NHUẬN THÁNG NÀY', style: TextStyle(fontWeight: FontWeight.bold)),
                      trailing: Text('${(monthRevenue - monthExpense).toStringAsFixed(0)} VNĐ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.purple)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// 2. Tab Lịch Sử Đơn Hàng
class OrderHistoryTab extends StatelessWidget {
  const OrderHistoryTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('orders').orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final status = data['status'] ?? 'pending';
            final total = (data['totalAmount'] ?? 0).toDouble();

            Color statusColor = Colors.orange;
            String statusText = 'Đang chờ';
            if (status == 'completed') {
              statusColor = Colors.green;
              statusText = 'Đã thanh toán';
            } else if (status == 'cancelled') {
              statusColor = Colors.red;
              statusText = 'Đã hủy';
            }

            return ListTile(
              leading: Icon(Icons.receipt, color: statusColor),
              title: Text('Mã đơn: #${docs[index].id.substring(0, 5)} - $statusText'),
              subtitle: Text('Ngày: ${data['dateString'] ?? ''}'),
              trailing: Text('${total.toStringAsFixed(0)} VNĐ', style: TextStyle(color: statusColor, fontWeight: FontWeight.bold)),
            );
          },
        );
      },
    );
  }
}

// 3. Tab Lịch Sử Thao Tác (Ghi sổ Log)
class OperationLogsTab extends StatelessWidget {
  const OperationLogsTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('logs').orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final action = data['action'] ?? '';

            return ListTile(
              dense: true,
              leading: const Icon(Icons.history_toggle_off, size: 20),
              title: Text(action),
            );
          },
        );
      },
    );
  }
}
