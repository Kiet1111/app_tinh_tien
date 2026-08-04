import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ExpenseScreen extends StatefulWidget {
  const ExpenseScreen({Key? key}) : super(key: key);

  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();

  Future<void> _addExpense() async {
    final title = _titleController.text.trim();
    final amountText = _amountController.text.trim();

    if (title.isEmpty || amountText.isEmpty) return;

    await FirebaseFirestore.instance.collection('expenses').add({
      'title': title,
      'amount': double.parse(amountText),
      'createdAt': FieldValue.serverTimestamp(),
      'dateString': DateTime.now().toIso8601String().substring(0, 10), // YYYY-MM-DD
    });

    _titleController.clear();
    _amountController.clear();
    if (mounted) Navigator.pop(context);
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ghi Chép Chi Phí Mua NVL'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _titleController, decoration: const InputDecoration(labelText: 'Tên khoản chi (vd: Mua rau, thịt)')),
            TextField(controller: _amountController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Số tiền (VNĐ)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(onPressed: _addExpense, child: const Text('Lưu Khoản Chi')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sổ Ghi Chép Chi Phí'), centerTitle: true),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        backgroundColor: Colors.redAccent,
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('expenses').orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final title = data['title'] ?? '';
              final amount = (data['amount'] ?? 0).toDouble();
              final dateStr = data['dateString'] ?? '';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: const CircleAvatar(backgroundColor: Colors.redAccent, child: Icon(Icons.remove, color: Colors.white)),
                  title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Ngày chi: $dateStr'),
                  trailing: Text('-${amount.toStringAsFixed(0)} VNĐ', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
