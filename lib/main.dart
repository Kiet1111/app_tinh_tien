// lib/main.dart

import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

// Định dạng tiền tệ VNĐ
String formatMoney(double amount) {
  String str = amount.toStringAsFixed(0);
  RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
  return '${str.replaceAllMapped(reg, (Match m) => '${m[1]}.')}đ';
}

// ------------------- LOCAL STORAGE & LOGIC DỮ LIỆU -------------------
class LocalStorageService {
  static const String masterCode = "000"; // Mã PIN master mặc định
  static bool isUnlocked = false; // Trạng thái đã xác thực mã PIN hay chưa

  static final List<String> _categories = [
    'Tất cả',
    'Đồ Uống',
    'Đồ Ăn',
    'Đồ Cân',
  ];

  static final List<Map<String, dynamic>> _menuList = [
    {
      'id': '1',
      'name': 'Cà Phê Sữa Đá',
      'category': 'Đồ Uống',
      'price': 25000.0,
      'unit': 'ly',
      'stock': 50.0,
      'variants': [],
      'toppings': [
        {'name': 'Trân châu đen', 'price': 5000.0, 'qty': 0},
        {'name': 'Kem cheese', 'price': 10000.0, 'qty': 0},
      ]
    },
    {
      'id': '2',
      'name': 'Trà Sữa Thái Xanh',
      'category': 'Đồ Uống',
      'price': 30000.0,
      'unit': 'ly',
      'stock': 40.0,
      'variants': [],
      'toppings': [
        {'name': 'Trân châu 3Q', 'price': 5000.0, 'qty': 0},
        {'name': 'Pudding trứng', 'price': 7000.0, 'qty': 0},
      ]
    },
    {
      'id': '3',
      'name': 'Dừa Nạo Sợi',
      'category': 'Đồ Cân',
      'price': 60000.0,
      'unit': 'kg',
      'stock': 10.0,
      'variants': [],
      'toppings': []
    },
  ];

  static final List<Map<String, dynamic>> _orders = [];
  static final List<Map<String, dynamic>> _expenses = [];
  static final List<Map<String, dynamic>> _logs = [
    {
      'detail': 'Khởi động ứng dụng POS thành công',
      'time': DateTime.now().toString().substring(0, 16),
      'type': 'system'
    }
  ];

  // Danh mục
  static Future<List<String>> fetchCategories() async => List<String>.from(_categories);
  
  static Future<void> addCategory(String name) async {
    if (!_categories.contains(name)) {
      _categories.add(name);
      _addLog('Thêm danh mục mới: $name');
    }
  }

  static Future<void> deleteCategory(String name) async {
    if (name != 'Tất cả') {
      _categories.remove(name);
      _addLog('Xóa danh mục: $name');
    }
  }

  // Thực đơn
  static Future<List<Map<String, dynamic>>> fetchMenu() async => List<Map<String, dynamic>>.from(_menuList);

  static Future<void> addMenuItem(Map<String, dynamic> item) async {
    item['id'] = DateTime.now().millisecondsSinceEpoch.toString();
    _menuList.add(item);
    _addLog('Thêm món mới: ${item['name']}');
  }

  static Future<void> updateMenuItem(Map<String, dynamic> item) async {
    int idx = _menuList.indexWhere((e) => e['id'].toString() == item['id'].toString());
    if (idx != -1) {
      _menuList[idx] = item;
      _addLog('Cập nhật món: ${item['name']}');
    }
  }

  static Future<void> deleteMenuItem(String id) async {
    int idx = _menuList.indexWhere((e) => e['id'].toString() == id);
    if (idx != -1) {
      String name = _menuList[idx]['name'];
      _menuList.removeAt(idx);
      _addLog('Xóa món: $name');
    }
  }

  // Đơn hàng & Chốt ngày
  static Future<bool> saveOrder(Map<String, dynamic> order) async {
    _orders.add(order);
    List items = order['items'] ?? [];
    for (var item in items) {
      var dishId = item['dishId'];
      var qty = item['qty'] ?? 1.0;
      int idx = _menuList.indexWhere((e) => e['id'].toString() == dishId.toString());
      if (idx != -1) {
        double currentStock = double.tryParse(_menuList[idx]['stock'].toString()) ?? 0.0;
        _menuList[idx]['stock'] = (currentStock - qty) < 0 ? 0.0 : (currentStock - qty);
      }
    }
    _addLog('Tạo đơn hàng #${order['id']} - Tổng: ${formatMoney(order['total'] ?? 0)}');
    return true;
  }

