import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CreateOrderScreen extends StatefulWidget {
  final String tableName;
  const CreateOrderScreen({Key? key, required this.tableName}) : super(key: key);

  @override
  State<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends State<CreateOrderScreen> {
  final Map<String, Map<String, dynamic>> _cart = {};
  bool _isSaving = false;

  double get _totalPrice {
    double total = 0;
    _cart.forEach((key, item) {
      total += (item['price'] as double) * (item['quantity'] as int);
    });
    return total;
  }

  void _addItem(String id, String name, double price) {
    setState(() {
      if (_cart.containsKey(id)) {
        _cart[id]!['quantity'] += 1;
      } else {
        _cart[id] = {
          'name': name,
          'price': price,
          'quantity': 1,
        };
      }
    });
  }

  void _removeItem(String id) {
    setState(() {
      if (_cart.containsKey(id)) {
        if (_cart[id]!['quantity'] > 1) {
          _cart[id]!['quantity'] -= 1;
        } else {
          _cart.remove(id);
        }
      }
    });
  }

  Future<void> _saveOrder() async {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn ít nhất 1 món ăn!')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      List<Map<String, dynamic>> itemList = _cart.values.toList();

      await FirebaseFirestore.instance.collection('orders').add({
        'tableName': widget.tableName,
        'items': itemList,
        'totalAmount': _totalPrice,
        'status': 'pending', // pending = đang phục vụ (chưa thanh toán)
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã tạo hóa đơn cho ${widget.tableName}!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Tạo Hóa Đơn - ${widget.tableName}'),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('menu_items').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('Chưa có món ăn nào trong thực đơn.'));
                }

                final items = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final doc = items[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final id = doc.id;
                    final name = data['name'] ?? '';
                    final price = (data['price'] ?? 0).toDouble();
                    final imageUrl = data['imageUrl'] ?? '';

                    final qty = _cart[id]?['quantity'] ?? 0;

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      child: ListTile(
                        leading: imageUrl.isNotEmpty
                            ? Image.network(imageUrl, width: 50, height: 50, fit: BoxFit.cover)
                            : const Icon(Icons.fastfood, size: 40),
                        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${price.toStringAsFixed(0)} VNĐ'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (qty > 0) ...[
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                                onPressed: () => _removeItem(id),
                              ),
                              Text('$qty', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ],
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                              onPressed: () => _addItem(id, name, price),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: Colors.black12, blurRadius: 4, spreadRadius: 2),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Tổng tiền:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(
                      '${_totalPrice.toStringAsFixed(0)} VNĐ',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepOrange),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveOrder,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepOrange,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: _isSaving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('TẠO HÓA ĐƠN', style: TextStyle(fontSize: 16, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

