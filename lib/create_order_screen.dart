import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'topping_variant_dialog.dart';

class CreateOrderScreen extends StatefulWidget {
  const CreateOrderScreen({Key? key}) : super(key: key);

  @override
  State<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends State<CreateOrderScreen> {
  final List<Map<String, dynamic>> _selectedItems = [];
  String _selectedCategory = 'Tất cả';

  double _getGrandTotal() {
    double total = 0;
    for (var item in _selectedItems) {
      total += (item['totalPrice'] ?? 0).toDouble();
    }
    return total;
  }

  Future<void> _submitOrder() async {
    if (_selectedItems.isEmpty) return;

    final orderData = {
      'items': _selectedItems,
      'totalAmount': _getGrandTotal(),
      'status': 'completed',
      'createdAt': FieldValue.serverTimestamp(),
      'dateString': DateTime.now().toIso8601String().substring(0, 10),
    };

    await FirebaseFirestore.instance.collection('orders').add(orderData);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tạo Đơn Hàng Mới'), centerTitle: true),
      body: Column(
        children: [
          // BỘ LỌC DANH MỤC
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('categories').snapshots(),
            builder: (context, snapshot) {
              List<String> categories = ['Tất cả', 'Món chính', 'Đồ uống', 'Ăn vặt', 'Topping', 'Tráng miệng', 'Khác'];
              if (snapshot.hasData) {
                for (var d in snapshot.data!.docs) {
                  categories.add(d['name']);
                }
              }
              categories = categories.toSet().toList();

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(6),
                child: Row(
                  children: categories.map((cat) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 6.0),
                      child: FilterChip(
                        label: Text(cat),
                        selected: _selectedCategory == cat,
                        onSelected: (selected) => setState(() => _selectedCategory = cat),
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          ),

          // DANH SÁCH MÓN ĂN
          Expanded(
            flex: 3,
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('menu_items').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                var docs = snapshot.data!.docs;
                docs = docs.where((d) => (d.data() as Map<String, dynamic>)['isAvailable'] ?? true).toList();

                if (_selectedCategory != 'Tất cả') {
                  docs = docs.where((d) => (d.data() as Map<String, dynamic>)['category'] == _selectedCategory).toList();
                }

                if (docs.isEmpty) return const Center(child: Text('Không có món ăn khả dụng.'));

                return GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 2.1,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final item = docs[index].data() as Map<String, dynamic>;
                    return InkWell(
                      onTap: () {
                        // HIỂN THỊ DIALOG CHỌN TOPPING & BIẾN THỂ
                        showDialog(
                          context: context,
                          builder: (ctx) => SelectToppingVariantDialog(
                            menuItem: item,
                            onConfirm: (selectedOrderData) {
                              setState(() => _selectedItems.add(selectedOrderData));
                            },
                          ),
                        );
                      },
                      child: Card(
                        color: Colors.orange.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(6.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(item['name'] ?? '', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1),
                              Text('${formatMoney(item['price'] ?? 0)} VNĐ / ${item['unit'] ?? 'Phần'}', style: const TextStyle(color: Colors.deepOrange, fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const Divider(),

          // DANH SÁCH CÁC MÓN ĐÃ CHỌN TRONG ĐƠN
          Expanded(
            flex: 2,
            child: ListView.builder(
              itemCount: _selectedItems.length,
              itemBuilder: (context, index) {
                final item = _selectedItems[index];
                final List addOns = item['addOns'] ?? [];

                return ListTile(
                  dense: true,
                  title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('SL: ${item['quantityDisplay']}${addOns.isNotEmpty ? '\nTopping: ${addOns.join(', ')}' : ''}'),
                  trailing: Text('${formatMoney(item['totalPrice'] ?? 0)} VNĐ', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                  leading: IconButton(
                    icon: const Icon(Icons.remove_circle, color: Colors.red),
                    onPressed: () => setState(() => _selectedItems.removeAt(index)),
                  ),
                );
              },
            ),
          ),

          // NÚT HOÀN TẤT ĐƠN HÀNG
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton(
              onPressed: _selectedItems.isEmpty ? null : _submitOrder,
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50), backgroundColor: Colors.green),
              child: Text(
                'HOÀN TẤT ĐƠN HÀNG (${formatMoney(_getGrandTotal())} VNĐ)',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
