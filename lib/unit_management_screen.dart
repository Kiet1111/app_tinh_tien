import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UnitManagementScreen extends StatelessWidget {
  const UnitManagementScreen({Key? key}) : super(key: key);

  void _addOrEditUnit(BuildContext context, {String? id, String? currentName}) {
    final controller = TextEditingController(text: currentName ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(id == null ? 'Thêm Đơn Vị Tính' : 'Sửa Đơn Vị Tính'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Tên đơn vị (vd: chai, ly, kg, tô)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () async {
              final text = controller.text.trim();
              if (text.isEmpty) return;
              Navigator.pop(ctx);
              if (id == null) {
                await FirebaseFirestore.instance.collection('units').add({'name': text});
              } else {
                await FirebaseFirestore.instance.collection('units').doc(id).update({'name': text});
              }
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quản Lý Đơn Vị Tính'), centerTitle: true),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addOrEditUnit(context),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('units').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(child: Text('Chưa có đơn vị tính nào. Hãy bấm + để thêm!'));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final name = doc['name'] ?? '';
              return ListTile(
                leading: const Icon(Icons.square_foot),
                title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _addOrEditUnit(context, id: doc.id, currentName: name),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => FirebaseFirestore.instance.collection('units').doc(doc.id).delete(),
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
