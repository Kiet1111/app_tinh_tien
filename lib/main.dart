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
      home: const MainTabScreen(),
    );
  }
}

class MainTabScreen extends StatefulWidget {
  const MainTabScreen({super.key});

  @override
  State<MainTabScreen> createState() => _MainTabScreenState();
}

class _MainTabScreenState extends State<MainTabScreen> {
  int _currentIndex = 0;
  final List<Widget> _screens = [
    const HomeScreen(),
    const ReportsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.point_of_sale),
            label: 'Tính Tiền',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart),
            label: 'Báo Cáo',
          ),
        ],
      ),
    );
  }
}

// ------------------- MÀN HÌNH TÍNH TIỀN & MENU -------------------
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final String adminPinCode = "1234";
  bool isAdminMode = false;
  bool isLoadingMenu = true;

  List<Map<String, dynamic>> menuList = [];
  List<Map<String, dynamic>> currentOrder = [];

  @override
  void initState() {
    super.initState();
    _loadMenuFromServer();
  }

  Future<void> _loadMenuFromServer() async {
    setState(() => isLoadingMenu = true);
    final data = await ApiService.fetchMenu();
    setState(() {
      if (data.isNotEmpty) {
        menuList = List<Map<String, dynamic>>.from(data);
      } else {
        menuList = [
          {'id': '1', 'name': 'Cháo lòng', 'price': 25000.0},
          {'id': '2', 'name': 'Cháo gà', 'price': 25000.0},
          {'id': '3', 'name': 'Hủ tiếu', 'price': 30000.0},
          {'id': '4', 'name': 'Cà phê sữa', 'price': 15000.0},
        ];
      }
      isLoadingMenu = false;
    });
  }

  double get totalAmount => currentOrder.fold(
      0, (sum, item) => sum + (item['price'] * item['qty']));

  void _showAddMenuItemDialog() {
    final nameController = TextEditingController();
    final priceController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thêm món mới vào Menu'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Tên món ăn / đồ uống',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Giá bán (VNĐ)',
                suffixText: 'đ',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () async {
              String name = nameController.text.trim();
              double price = double.tryParse(priceController.text) ?? 0;
              if (name.isNotEmpty && price > 0) {
                Navigator.pop(ctx);
                bool success = await ApiService.addMenuItem(name, price);
                if (success) _loadMenuFromServer();
              }
            },
            child: const Text('Lưu vào Server'),
          ),
        ],
      ),
    );
  }

  void _showAddDishDialog(String name, double defaultPrice) {
    final priceController =
        TextEditingController(text: defaultPrice.toStringAsFixed(0));
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Thêm món: $name'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Giá bán tùy chỉnh (VNĐ)',
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
        title: const Text('Xác thực quyền Admin'),
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
                setState(() => isAdminMode = !isAdminMode);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isAdminMode
                        ? 'Đã bật chế độ Admin (Chỉnh sửa Menu)'
                        : 'Đã tắt chế độ Admin'),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Mã PIN không đúng!'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: Text(isAdminMode ? 'Tắt Admin' : 'Mở khóa'),
          ),
        ],
      ),
    );
  }

  void _showReceiptDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Center(child: Text('HÓA ĐƠN THANH TOÁN')),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Thời gian: ${DateTime.now().toString().substring(0, 16)}'),
              const Divider(),
              ...currentOrder.map((item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${item['name']} ${item['note'].toString().isNotEmpty ? "(${item['note']})" : ""}'),
                        Text('${item['price'].toStringAsFixed(0)}đ'),
                      ],
                    ),
                  )),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('TỔNG CỘNG:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('${totalAmount.toStringAsFixed(0)}đ',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.teal)),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Đóng')),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              _submitOrder();
            },
            icon: const Icon(Icons.check),
            label: const Text('XÁC NHẬN & LƯU SERVER'),
          )
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
              ? 'Thanh toán & Lưu đơn thành công!'
              : 'Lỗi gửi Server!'),
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
            Text('Tính Tiền Quán Ăn'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMenuFromServer,
          ),
          if (isAdminMode)
            IconButton(
              icon: const Icon(Icons.add_circle, color: Colors.teal),
              onPressed: _showAddMenuItemDialog,
            ),
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
            child: isLoadingMenu
                ? const Center(child: CircularProgressIndicator())
                : GridView.builder(
                    padding: const EdgeInsets.all(8),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 1.6,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: menuList.length,
                    itemBuilder: (ctx, index) {
                      final dish = menuList[index];
                      double price =
                          double.tryParse(dish['price'].toString()) ?? 0.0;
                      return Card(
                        color: Colors.teal.shade50,
                        child: InkWell(
                          onTap: () => _showAddDishDialog(dish['name'], price),
                          child: Stack(
                            children: [
                              Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(dish['name'],
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16)),
                                    Text('${price.toStringAsFixed(0)}đ',
                                        style:
                                            const TextStyle(color: Colors.teal)),
                                  ],
                                ),
                              ),
                              if (isAdminMode && dish['id'] != null)
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child: IconButton(
                                    icon: const Icon(Icons.remove_circle,
                                        color: Colors.red, size: 20),
                                    onPressed: () async {
                                      await ApiService.deleteMenuItem(
                                          dish['id'].toString());
                                      _loadMenuFromServer();
                                    },
                                  ),
                                )
                            ],
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
                      const Text('Đơn hiện tại',
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
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed:
                          currentOrder.isEmpty ? null : _showReceiptDialog,
                      icon: const Icon(Icons.receipt_long),
                      label: const Text('XEM HÓA ĐƠN & THANH TOÁN'),
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

// ------------------- MÀN HÌNH BÁO CÁO DOANH THU -------------------
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  List<dynamic> orders = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() => isLoading = true);
    final data = await ApiService.fetchOrders();
    setState(() {
      orders = data;
      isLoading = false;
    });
  }

  double get totalRevenue => orders.fold(
      0.0,
      (sum, item) =>
          sum + (double.tryParse(item['total'].toString()) ?? 0.0));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Báo Cáo Doanh Thu'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReports,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const Text('TỔNG DOANH THU SERVER',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(
                        '${totalRevenue.toStringAsFixed(0)} VNĐ',
                        style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal),
                      ),
                      Text('Tổng số đơn đã lưu: ${orders.length}'),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Lịch sử đơn hàng mới nhất',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                Expanded(
                  child: orders.isEmpty
                      ? const Center(child: Text('Chưa có đơn hàng nào trên Server!'))
                      : ListView.builder(
                          itemCount: orders.length,
                          itemBuilder: (ctx, index) {
                            final order = orders[orders.length - 1 - index];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              child: ListTile(
                                leading: const Icon(Icons.receipt,
                                    color: Colors.teal),
                                title: Text(
                                    'Đơn hàng #${order['id'] ?? (orders.length - index)}'),
                                subtitle: Text(
                                    'Thời gian: ${order['timestamp']?.toString().substring(0, 10) ?? ''}'),
                                trailing: Text(
                                  '${(double.tryParse(order['total'].toString()) ?? 0).toStringAsFixed(0)}đ',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.teal),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

