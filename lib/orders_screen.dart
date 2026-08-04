import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'create_order_screen.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({Key? key}) : super(key: key);

  // Ghi nhật ký thao tác
  Future<void> _logAction(String action) async {
    await FirebaseFirestore.instance.collection('logs').add({
      'action': action,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Hủy đơn hàng
  void _cancelOrder(BuildContext context, String orderId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận Hủy Đơn'),
        content: const Text('Khách không mua nữa? Bạn có chắc muốn hủy đơn này?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Không')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await FirebaseFirestore.instance.collection('orders').doc(orderId).update({'status': 'cancelled'});
              await _logAction('Hủy đơn hàng #${orderId.substring(0, 5)}');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hủy Đơn', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Thanh toán hoàn tất đơn
  void _completeOrder(BuildContext context, String orderId, double total) async {
    await FirebaseFirestore.instance.collection('orders').doc(orderId).update({'status': 'completed'});
    await _logAction('Thanh toán đơn hàng #${orderId.substring(0, 5)} - Số tiền: ${total.toStringAsFixed(0)} VNĐ');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã thanh toán đơn hàng thành công!')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Danh Sách Đơn Hàng Đang Phục Vụ'), centerTitle: true),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateOrderScreen()));
        },
        icon: const Icon(Icons.add),
        label: const Text('Tạo Đơn Mới'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('orders').where('status', isEqualTo: 'pending').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(child: Text('Hiện không có đơn hàng nào đang chờ thanh toán.'));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final total = (data['totalAmount'] ?? 0).toDouble();
              final items = List.from(data['items'] ?? []);

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ExpansionTile(
                  leading: const CircleAvatar(child: Icon(Icons.receipt)),
                  title: Text('Đơn Hàng #${doc.id.substring(0, 5)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Tổng: ${total.toStringAsFixed(0)} VNĐ (${items.length} món)'),
                  children: [
                    ...items.map((i) => ListTile(
                          dense: true,
                          title: Text('${i['name']} x${i['quantity']}'),
                          trailing: Text('${(i['totalPrice'] ?? 0).toStringAsFixed(0)} VNĐ'),
                        )),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _cancelOrder(context, doc.id),
                            icon: const Icon(Icons.cancel, color: Colors.red),
                            label: const Text('Hủy Đơn', style: TextStyle(color: Colors.red)),
                          ),
                          ElevatedButton.icon(
                            onPressed: () => _completeOrder(context, doc.id, total),
                            icon: const Icon(Icons.check),
                            label: const Text('Thanh Toán'),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                          ),
                        ],
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
