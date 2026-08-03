// lib/main.dart

import 'package:flutter/material.dart';
import 'services/api_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
    const LogsScreen(),
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
          NavigationDestination(
            icon: Icon(Icons.history_edu),
            label: 'Nhật Ký Máy',
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
  String selectedCategory = 'Tất cả';

  @override
  void initState() {
    super.initState();
    _loadMenuFromStorage();
  }

  Future<void> _loadMenuFromStorage() async {
    setState(() => isLoadingMenu = true);
    final data = await LocalStorageService.fetchMenu();
    setState(() {
      menuList = List<Map<String, dynamic>>.from(data);
      isLoadingMenu = false;
    });
  }

  List<String> get categories {
    List<String> list = ['Tất cả'];
    for (var item in menuList) {
      String cat = item['category']?.toString() ?? 'Khác';
      if (!list.contains(cat)) list.add(cat);
    }
    return list;
  }

  List<Map<String, dynamic>> get filteredMenu {
    if (selectedCategory == 'Tất cả') return menuList;
    return menuList
        .where((item) => (item['category'] ?? 'Khác') == selectedCategory)
        .toList();
  }

  double get totalAmount => currentOrder.fold(
      0, (sum, item) => sum + (item['price'] * item['qty']));

  // Chọn loại/phần ăn khi nhấn vào món có nhiều biến thể
  void _onDishSelected(Map<String, dynamic> dish) {
    List<dynamic> rawVariants = dish['variants'] ?? [];
    List<Map<String, dynamic>> variants =
        rawVariants.map((v) => Map<String, dynamic>.from(v)).toList();

    if (variants.isEmpty) {
      _showAddDishDialog(dish['name'], double.tryParse(dish['price'].toString()) ?? 0);
    } else {
      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
        builder: (ctx) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Chọn phần: ${dish['name']}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...variants.map((v) {
                double price = double.tryParse(v['price'].toString()) ?? 0;
                return ListTile(
                  title: Text(v['name'].toString(),
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  trailing: Text('${price.toStringAsFixed(0)}đ',
                      style: const TextStyle(
                          color: Colors.teal,
                          fontWeight: FontWeight.bold,
                          fontSize: 15)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showAddDishDialog('${dish['name']} (${v['name']})', price);
                  },
                );
              }),
            ],
          ),
        ),
      );
    }
  }

  void _showAddDishDialog(String fullName, double defaultPrice) {
    final priceController =
        TextEditingController(text: defaultPrice.toStringAsFixed(0));
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Thêm: $fullName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Giá bán (VNĐ)',
                suffixText: 'đ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(
                labelText: 'Ghi chú (Ví dụ: Không hành, nhiều ớt...)',
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
              double price = double.tryParse(priceController.text) ?? defaultPrice;
              setState(() {
                currentOrder.add({
                  'name': fullName,
                  'price': price,
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

  void _showAddMenuItemDialog() {
    final nameController = TextEditingController();
    final categoryController = TextEditingController();
    final priceController = TextEditingController();
    final variantsController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thêm món / Danh mục mới'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Tên món (Ví dụ: Cháo / Nước ngọt)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: categoryController,
                decoration: const InputDecoration(
                  labelText: 'Danh mục (Ví dụ: Món ăn / Nước uống)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Giá mặc định (VNĐ)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: variantsController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Các phần/loại (Mỗi loại 1 dòng)',
                  hintText: 'Cháo 10k:10000\nCháo 20k:20000\nCháo xương:35000',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () async {
              String name = nameController.text.trim();
              String category = categoryController.text.trim();
              double defaultPrice = double.tryParse(priceController.text) ?? 0;

              List<Map<String, dynamic>> parsedVariants = [];
              if (variantsController.text.trim().isNotEmpty) {
                List<String> lines = variantsController.text.trim().split('\n');
                for (var line in lines) {
                  if (line.contains(':')) {
                    var parts = line.split(':');
                    parsedVariants.add({
                      'name': parts[0].trim(),
                      'price': double.tryParse(parts[1].trim()) ?? defaultPrice,
                    });
                  } else if (line.trim().isNotEmpty) {
                    parsedVariants.add({
                      'name': line.trim(),
                      'price': defaultPrice,
                    });
                  }
                }
              }

              if (name.isNotEmpty) {
                Navigator.pop(ctx);
                bool success = await LocalStorageService.addMenuItem(
                  name: name,
                  category: category.isEmpty ? 'Món khác' : category,
                  defaultPrice: defaultPrice,
                  variants: parsedVariants,
                );
                if (success) _loadMenuFromStorage();
              }
            },
            child: const Text('Lưu Món'),
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
            labelText: 'Mã PIN bảo mật (1234)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () async {
              if (pinController.text == adminPinCode) {
                setState(() => isAdminMode = !isAdminMode);
                Navigator.pop(ctx);
                await LocalStorageService.addLog('ADMIN_LOGIN',
                    isAdminMode ? 'Đăng nhập Admin' : 'Đăng xuất Admin');
              }
            },
            child: Text(isAdminMode ? 'Tắt Admin' : 'Mở khóa'),
          ),
        ],
      ),
    );
  }

  void _submitOrder() async {
    if (currentOrder.isEmpty) return;

    final orderData = {
      'timestamp': DateTime.now().toString().substring(0, 19),
      'total': totalAmount,
      'items': List<Map<String, dynamic>>.from(currentOrder),
    };

    bool isSaved = await LocalStorageService.saveOrder(orderData);
    if (mounted && isSaved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Thanh toán & Đã lưu đơn hàng!'),
            backgroundColor: Colors.green),
      );
      setState(() => currentOrder.clear());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tính Tiền Quán Ăn'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMenuFromStorage,
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
          // THANH CHỌN DANH MỤC MÓN ÁN
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              itemBuilder: (ctx, index) {
                String cat = categories[index];
                bool isSelected = cat == selectedCategory;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(cat),
                    selected: isSelected,
                    selectedColor: Colors.teal,
                    labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.black),
                    onSelected: (val) {
                      if (val) setState(() => selectedCategory = cat);
                    },
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),

          // LƯỚI DANH SÁCH MÓN ÁN
          Expanded(
            flex: 1,
            child: isLoadingMenu
                ? const Center(child: CircularProgressIndicator())
                : GridView.builder(
                    padding: const EdgeInsets.all(8),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 1.5,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: filteredMenu.length,
                    itemBuilder: (ctx, index) {
                      final dish = filteredMenu[index];
                      double price =
                          double.tryParse(dish['price'].toString()) ?? 0.0;
                      List variants = dish['variants'] ?? [];

                      return Card(
                        color: Colors.teal.shade50,
                        child: InkWell(
                          onTap: () => _onDishSelected(dish),
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
                                    const SizedBox(height: 4),
                                    Text(
                                      variants.isNotEmpty
                                          ? '${variants.length} lựa chọn'
                                          : '${price.toStringAsFixed(0)}đ',
                                      style: TextStyle(
                                          color: variants.isNotEmpty
                                              ? Colors.orange.shade800
                                              : Colors.teal,
                                          fontWeight: FontWeight.w600),
                                    ),
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
                                      await LocalStorageService.deleteMenuItem(
                                          dish['id'].toString());
                                      _loadMenuFromStorage();
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

          // DANH SÁCH ĐƠN HÀNG HIỆN TẠI
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
                      onPressed: currentOrder.isEmpty ? null : _submitOrder,
                      icon: const Icon(Icons.check_circle),
                      label: const Text('THANH TOÁN & LƯU ĐƠN'),
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

// ------------------- MÀN HÌNH BÁO CÁO -------------------
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  List<Map<String, dynamic>> orders = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() => isLoading = true);
    final data = await LocalStorageService.fetchOrders();
    setState(() {
      orders = List<Map<String, dynamic>>.from(data);
      isLoading = false;
    });
  }

  double get totalRevenue => orders.fold(
      0.0, (sum, item) => sum + (double.tryParse(item['total'].toString()) ?? 0.0));

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
                      const Text('TỔNG DOANH THU',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(
                        '${totalRevenue.toStringAsFixed(0)} VNĐ',
                        style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal),
                      ),
                      Text('Tổng số đơn đã thanh toán: ${orders.length}'),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: orders.length,
                    itemBuilder: (ctx, index) {
                      final order = orders[orders.length - 1 - index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        child: ListTile(
                          leading: const Icon(Icons.receipt, color: Colors.teal),
                          title: Text('Đơn #${order['id']}'),
                          subtitle: Text('Thời gian: ${order['timestamp']}'),
                          trailing: Text(
                            '${(double.tryParse(order['total'].toString()) ?? 0).toStringAsFixed(0)}đ',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, color: Colors.teal),
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

// ------------------- MÀN HÌNH NHẬT KÝ MÁY -------------------
class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  List<Map<String, dynamic>> logs = [];

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    final data = await LocalStorageService.fetchLogs();
    setState(() => logs = List<Map<String, dynamic>>.from(data));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nhật Ký Máy'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadLogs)
        ],
      ),
      body: ListView.builder(
        itemCount: logs.length,
        itemBuilder: (ctx, index) {
          final log = logs[logs.length - 1 - index];
          return ListTile(
            leading: const Icon(Icons.history, color: Colors.teal),
            title: Text(log['detail'] ?? ''),
            subtitle: Text(log['time'] ?? ''),
          );
        },
      ),
    );
  }
}