  static Future<List<Map<String, dynamic>>> fetchOrders() async => List<Map<String, dynamic>>.from(_orders);

  static Future<List<Map<String, dynamic>>> fetchExpenses() async => List<Map<String, dynamic>>.from(_expenses);

  static Future<void> addExpense(String category, double amount, String note) async {
    _expenses.add({
      'category': category,
      'amount': amount,
      'note': note,
      'timestamp': DateTime.now().toIso8601String(),
    });
    _addLog('Chi phí phát sinh [$category]: ${formatMoney(amount)}');
  }

  static Future<List<Map<String, dynamic>>> fetchLogs() async => List<Map<String, dynamic>>.from(_logs);

  static void _addLog(String detail) {
    _logs.add({
      'detail': detail,
      'time': DateTime.now().toString().substring(0, 16),
      'type': 'order_op'
    });
  }

  // Xác thực mã PIN security
  static bool verifyCode(String code) {
    if (code == masterCode) {
      isUnlocked = true;
      return true;
    }
    return false;
  }
}

// ------------------- CẤU HÌNH GIAO DIỆN CHÍNH -------------------
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'POS Bán Hàng & Chốt Lợi Nhuận',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0D9488),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
        ),
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
    const MenuManagementScreen(),
    const EndOfDayReportScreen(),
    const SecureLogsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        height: 62,
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront, color: Color(0xFF0D9488)),
            label: 'Bán Hàng',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2, color: Color(0xFF0D9488)),
            label: 'Thực Đơn',
          ),
          NavigationDestination(
            icon: Icon(Icons.point_of_sale_outlined),
            selectedIcon: Icon(Icons.point_of_sale, color: Color(0xFF0D9488)),
            label: 'Chốt Ngày',
          ),
          NavigationDestination(
            icon: Icon(Icons.security_outlined),
            selectedIcon: Icon(Icons.security, color: Color(0xFF0D9488)),
            label: 'Nhật Ký (PIN)',
          ),
        ],
      ),
    );
  }
}

