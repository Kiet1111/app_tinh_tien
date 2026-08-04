import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OrderDetailScreen extends StatefulWidget {
  final String orderId;
  final String tableName;

  const OrderDetailScreen({
    Key? key,
    required this.orderId,
    required this.tableName,
  }) : super(key: key);

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  bool _isLoading = false;

  // 1. THANH TOÁN & TRẢ BÀN
  Future<void> _checkout() async {
    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .update({'status': 'completed', 'completedAt': FieldValue.serverTimestamp()});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã thanh toán & trả ${widget.tableName}!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 2. GỘP BÀN
  Future<void> _mergeTable(List<dynamic> currentItems, double currentTotal) async {
    String? targetTable;
    final tables = List.generate(12, (i) => 'Bàn ${i + 1}')..remove(widget.tableName);

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Gộp ${widget.tableName} sang bàn khác'),
        content: DropdownButtonFormField<String>(
          hint: const Text('Chọn bàn đích'),
          items: tables.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
          onChanged: (val) => targetTable = val,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Xác nhận gộp'),
          ),
        ],
      ),
    );

    if (targetTable == null) return;

    setState(() => _isLoading = true);
    try {
      // Tìm đơn hàng của bàn đích (nếu có)
      final targetQuery = await FirebaseFirestore.instance
          .collection('orders')
          .where('tableName', isEqualTo: targetTable)
          .where('status', isEqualTo: 'pending')
          .get();

      if (targetQuery.docs.isNotEmpty) {
        // Bàn đích đang có khách -> Nối thêm món vào đơn đó
        final targetDoc = targetQuery.docs.first;
        List<dynamic> targetItems = List.from(targetDoc['items']);
        targetItems.addAll(currentItems);
        double newTotal = (targetDoc['totalAmount'] as num).toDouble() + currentTotal;

        await FirebaseFirestore.instance
            .collection('orders')
            .doc(targetDoc.id)
            .update({'items': targetItems, 'totalAmount': newTotal});
      } else {
        // Bàn đích đang trống -> Đổi tên bàn của đơn này sang bàn đích
        await FirebaseFirestore.instance
            .collection('orders')
            .doc(widget.orderId)
            .update({'tableName': targetTable});
      }

      // Xóa/hoàn tất đơn cũ nếu đã chuyển sang bàn đang có khách
      if (targetQuery.docs.isNotEmpty) {
        await FirebaseFirestore.instance.collection('orders').doc(widget.orderId).delete();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã gộp ${widget.tableName} vào $targetTable thành công!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi gộp bàn: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 3. TÁCH ĐƠN / TÁCH MÓN
  Future<void> _splitOrder(List<dynamic> currentItems) async {
    Map<int, int> splitQty = {}; // [chỉ số món] -> số lượng tách

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Chọn món muốn tách đơn'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: currentItems.length,
                  itemBuilder: (context, index) {
                    final item = currentItems[index];
                    final maxQty = item['quantity'] as int;
                    final currentSplit = splitQty[index] ?? 0;

                    return ListTile(
                      title: Text(item['name']),
                      subtitle: Text('Giá: ${item['price']} VNĐ (Hiện có: $maxQty)'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove),
                            onPressed: currentSplit > 0
                                ? () => setDialogState(() => splitQty[index] = currentSplit - 1)
                                : null,
                          ),
                          Text('$currentSplit'),
                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: currentSplit < maxQty
                                ? () => setDialogState(() => splitQty[index] = currentSplit + 1)
                                : null,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Tách đơn mới'),
                ),
              ],
            );
          },
        );
      },
    );

    // Bật chọn bàn mới cho đơn vừa tách
    List<Map<String, dynamic>> newOrderItems = [];
    List<Map<String, dynamic>> remainingItems = [];
    double newTotal = 0;
    double remainingTotal = 0;

    for (int i = 0; i < currentItems.length; i++) {
      final item = Map<String, dynamic>.from(currentItems[i]);
      int splitAmount = splitQty[i] ?? 0;
      int origQty = item['quantity'];
      double price = (item['price'] as num).toDouble();

      if (splitAmount > 0) {
        newOrderItems.add({'name': item['name'], 'price': price, 'quantity': splitAmount});
        newTotal += price * splitAmount;
      }

      if (origQty - splitAmount > 0) {
        remainingItems.add({'name': item['name'], 'price': price, 'quantity': origQty - splitAmount});
        remainingTotal += price * (origQty - splitAmount);
      }
    }

    if (newOrderItems.isEmpty) return;

    // Chọn bàn cho hóa đơn mới tách
    String? newTable;
    final tables = List.generate(12, (i) => 'Bàn ${i + 1}');

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Chuyển đơn tách sang bàn nào?'),
        content: DropdownButtonFormField<String>(
          hint: const Text('Chọn bàn mới'),
          items: tables.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
          onChanged: (val) => newTable = val,
        ),
        actions: [
          ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Xác nhận')),
        ],
      ),
    );

    if (newTable == null) return;

    setState(() => _isLoading = true);
    try {
      // 1. Cập nhật đơn cũ với số món còn lại
      if (remainingItems.isEmpty) {
        await FirebaseFirestore.instance.collection('orders').doc(widget.orderId).delete();
      } else {
        await FirebaseFirestore.instance
            .collection('orders')
            .doc(widget.orderId)
            .update({'items': remainingItems, 'totalAmount': remainingTotal});
      }

      // 2. Tạo đơn mới cho bàn được chọn
      await FirebaseFirestore.instance.collection('orders').add({
        'tableName': newTable,
        'items': newOrderItems,
        'totalAmount': newTotal,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã tách món từ ${widget.tableName} sang $newTable!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi tách đơn: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Hóa Đơn - ${widget.tableName}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.call_merge),
            tooltip: 'Gộp bàn',
            onPressed: () {},
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('orders').doc(widget.orderId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Đơn hàng không tồn tại hoặc đã thanh toán.'));
          }

          final orderData = snapshot.data!.data() as Map<String, dynamic>;
          final items = List<dynamic>.from(orderData['items'] ?? []);
          final totalAmount = (orderData['totalAmount'] ?? 0).toDouble();

          return Column(
            children: [
              // Nút Chức Năng Gộp / Tách Đơn
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _mergeTable(items, totalAmount),
                        icon: const Icon(Icons.merge_type),
                        label: const Text('Gộp Bàn'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _splitOrder(items),
                        icon: const Icon(Icons.call_split),
                        label: const Text('Tách Đơn'),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(),
              // Danh sách món ăn
              Expanded(
                child: ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return ListTile(
                      title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Đơn giá: ${item['price']} VNĐ'),
                      trailing: Text('x${item['quantity']}', style: const TextStyle(fontSize: 16)),
                    );
                  },
                ),
              ),
              // Khối Tổng Tiền & Nút Thanh Toán
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('TỔNG CỘNG:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text(
                          '${totalAmount.toStringAsFixed(0)} VNĐ',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _checkout,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('THANH TOÁN & TRẢ BÀN',
                                style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
