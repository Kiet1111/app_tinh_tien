import 'package:flutter/material.dart';
import 'services/api_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Tính Tiền Quán Ăn',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final String adminPinCode = "1234";
  bool isAdminMode = false;

  List<Map<String, dynamic>> menuList = [
    {'name': 'Cháo lòng', 'price': 25000.0},
    {'name': 'Cháo gà', 'price': 25000.0},
    {'name': 'Hủ tiếu', 'price': 30000.0},
    {'name': 'Cà phê sữa', 'price': 15000.0},
  ];

  List<Map<String, dynamic>> currentOrder = [];

  double get totalAmount => currentOrder.fold(
      0, (sum, item) => sum + (item['price'] * item['qty']));

  void _showAddDishDialog(String name, double defaultPrice) {
    final priceController =
        TextEditingController(text: defaultPrice.toStringAsFixed(0));
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Món: $name'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Giá tiền tùy chỉnh (VNĐ)',
                suffixText: 'đ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(
                labelText: 'Ghi chú (Ví dụ: Tô lớn, không hành...)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () {
              double customPrice =
                  double.tryParse(priceController.text) ?? defaultPrice;
              setState(() {
                currentOrder.add({
                  'name': name,
                  'price': customPrice,
                  'qty': 1,
                  'note': noteController.text,
                });
              });
              Navigator.pop(ctx);
            },
            child: const Text('Thêm vào đơn'),
          ),
        ],
      ),
    );
  }

  void _showAdminAuthDialog() {
    final pinController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác thực quyền hạn'),
        content: TextField(
          controller: pinController,
          obscureText: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Mã PIN bảo mật (Mặc định: 1234)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () {
              if (pinController.text == adminPinCode) {
                setState(() => isAdminMode = true);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Mở khóa thành công!')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Mã PIN không đúng!'),
                      backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('Mở khóa'),
          ),
        ],
      ),
    );
  }

  void _submitOrder() async {
    if (currentOrder.isEmpty) return;

    final orderData = {
      'timestamp': DateTime.now().toIso8601String(),
      'total': totalAmount,
      'items': currentOrder,
    };

    bool isSaved = await ApiService.saveOrder(orderData);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isSaved
              ? 'Lưu đơn lên Server thành công!'
              : 'Lỗi gửi Server (Kiểm tra lại kết nối)'),
          backgroundColor: isSaved ? Colors.green : Colors.red,
        ),
      );
      if (isSaved) setState(() => currentOrder.clear());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.menu_book, color: Colors.teal),
            SizedBox(width: 8),
            Text('Tính Tiền - Quán Ăn'),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(isAdminMode ? Icons.lock_open : Icons.lock,
                color: isAdminMode ? Colors.green : Colors.grey),
            onPressed: _showAdminAuthDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 1,
            child: GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.6,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: menuList.length,
              itemBuilder: (ctx, index) {
                final dish = menuList[index];
                return Card(
                  color: Colors.teal.shade50,
                  child: InkWell(
                    onTap: () =>
                        _showAddDishDialog(dish['name'], dish['price']),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(dish['name'],
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          Text('${dish['price'].toStringAsFixed(0)}đ',
                              style: const TextStyle(color: Colors.teal)),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Chi tiết đơn',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      Text('Tổng: ${totalAmount.toStringAsFixed(0)}đ',
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal)),
                    ],
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: currentOrder.length,
                      itemBuilder: (ctx, index) {
                        final item = currentOrder[index];
                        return ListTile(
                          dense: true,
                          title: Text(
                              '${item['name']} - ${item['price'].toStringAsFixed(0)}đ'),
                          subtitle: item['note'].toString().isNotEmpty
                              ? Text(item['note'])
                              : null,
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () =>
                                setState(() => currentOrder.removeAt(index)),
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _submitOrder,
                      icon: const Icon(Icons.cloud_upload),
                      label: const Text('TẠO ĐƠN & LƯU SERVER'),
                    ),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