// ------------------- 1. MÀN HÌNH BÁN HÀNG (+/- TOPPING) -------------------
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool isOnline = true;
  bool isLoadingMenu = true;

  List<Map<String, dynamic>> menuList = [];
  List<String> categories = ['Tất cả'];
  List<Map<String, dynamic>> currentOrder = [];
  String selectedCategory = 'Tất cả';
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoadingMenu = true);
    final data = await LocalStorageService.fetchMenu();
    final cats = await LocalStorageService.fetchCategories();
    setState(() {
      menuList = List<Map<String, dynamic>>.from(data);
      categories = List<String>.from(cats);
      isLoadingMenu = false;
    });
  }

  List<Map<String, dynamic>> get filteredMenu {
    return menuList.where((item) {
      bool matchCat = selectedCategory == 'Tất cả' || item['category'] == selectedCategory;
      bool matchSearch = searchQuery.isEmpty ||
          item['name'].toString().toLowerCase().contains(searchQuery.toLowerCase());
      return matchCat && matchSearch;
    }).toList();
  }

  double get totalAmount => currentOrder.fold(
      0.0, (sum, item) => sum + (item['totalPrice'] as double));

  void _openQuantityModal(Map<String, dynamic> dish) {
    String unit = dish['unit']?.toString().toLowerCase() ?? 'phần';
    bool isWeightUnit = unit == 'kg' || unit == 'g' || unit == 'gram';

    final qtyController = TextEditingController(text: isWeightUnit ? '' : '1');
    final weightGramController = TextEditingController();
    double baseUnitPrice = double.tryParse(dish['price'].toString()) ?? 0.0;

    List rawToppings = dish['toppings'] ?? [];
    List<Map<String, dynamic>> toppingList = rawToppings
        .map((t) => {
              'name': t['name'],
              'price': double.tryParse(t['price'].toString()) ?? 0.0,
              'qty': 0
            })
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            double toppingTotal = toppingList.fold(0.0, (sum, t) {
              return sum + (t['price'] as double) * (t['qty'] as int);
            });

            double calculatedQty = 1.0;
            if (isWeightUnit) {
              if (weightGramController.text.isNotEmpty) {
                double grams = double.tryParse(weightGramController.text) ?? 0;
                calculatedQty = grams / 1000.0;
              } else if (qtyController.text.isNotEmpty) {
                calculatedQty = double.tryParse(qtyController.text) ?? 0.0;
              }
            } else {
              calculatedQty = double.tryParse(qtyController.text) ?? 1.0;
            }

            double totalPrice = (baseUnitPrice + toppingTotal) * calculatedQty;

            return Padding(
              padding: EdgeInsets.only(
                top: 16, left: 16, right: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(dish['name'],
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                        Text('${formatMoney(baseUnitPrice)} / $unit',
                            style: const TextStyle(
                                color: Color(0xFF0D9488),
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
                      ],
                    ),
                    const Divider(height: 20),

                    if (isWeightUnit) ...[
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: weightGramController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(labelText: 'Số Gram (g)', isDense: true),
                              onChanged: (_) {
                                qtyController.clear();
                                setModalState(() {});
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: qtyController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(labelText: 'Số Kg (kg)', isDense: true),
                              onChanged: (_) {
                                weightGramController.clear();
                                setModalState(() {});
                              },
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton.filledTonal(
                            icon: const Icon(Icons.remove),
                            onPressed: () {
                              int current = int.tryParse(qtyController.text) ?? 1;
                              if (current > 1) {
                                qtyController.text = (current - 1).toString();
                                setModalState(() {});
                              }
                            },
                          ),
                          SizedBox(
                            width: 80,
                            child: TextField(
                              controller: qtyController,
                              textAlign: TextAlign.center,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              decoration: const InputDecoration(isDense: true),
                              onChanged: (_) => setModalState(() {}),
                            ),
                          ),
                          IconButton.filledTonal(
                            icon: const Icon(Icons.add),
                            onPressed: () {
                              int current = int.tryParse(qtyController.text) ?? 1;
                              qtyController.text = (current + 1).toString();
                              setModalState(() {});
                            },
                          ),
                        ],
                      ),
                    ],

                    // PHẦN CỘNG TRỪ SỐ LƯỢNG TOPPING
                    if (toppingList.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text('Chọn Topping (Tăng / Giảm):',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D9488))),
                      const SizedBox(height: 8),
                      ...toppingList.map((t) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${t['name']} (+${formatMoney(t['price'])})',
                                  style: const TextStyle(fontSize: 14)),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 22),
                                    onPressed: t['qty'] > 0
                                        ? () => setModalState(() => t['qty']--)
                                        : null,
                                  ),
                                  Text('${t['qty']}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline, color: Colors.green, size: 22),
                                    onPressed: () => setModalState(() => t['qty']++),
                                  ),
                                ],
                              )
                            ],
                          ),
                        );
                      }),
                    ],

                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D9488),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: calculatedQty <= 0
                            ? null
                            : () {
                                String displayQty = isWeightUnit
                                    ? (calculatedQty < 1
                                        ? '${(calculatedQty * 1000).toStringAsFixed(0)}g'
                                        : '${calculatedQty.toStringAsFixed(2)}kg')
                                    : '${calculatedQty.toInt()} $unit';

                                List<String> selectedTopStr = [];
                                for (var t in toppingList) {
                                  if (t['qty'] > 0) {
                                    selectedTopStr.add('${t['name']} (x${t['qty']})');
                                  }
                                }

                                String fullName = dish['name'];
                                if (selectedTopStr.isNotEmpty) {
                                  fullName += ' + [${selectedTopStr.join(', ')}]';
                                }

                                setState(() {
                                  currentOrder.add({
                                    'dishId': dish['id'],
                                    'name': fullName,
                                    'price': baseUnitPrice + toppingTotal,
                                    'qty': calculatedQty,
                                    'displayQty': displayQty,
                                    'totalPrice': totalPrice,
                                  });
                                });
                                Navigator.pop(ctx);
                              },
                        child: Text('THÊM VÀO ĐƠN • ${formatMoney(totalPrice)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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

  void _submitOrder() async {
    if (currentOrder.isEmpty) return;

    final orderData = {
      'id': DateTime.now().millisecondsSinceEpoch.toString().substring(7),
      'timestamp': DateTime.now().toIso8601String(),
      'total': totalAmount,
      'items': List<Map<String, dynamic>>.from(currentOrder),
    };

    bool isSaved = await LocalStorageService.saveOrder(orderData);
    if (mounted && isSaved) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isOnline ? 'Tạo đơn thành công!' : 'Lưu đơn Offline thành công!'),
          backgroundColor: Colors.green,
        ),
      );
      setState(() => currentOrder.clear());
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: SizedBox(
          height: 38,
          child: TextField(
            onChanged: (val) => setState(() => searchQuery = val),
            decoration: InputDecoration(
              hintText: 'Tìm nhanh món...',
              prefixIcon: const Icon(Icons.search, size: 18),
              contentPadding: EdgeInsets.zero,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(isOnline ? Icons.wifi : Icons.wifi_off,
                color: isOnline ? Colors.green : Colors.orange),
            onPressed: () => setState(() => isOnline = !isOnline),
          )
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: categories.length,
              itemBuilder: (ctx, index) {
                String cat = categories[index];
                bool isSelected = cat == selectedCategory;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: ChoiceChip(
                    label: Text(cat),
                    selected: isSelected,
                    selectedColor: const Color(0xFF0D9488),
                    labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87),
                    onSelected: (val) {
                      if (val) setState(() => selectedCategory = cat);
                    },
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: isLoadingMenu
                ? const Center(child: CircularProgressIndicator())
                : GridView.builder(
                    padding: const EdgeInsets.all(8),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 0.95,
                      crossAxisSpacing: 6,
                      mainAxisSpacing: 6,
                    ),
                    itemCount: filteredMenu.length,
                    itemBuilder: (ctx, index) {
                      final dish = filteredMenu[index];
                      double price = double.tryParse(dish['price'].toString()) ?? 0.0;
                      double stock = double.tryParse(dish['stock'].toString()) ?? 0.0;

                      return Card(
                        child: InkWell(
                          onTap: stock <= 0 ? null : () => _openQuantityModal(dish),
                          child: Padding(
                            padding: const EdgeInsets.all(6.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(dish['name'],
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                Text(formatMoney(price),
                                    style: const TextStyle(
                                        color: Color(0xFF0D9488),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12)),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: currentOrder.isEmpty
          ? null
          : Container(
              padding: const EdgeInsets.all(12),
              color: Colors.white,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9488),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _submitOrder,
                child: Text('THANH TOÁN (${currentOrder.length} MÓN) • ${formatMoney(totalAmount)}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
    );
  }
}

// ------------------- 2. MÀN HÌNH QUẢN LÝ THỰC ĐƠN & DANH MỤC -------------------
class MenuManagementScreen extends StatefulWidget {
  const MenuManagementScreen({super.key});

  @override
  State<MenuManagementScreen> createState() => _MenuManagementScreenState();
}

class _MenuManagementScreenState extends State<MenuManagementScreen> {
  List<Map<String, dynamic>> menuList = [];
  List<String> categories = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMenuData();
  }

  Future<void> _loadMenuData() async {
    setState(() => isLoading = true);
    final data = await LocalStorageService.fetchMenu();
    final cats = await LocalStorageService.fetchCategories();
    setState(() {
      menuList = List<Map<String, dynamic>>.from(data);
      categories = List<String>.from(cats);
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quản Lý Thực Đơn & Danh Mục')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: menuList.length,
              itemBuilder: (ctx, index) {
                final item = menuList[index];
                double price = double.tryParse(item['price'].toString()) ?? 0;
                return Card(
                  child: ListTile(
                    title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Danh mục: ${item['category']} | Giá: ${formatMoney(price)}'),
                  ),
                );
              },
            ),
    );
  }
}

// ------------------- 3. MÀN HÌNH MÁY CHỦ CHỐT NGÀY & TÍNH LỢI NHUẬN -------------------
class EndOfDayReportScreen extends StatefulWidget {
  const EndOfDayReportScreen({super.key});

  @override
  State<EndOfDayReportScreen> createState() => _EndOfDayReportScreenState();
}

class _EndOfDayReportScreenState extends State<EndOfDayReportScreen> {
  DateTime selectedDate = DateTime.now();
  List<Map<String, dynamic>> orders = [];
  List<Map<String, dynamic>> expenses = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDataForDate();
  }

  Future<void> _loadDataForDate() async {
    setState(() => isLoading = true);
    final allOrders = await LocalStorageService.fetchOrders();
    final allExpenses = await LocalStorageService.fetchExpenses();

    String targetDateStr = selectedDate.toIso8601String().substring(0, 10);

    setState(() {
      orders = allOrders.where((o) => o['timestamp'].toString().startsWith(targetDateStr)).toList();
      expenses = allExpenses.where((e) => e['timestamp'].toString().startsWith(targetDateStr)).toList();
      isLoading = false;
    });
  }

  double get dayRevenue => orders.fold(0.0, (sum, o) => sum + (double.tryParse(o['total'].toString()) ?? 0.0));
  double get dayExpenses => expenses.fold(0.0, (sum, e) => sum + (double.tryParse(e['amount'].toString()) ?? 0.0));
  double get dayNetProfit => dayRevenue - dayExpenses;

  @override
  Widget build(BuildContext context) {
    String dateFormatted = "${selectedDate.day}/${selectedDate.month}/${selectedDate.year}";

    return Scaffold(
      appBar: AppBar(
        title: const Text('Máy Chủ - Báo Cáo Chốt Ngày'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: () async {
              DateTime? picked = await showDatePicker(
                context: context,
                initialDate: selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );
              if (picked != null) {
                setState(() => selectedDate = picked);
                _loadDataForDate();
              }
            },
          )
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ngày chốt sổ: $dateFormatted',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: dayNetProfit >= 0 ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: dayNetProfit >= 0 ? const Color(0xFF10B981) : Colors.red,
                      ),
                    ),
                    child: Column(
                      children: [
                        const Text('LỢI NHUẬN RÒNG CUỐI NGÀY',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                        const SizedBox(height: 6),
                        Text(
                          formatMoney(dayNetProfit),
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: dayNetProfit >= 0 ? const Color(0xFF059669) : Colors.red,
                          ),
                        ),
                        const Divider(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                const Text('Tổng Doanh Thu'),
                                Text(formatMoney(dayRevenue),
                                    style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            Column(
                              children: [
                                const Text('Tổng Chi Phí'),
                                Text(formatMoney(dayExpenses),
                                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('Tổng số đơn trong ngày: ${orders.length}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 8),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: orders.length,
                    itemBuilder: (ctx, idx) {
                      final order = orders[idx];
                      return ListTile(
                        dense: true,
                        title: Text('Đơn #${order['id']}'),
                        subtitle: Text(order['timestamp'].toString().substring(11, 16)),
                        trailing: Text(formatMoney(double.tryParse(order['total'].toString()) ?? 0),
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                      );
                    },
                  )
                ],
              ),
            ),
    );
  }
}

// ------------------- 4. MÀN HÌNH BẢO MẬT NHẬT KÝ THAO TÁC ĐƠN (PIN 000) -------------------
class SecureLogsScreen extends StatefulWidget {
  const SecureLogsScreen({super.key});

  @override
  State<SecureLogsScreen> createState() => _SecureLogsScreenState();
}

class _SecureLogsScreenState extends State<SecureLogsScreen> {
  final pinController = TextEditingController();
  List<Map<String, dynamic>> logs = [];
  bool unlocked = LocalStorageService.isUnlocked;

  @override
  void initState() {
    super.initState();
    if (unlocked) _loadLogs();
  }

  Future<void> _loadLogs() async {
    final data = await LocalStorageService.fetchLogs();
    setState(() => logs = List<Map<String, dynamic>>.from(data));
  }

  void _verifyCode() {
    if (LocalStorageService.verifyCode(pinController.text.trim())) {
      setState(() => unlocked = true);
      _loadLogs();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mã PIN không đúng! Vui lòng nhập lại.'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!unlocked) {
      return Scaffold(
        appBar: AppBar(title: const Text('Bảo Mật Thao Tác Đơn')),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 64, color: Color(0xFF0D9488)),
              const SizedBox(height: 16),
              const Text('Nhập mã CODE (Mã mặc định: 000) để xem dữ liệu thao tác đơn hàng:',
                  textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: pinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, letterSpacing: 8),
                decoration: const InputDecoration(hintText: '***'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9488),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: _verifyCode,
                child: const Text('XÁC NHẬN MÃ CODE'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch Sử Thao Tác Đơn Hàng'),
        actions: [
          IconButton(
            icon: const Icon(Icons.lock),
            onPressed: () {
              setState(() {
                LocalStorageService.isUnlocked = false;
                unlocked = false;
              });
            },
          )
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: logs.length,
        itemBuilder: (ctx, index) {
          final log = logs[logs.length - 1 - index];
          return ListTile(
            dense: true,
            leading: const Icon(Icons.history, color: Color(0xFF0D9488)),
            title: Text(log['detail'] ?? ''),
            subtitle: Text(log['time'] ?? ''),
          );
        },
      ),
    );
  }
}

