import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CreateOrderScreen extends StatefulWidget {
  final String? existingOrderId; // Nếu null là tạo đơn mới

  const CreateOrderScreen({Key? key, this.existingOrderId}) : super(key: key);

  @override
  State<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends State<CreateOrderScreen> {
  final List<Map<String, dynamic>> _selectedItems = [];

  // Dialog chọn biến thể & đồ ăn thêm cho món được bấm
  void _showAddOptionDialog(Map<String, dynamic> menuItem) {
    final List variants = menuItem['variants'] ?? [];
    final List addOns = menuItem['addOns'] ?? [];

    Map<String, dynamic>? selectedVariant = variants.isNotEmpty ? variants.first : null;
    List<Map<String, dynamic>> selectedAddOns = [];
    int quantity = 1;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            double calculateTotalPrice() {
              double base = (menuItem['price'] ?? 0).toDouble();
              if (selectedVariant != null) {
                base += (selectedVariant!['price'] ?? 0).toDouble();
              }
              for (var addon in selectedAddOns) {
                base += (addon['price'] ?? 0).toDouble();
              }
              return base * quantity;
            }

            return AlertDialog(
              title: Text(menuItem['name'] ?? ''),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Biến thể
                    if (variants.isNotEmpty) ...[
                      const Text('Chọn Biến Thể:', style: TextStyle(fontWeight: FontWeight.bold)),
                      ...variants.map((v) => RadioListTile<Map<String, dynamic>>(
                            title: Text('${v['name']} (+${v['price']}k)'),
                            value: v,
                            groupValue: selectedVariant,
                            onChanged: (val) => setDlgState(() => selectedVariant = val),
                          )),
                      const Divider(),
                    ],
                    // Đồ ăn thêm
                    if (addOns.isNotEmpty) ...[
                      const Text('Đồ Ăn Thêm:', style: TextStyle(fontWeight: FontWeight.bold)),
                      ...addOns.map((a) {
                        final isChecked = selectedAddOns.contains(a);
                        return CheckboxListTile(
                          title: Text('${a['name']} (+${a['price']}k)'),
                          value: isChecked,
                          onChanged: (val) {
                            setDlgState(() {
                              if (val == true) {
                                selectedAddOns.add(a);
                              } else {
                                selectedAddOns.remove(a);
                              }
                            });
                          },
                        );
                      }),
                      const Divider(),
                    ],
                    // Số lượng
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Số lượng:'),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: quantity > 1 ? () => setDlgState(() => quantity--) : null,
                            ),
                            Text('$quantity', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: () => setDlgState(() => quantity++),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _selectedItems.add({
                        'name': menuItem['name'],
                        'unit': menuItem['unit'] ?? 'Phần',
                        'variant': selectedVariant != null ? selectedVariant!['name'] : null,
                        'addOns': selectedAddOns.map((a) => a['name']).toList(),
                        'quantity': quantity,
                        'totalPrice': calculateTotalPrice(),
                      });
                    });
                    Navigator.pop(ctx);
                  },
                  child: Text('Thêm (${calculateTotalPrice().toStringAsFixed(0)} VNĐ)'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _submitOrder() async {
    if (_selectedItems.isEmpty) return;

    double grandTotal = 0;
    for (var item in _selectedItems) {
      grandTotal += (item['totalPrice'] ?? 0).toDouble();
    }

    final orderData = {
      'items': _selectedItems,
      'totalAmount': grandTotal,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'dateString': DateTime.now().toIso8601String().substring(0, 10),
    };

    final docRef = await FirebaseFirestore.instance.collection('orders').add(orderData);

    // Ghi nhật ký thao tác
    await FirebaseFirestore.instance.collection('logs').add({
      'action': 'Tạo đơn mới #${docRef.id.substring(0, 5)} - Giá trị: ${grandTotal.toStringAsFixed(0)} VNĐ',
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tạo Đơn Hàng Mới')),
      body: Column(
        children: [
          // Danh sách món chọn
          Expanded(
            flex: 2,
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('menu_items').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final docs = snapshot.data!.docs;

                return GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 2.5, crossAxisSpacing: 8, mainAxisSpacing: 8),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final item = docs[index].data() as Map<String, dynamic>;
                    return InkWell(
                      onTap: () => _showAddOptionDialog(item),
                      child: Card(
                        color: Colors.orange.shade50,
                        child: Center(
                          child: Text(item['name'] ?? '', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const Divider(),
          // Các món đã thêm vào đơn
          Expanded(
            flex: 3,
            child: ListView.builder(
              itemCount: _selectedItems.length,
              itemBuilder: (context, index) {
                final item = _selectedItems[index];
                final variantStr = item['variant'] != null ? ' [${item['variant']}]' : '';
                final addOnsStr = (item['addOns'] as List).isNotEmpty ? ' (+${(item['addOns'] as List).join(', ')})' : '';

                return ListTile(
                  title: Text('${item['name']}$variantStr$addOnsStr'),
                  subtitle: Text('SL: ${item['quantity']} ${item['unit']}'),
                  trailing: Text('${(item['totalPrice'] ?? 0).toStringAsFixed(0)} VNĐ'),
                  leading: IconButton(
                    icon: const Icon(Icons.remove_circle, color: Colors.red),
                    onPressed: () => setState(() => _selectedItems.removeAt(index)),
                  ),
                );
              },
            ),
          ),
          ElevatedButton(
            onPressed: _selectedItems.isEmpty ? null : _submitOrder,
            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50), backgroundColor: Colors.green),
            child: const Text('HOÀN TẤT TẠO ĐƠN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
