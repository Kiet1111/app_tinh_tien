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

  // DIALOG THÊM MÓN VÀO ĐƠN - HỖ TRỢ NHẬP SỐ KG / GRAM CHI TIẾT
  void _showAddOptionDialog(Map<String, dynamic> menuItem) {
    final List addOns = menuItem['addOns'] ?? [];
    final String unit = (menuItem['unit'] ?? 'Phần').toString().toLowerCase();
    final bool isWeightUnit = (unit == 'kg' || unit == 'g');

    // Mặc định trọng lượng/số lượng
    final quantityController = TextEditingController(text: '1');
    String weightUnitType = (unit == 'g') ? 'g' : 'kg'; // Đơn vị nhập 'kg' hoặc 'g'
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
                // Đổi ra kg để tính giá
                double weightInKg = (weightUnitType == 'g') ? (inputVal / 1000.0) : inputVal;
                itemTotal = basePrice * weightInKg;
              } else {
                itemTotal = basePrice * inputVal;
              }

              // Cộng giá Topping
              for (var addon in selectedAddOns) {
                itemTotal += (addon['price'] ?? 0).toDouble();
              }

              return itemTotal;
            }

            return AlertDialog(
              title: Text('Chọn món: ${menuItem['name']}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Đơn giá: ${menuItem['price']} VNĐ / ${menuItem['unit']}', style: const TextStyle(color: Colors.grey)),
                    const SizedBox(height: 12),

                    // NHẬP TRỌNG LƯỢNG KHI MÓN CÓ ĐƠN VỊ KG / G
                    if (isWeightUnit) ...[
                      const Text('Nhập trọng lượng mua:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: quantityController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: 'Số lượng (${weightUnitType})',
                                border: const OutlineInputBorder(),
                                hintText: weightUnitType == 'kg' ? 'VD: 0.5 hoặc 1.2' : 'VD: 250 hoặc 500',
                              ),
                              onChanged: (_) => setDlgState(() {}),
                            ),
                          ),
                          const SizedBox(width: 8),
                          DropdownButton<String>(
                            value: weightUnitType,
                            items: const [
                              DropdownMenuItem(value: 'kg', child: Text('kg')),
                              DropdownMenuItem(value: 'g', child: Text('g (gram)')),
                            ],
                            onChanged: (val) {
                              if (val != null) setDlgState(() => weightUnitType = val);
                            },
                          ),
                        ],
                      ),
                    ] else ...[
                      // NHẬP SỐ LƯỢNG CHO ĐƠN VỊ PHẦN/LY/TÔ...
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                    // CHỌN TOPPING
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

                    final calculatedPrice = calculateTotal();
                    final quantityDisplay = isWeightUnit ? '$inputVal $weightUnitType' : '${inputVal.toInt()} ${menuItem['unit']}';

                    setState(() {
                      _selectedItems.add({
                        'name': menuItem['name'],
                        'quantityDisplay': quantityDisplay,
                        'addOns': selectedAddOns.map((a) => a['name']).toList(),
                        'totalPrice': calculatedPrice,
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

    await FirebaseFirestore.instance.collection('logs').add({
      'action': 'Tạo đơn mới #${docRef.id.substring(0, 5)} - Tổng: ${grandTotal.toStringAsFixed(0)} VNĐ',
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tạo Đơn Hàng Mới')),
      body: Column(
        children: [
          // DANH MỤC LỌC ĐỘNG TỪ FIRESTORE
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
                if (_selectedCategory != 'Tất cả') {
                  docs = docs.where((d) => (d.data() as Map<String, dynamic>)['category'] == _selectedCategory).toList();
                }

                if (docs.isEmpty) return const Center(child: Text('Không tìm thấy món ăn trong danh mục này.'));

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

          // MÓN ĐÃ CHỌN VÀO ĐƠN
          Expanded(
            flex: 2,
            child: ListView.builder(
              itemCount: _selectedItems.length,
              itemBuilder: (context, index) {
                final item = _selectedItems[index];
                final addOnsStr = (item['addOns'] as List).isNotEmpty ? ' (+${(item['addOns'] as List).join(', ')})' : '';

                return ListTile(
                  dense: true,
                  title: Text('${item['name']}$addOnsStr'),
                  subtitle: Text('Trọng lượng / SL: ${item['quantityDisplay']}'),
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
