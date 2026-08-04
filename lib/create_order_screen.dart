import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CreateOrderScreen extends StatefulWidget {
  const CreateOrderScreen({Key? key}) : super(key: key);

  @override
  State<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends State<CreateOrderScreen> {
  final List<Map<String, dynamic>> _selectedItems = [];
  String _selectedCategory = 'Tất cả';

  void _showAddOptionDialog(Map<String, dynamic> menuItem) {
    final List addOns = menuItem['addOns'] ?? [];
    final String unit = (menuItem['unit'] ?? 'Phần').toString().toLowerCase();
    final bool isWeightUnit = (unit == 'kg' || unit == 'g');

    final quantityController = TextEditingController(text: '1');
    String weightUnitType = (unit == 'g') ? 'g' : 'kg';
    List<Map<String, dynamic>> selectedAddOns = [];

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            double calculateTotal() {
              double inputVal = double.tryParse(quantityController.text.trim()) ?? 0.0;
              double basePrice = (menuItem['price'] ?? 0).toDouble();

              double itemTotal = 0;
              if (isWeightUnit) {
                double weightInKg = (weightUnitType == 'g') ? (inputVal / 1000.0) : inputVal;
                itemTotal = basePrice * weightInKg;
              } else {
                itemTotal = basePrice * inputVal;
              }

              for (var addon in selectedAddOns) {
                itemTotal += (addon['price'] ?? 0).toDouble();
              }
              return itemTotal;
            }

            double calculateTotalCost() {
              double inputVal = double.tryParse(quantityController.text.trim()) ?? 0.0;
              double baseCost = (menuItem['costPrice'] ?? 0).toDouble();
              if (isWeightUnit) {
                double weightInKg = (weightUnitType == 'g') ? (inputVal / 1000.0) : inputVal;
                return baseCost * weightInKg;
              }
              return baseCost * inputVal;
            }

            return AlertDialog(
              title: Text('Chọn: ${menuItem['name']}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Đơn giá: ${menuItem['price']} VNĐ / ${menuItem['unit']}', style: const TextStyle(color: Colors.grey)),
                    const SizedBox(height: 12),
                    if (isWeightUnit) ...[
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: quantityController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(labelText: 'Số lượng ($weightUnitType)', border: const OutlineInputBorder()),
                              onChanged: (_) => setDlgState(() {}),
                            ),
                          ),
                          const SizedBox(width: 8),
                          DropdownButton<String>(
                            value: weightUnitType,
                            items: const [DropdownMenuItem(value: 'kg', child: Text('kg')), DropdownMenuItem(value: 'g', child: Text('g'))],
                            onChanged: (val) { if (val != null) setDlgState(() => weightUnitType = val); },
                          ),
                        ],
                      ),
                    ] else ...[
                      Row(
                        children: [
                          const Text('Số lượng:', style: TextStyle(fontWeight: FontWeight.bold)),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(left: 16.0),
                              child: TextField(
                                controller: quantityController,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                                onChanged: (_) => setDlgState(() {}),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const Divider(height: 24),
                    if (addOns.isNotEmpty) ...[
                      const Text('Topping / Đồ ăn thêm:', style: TextStyle(fontWeight: FontWeight.bold)),
                      ...addOns.map((a) {
                        final isChecked = selectedAddOns.contains(a);
                        return CheckboxListTile(
                          title: Text('${a['name']} (+${a['price']} VNĐ)'),
                          value: isChecked,
                          onChanged: (val) {
                            setDlgState(() {
                              if (val == true) selectedAddOns.add(a);
                              else selectedAddOns.remove(a);
                            });
                          },
                        );
                      }),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
                ElevatedButton(
                  onPressed: () {
                    double inputVal = double.tryParse(quantityController.text.trim()) ?? 0.0;
                    if (inputVal <= 0) return;

                    final quantityDisplay = isWeightUnit ? '$inputVal $weightUnitType' : '${inputVal.toInt()} ${menuItem['unit']}';

                    setState(() {
                      _selectedItems.add({
                        'name': menuItem['name'],
                        'quantityDisplay': quantityDisplay,
                        'addOns': selectedAddOns.map((a) => a['name']).toList(),
                        'totalPrice': calculateTotal(),
                        'totalCost': calculateTotalCost(), // Lưu tổng giá vốn để tính lợi nhuận
                      });
                    });
                    Navigator.pop(ctx);
                  },
                  child: Text('Thêm (${calculateTotal().toStringAsFixed(0)} VNĐ)'),
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
    double grandCost = 0;
    for (var item in _selectedItems) {
      grandTotal += (item['totalPrice'] ?? 0).toDouble();
      grandCost += (item['totalCost'] ?? 0).toDouble();
    }

    final orderData = {
      'items': _selectedItems,
      'totalAmount': grandTotal,
      'totalCostAmount': grandCost, // Tổng giá vốn của đơn hàng
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
      appBar: AppBar(title: const Text('Tạo Đơn Hàng Mới')),
      body: Column(
        children: [
          // DANH MỤC LỌC
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('categories').snapshots(),
            builder: (context, snapshot) {
              List<String> categories = ['Tất cả', 'Món chính', 'Đồ uống', 'Ăn vặt', 'Topping', 'Tráng miệng', 'Khác'];
              if (snapshot.hasData) {
                for (var d in snapshot.data!.docs) { categories.add(d['name']); }
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

          // DANH SÁCH MÓN ĂN (ĐÃ LỌC BỎ CÁC MÓN BỊ ẨN)
          Expanded(
            flex: 3,
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('menu_items').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                var docs = snapshot.data!.docs;

                // LỌC 1: BỎ CÁC MÓN BỊ ẨN (isAvailable == false)
                docs = docs.where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  return data['isAvailable'] ?? true;
                }).toList();

                // LỌC 2: THEO DANH MỤC
                if (_selectedCategory != 'Tất cả') {
                  docs = docs.where((d) => (d.data() as Map<String, dynamic>)['category'] == _selectedCategory).toList();
                }

                if (docs.isEmpty) return const Center(child: Text('Không có món ăn khả dụng.'));

                return GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 2.1, crossAxisSpacing: 8, mainAxisSpacing: 8),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final item = docs[index].data() as Map<String, dynamic>;
                    return InkWell(
                      onTap: () => _showAddOptionDialog(item),
                      child: Card(
                        color: Colors.orange.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(6.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(item['name'] ?? '', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1),
                              Text('${item['price']} VNĐ / ${item['unit'] ?? 'Phần'}', style: const TextStyle(color: Colors.deepOrange, fontSize: 12)),
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

          // DANH SÁCH ĐÃ CHỌN
          Expanded(
            flex: 2,
            child: ListView.builder(
              itemCount: _selectedItems.length,
              itemBuilder: (context, index) {
                final item = _selectedItems[index];
                return ListTile(
                  dense: true,
                  title: Text(item['name']),
                  subtitle: Text('SL: ${item['quantityDisplay']}'),
                  trailing: Text('${(item['totalPrice'] ?? 0).toStringAsFixed(0)} VNĐ', style: const TextStyle(fontWeight: FontWeight.bold)),
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
            child: const Text('HOÀN TẤT TẠO ĐƠN HÀNG', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
