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
            icon: Icon(Icons.history),
            label: 'Nhật Ký Máy',
          ),
        ],
      ),
    );
  }
}

// ------------------- MÀN HÌNH CHÍNH (POS) -------------------
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

  // PHÂN LOẠI DANH MỤC
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
      0, (sum, item) => sum + (item['totalPrice'] * item['qty']));

  // TÙY CHỈNH MÓN ÁN & BIẾN THỂ & TOPPING
  void _openDishCustomizationModal(Map<String, dynamic> dish) {
    List rawVariants = dish['variants'] ?? [];
    List rawToppings = dish['toppings'] ?? [];

    List<Map<String, dynamic>> variants =
        rawVariants.map((v) => Map<String, dynamic>.from(v)).toList();
    List<Map<String, dynamic>> toppings =
        rawToppings.map((t) => Map<String, dynamic>.from(t)).toList();

    Map<String, dynamic>? selectedVariant =
        variants.isNotEmpty ? variants.first : null;
    List<Map<String, dynamic>> selectedToppings = [];
    final noteController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            double calculateItemPrice() {
              double base = selectedVariant != null
                  ? (double.tryParse(selectedVariant!['price'].toString()) ?? 0)
                  : (double.tryParse(dish['price'].toString()) ?? 0);
              double toppingTotal = selectedToppings.fold(
                  0, (sum, t) => sum + (double.tryParse(t['price'].toString()) ?? 0));
              return base + toppingTotal;
            }

            return Padding(
              padding: EdgeInsets.only(
                top: 16,
                left: 16,
                right: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tùy chỉnh: ${dish['name']}',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const Divider(),

                    // QUẢN LÝ BIẾN THỂ (NẾU CÓ)
                    if (variants.isNotEmpty) ...[
                      const Text('Chọn phần / biến thể:',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, color: Colors.teal)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: variants.map((v) {
                          bool isSel = selectedVariant == v;
                          return ChoiceChip(
                            label: Text(
                                '${v['name']} (${(double.tryParse(v['price'].toString()) ?? 0).toStringAsFixed(0)}đ)'),
                            selected: isSel,
                            selectedColor: Colors.teal,
                            labelStyle: TextStyle(
                                color: isSel ? Colors.white : Colors.black),
                            onSelected: (val) {
                              if (val) {
                                setModalState(() => selectedVariant = v);
                              }
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // TÙY CHỈNH TOPPING / MÓN THÊM
                    if (toppings.isNotEmpty) ...[
                      const Text('Chọn món thêm / Topping:',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, color: Colors.teal)),
                      const SizedBox(height: 8),
                      Column(
                        children: toppings.map((t) {
                          bool isChecked = selectedToppings.contains(t);
                          double tPrice =
                              double.tryParse(t['price'].toString()) ?? 0;
                          return CheckboxListTile(
                            title: Text(t['name'].toString()),
                            subtitle: tPrice > 0
                                ? Text('+${tPrice.toStringAsFixed(0)}đ')
                                : const Text('Miễn phí'),
                            value: isChecked,
                            onChanged: (val) {
                              setModalState(() {
                                if (val == true) {
                                  selectedToppings.add(t);
                                } else {
                                  selectedToppings.remove(t);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // GHI CHÚ RIÊNG
                    TextField(
                      controller: noteController,
                      decoration: const InputDecoration(
                        labelText: 'Ghi chú món (Ví dụ: Không hành, nhiều ớt)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // NÚT THÊM VÀO ĐƠN
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () {
                          double unitPrice = calculateItemPrice();
                          String fullName = selectedVariant != null
                              ? '${dish['name']} (${selectedVariant!['name']})'
                              : dish['name'];

                          List<String> toppingNames = selectedToppings
                              .map((e) => e['name'].toString())
                              .toList();
                          if (toppingNames.isNotEmpty) {
                            fullName += ' + ${toppingNames.join(', ')}';
                          }

                          setState(() {
                            currentOrder.add({
                              'name': fullName,
                              'price': unitPrice,
                              'totalPrice': unitPrice,
                              'qty': 1,
                              'note': noteController.text.trim(),
                            });
                          });

                          Navigator.pop(ctx);
                        },
                        child: Text(
                          'THÊM VÀO ĐƠN - ${calculateItemPrice().toStringAsFixed(0)}đ',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // DIALOG THÊM MÓN DÀNH CHO ADMIN
  void _showAddMenuItemDialog() {
    final nameCtrl = TextEditingController();
    final catCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final variantsCtrl = TextEditingController();
    final toppingsCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thêm món mới (Admin)'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                    labelText: 'Tên món (Ví dụ: Cháo / Trà sữa)',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: catCtrl,
                decoration: const InputDecoration(
                    labelText: 'Danh mục (Ví dụ: Món ăn / Nước uống)',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: priceCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Giá mặc định (VNĐ)',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: variantsCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Biến thể/Phần ăn (Mỗi dòng 1 loại)',
                  hintText: 'Tô nhỏ:10000\nTô lớn:20000',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: toppingsCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Món thêm/Topping (Mỗi dòng 1 loại)',
                  hintText: 'Thêm trứng:5000\nNhiều ớt:0',
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
              String name = nameCtrl.text.trim();
              String category = catCtrl.text.trim();
              double defaultPrice = double.tryParse(priceCtrl.text) ?? 0;

              List<Map<String, dynamic>> parsedVariants = [];
              if (variantsCtrl.text.trim().isNotEmpty) {
                for (var line in variantsCtrl.text.trim().split('\n')) {
                  if (line.contains(':')) {
                    var parts = line.split(':');
                    parsedVariants.add({
                      'name': parts[0].trim(),
                      'price': double.tryParse(parts[1].trim()) ?? defaultPrice,
                    });
                  }
                }
              }

              List<Map<String, dynamic>> parsedToppings = [];
              if (toppingsCtrl.text.trim().isNotEmpty) {
                for (var line in toppingsCtrl.text.trim().split('\n')) {
                  if (line.contains(':')) {
                    var parts = line.split(':');
                    parsedToppings.add({
                      'name': parts[0].trim(),
                      'price': double.tryParse(parts[1].trim()) ?? 0,
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
                  toppings: parsedToppings,
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
    final pinCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác thực Admin'),
        content: TextField(
          controller: pinCtrl,
          obscureText: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
              labelText: 'Mã PIN bảo mật (1234)', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () async {
              if (pinCtrl.text == adminPinCode) {
                setState(() => isAdminMode = !isAdminMode);
                Navigator.pop(ctx);
                await LocalStorageService.addLog('ADMIN_AUTH',
                    isAdminMode ? 'Bật chế độ Admin' : 'Tắt chế độ Admin');
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
            content: Text('Thanh toán thành công (Đã lưu Offline)!'),
            backgroundColor: Colors.green),
      );
      setState(() => currentOrder.clear());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Tính Tiền'),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'OFFLINE',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.green),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh), onPressed: _loadMenuFromStorage),
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
          // THANH CHỌN DANH MỤC (CATEGORY)
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
                      childAspectRatio: 1.4,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: filteredMenu.length,
                    itemBuilder: (ctx, index) {
                      final dish = filteredMenu[index];
                      double price =
                          double.tryParse(dish['price'].toString()) ?? 0.0;
                      List variants = dish['variants'] ?? [];
                      List toppings = dish['toppings'] ?? [];

                      return Card(
                        color: Colors.teal.shade50,
                        child: InkWell(
                          onTap: () => _openDishCustomizationModal(dish),
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
                                          ? '${variants.length} phần lựa chọn'
                                          : '${price.toStringAsFixed(0)}đ',
                                      style: TextStyle(
                                          color: variants.isNotEmpty
                                              ? Colors.orange.shade800
                                              : Colors.teal,
                                          fontWeight: FontWeight.w600),
                                    ),
                                    if (toppings.isNotEmpty)
                                      Text(
                                        '+${toppings.length} topping',
                                        style: const TextStyle(
                                            fontSize: 11, color: Colors.grey),
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

          // DANH SÁCH ĐƠN HÀNG
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Đơn hàng hiện tại',
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
                              ? Text('Ghi chú: ${item['note']}',
                                  style: const TextStyle(color: Colors.red))
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
                      label: const Text('THANH TOÁN & LƯU ĐƠN (OFFLINE)'),
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
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadReports)
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
                      const Text('TỔNG DOANH THU OFFLINE',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(
                        '${totalRevenue.toStringAsFixed(0)} VNĐ',
                        style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal),
                      ),
                      Text('Tổng số đơn hàng: ${orders.length}'),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: orders.length,
                    itemBuilder: (ctx, index) {
                      final order = orders[orders.length - 1 - index];
                      return Card(
                        margin:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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

// ------------------- MÀN HÌNH NHẬT KÝ THAO TÁC -------------------
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
        title: const Text('Nhật Ký Thao Tác'),
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

