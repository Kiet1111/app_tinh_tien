// lib/main.dart

import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

// Hàm định dạng tiền tệ Việt Nam (VD: 170000 -> 170.000đ)
String formatMoney(double amount) {
  String str = amount.toStringAsFixed(0);
  RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
  return '${str.replaceAllMapped(reg, (Match m) => '${m[1]}.')}đ';
}

// ------------------- LỚP XỬ LÝ DỮ LIỆU ĐỘC LẬP (LOCAL STORAGE) -------------------
class LocalStorageService {
  // Danh sách danh mục món ăn
  static final List<String> _categories = [
    'Tất cả',
    'Đồ Uống',
    'Đồ Ăn',
    'Đồ Cân',
  ];

  // Danh sách thực đơn mẫu kèm Biến thể & Topping
  static final List<Map<String, dynamic>> _menuList = [
    {
      'id': '1',
      'name': 'Cà Phê Sữa Đá',
      'category': 'Đồ Uống',
      'price': 25000.0,
      'unit': 'ly',
      'stock': 50.0,
      'variants': [
        {'name': 'Ít đường', 'price': 25000.0},
        {'name': 'Nhiều sữa', 'price': 28000.0}
      ],
      'toppings': [
        {'name': 'Trân châu đen', 'price': 5000.0},
        {'name': 'Pudding trứng', 'price': 7000.0},
        {'name': 'Kem cheese', 'price': 10000.0},
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
        {'name': 'Trân châu 3Q', 'price': 5000.0},
        {'name': 'Thạch trái cây', 'price': 5000.0},
      ]
    },
    {
      'id': '3',
      'name': 'Bánh Mì Thịt',
      'category': 'Đồ Ăn',
      'price': 30000.0,
      'unit': 'ổ',
      'stock': 20.0,
      'variants': [],
      'toppings': [
        {'name': 'Thêm trứng ốp la', 'price': 5000.0},
        {'name': 'Thêm chả lụa', 'price': 7000.0},
      ]
    },
    {
      'id': '4',
      'name': 'Hủ Tếu Nam Vang',
      'category': 'Đồ Ăn',
      'price': 45000.0,
      'unit': 'tô',
      'stock': 15.0,
      'variants': [],
      'toppings': [
        {'name': 'Thêm tôm', 'price': 10000.0},
        {'name': 'Thêm trứng cút', 'price': 5000.0},
      ]
    },
    {
      'id': '5',
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
      'time': DateTime.now().toString().substring(0, 16)
    }
  ];

  // QUẢN LÝ DANH MỤC
  static Future<List<String>> fetchCategories() async {
    return List<String>.from(_categories);
  }

  static Future<void> addCategory(String categoryName) async {
    if (!_categories.contains(categoryName)) {
      _categories.add(categoryName);
      _logs.add({
        'detail': 'Thêm danh mục mới: $categoryName',
        'time': DateTime.now().toString().substring(0, 16)
      });
    }
  }

  static Future<void> deleteCategory(String categoryName) async {
    if (categoryName != 'Tất cả') {
      _categories.remove(categoryName);
      _logs.add({
        'detail': 'Xóa danh mục: $categoryName',
        'time': DateTime.now().toString().substring(0, 16)
      });
    }
  }

  // QUẢN LÝ MÓN ÁN
  static Future<List<Map<String, dynamic>>> fetchMenu() async {
    return List<Map<String, dynamic>>.from(_menuList);
  }

  static Future<void> addMenuItem(Map<String, dynamic> item) async {
    item['id'] = DateTime.now().millisecondsSinceEpoch.toString();
    _menuList.add(item);
    _logs.add({
      'detail': 'Thêm món mới: ${item['name']}',
      'time': DateTime.now().toString().substring(0, 16)
    });
  }

  static Future<void> updateMenuItem(Map<String, dynamic> item) async {
    int idx = _menuList.indexWhere((e) => e['id'].toString() == item['id'].toString());
    if (idx != -1) {
      _menuList[idx] = item;
      _logs.add({
        'detail': 'Cập nhật món: ${item['name']}',
        'time': DateTime.now().toString().substring(0, 16)
      });
    }
  }

  static Future<void> deleteMenuItem(String id) async {
    int idx = _menuList.indexWhere((e) => e['id'].toString() == id);
    if (idx != -1) {
      String name = _menuList[idx]['name'];
      _menuList.removeAt(idx);
      _logs.add({
        'detail': 'Xóa món: $name',
        'time': DateTime.now().toString().substring(0, 16)
      });
    }
  }

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
    _logs.add({
      'detail': 'Thanh toán thành công đơn ${formatMoney(order['total'] ?? 0)}',
      'time': DateTime.now().toString().substring(0, 16)
    });
    return true;
  }

  static Future<List<Map<String, dynamic>>> fetchOrders() async {
    return List<Map<String, dynamic>>.from(_orders);
  }

  static Future<List<Map<String, dynamic>>> fetchExpenses() async {
    return List<Map<String, dynamic>>.from(_expenses);
  }

  static Future<void> addExpense(String category, double amount, String note) async {
    _expenses.add({
      'category': category,
      'amount': amount,
      'note': note,
      'timestamp': DateTime.now().toIso8601String(),
    });
    _logs.add({
      'detail': 'Thêm chi phí [$category]: ${formatMoney(amount)}',
      'time': DateTime.now().toString().substring(0, 16)
    });
  }

  static Future<List<Map<String, dynamic>>> fetchLogs() async {
    return List<Map<String, dynamic>>.from(_logs);
  }
}

// ------------------- CẤU HÌNH GIAO DIỆN CHÍNH -------------------
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'POS Bán Hàng',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0D9488),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
        ),
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
    const FinancialReportScreen(),
    const LogsScreen(),
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
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart, color: Color(0xFF0D9488)),
            label: 'Báo Cáo',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history, color: Color(0xFF0D9488)),
            label: 'Nhật Ký',
          ),
        ],
      ),
    );
  }
}

// ------------------- 1. MÀN HÌNH BÁN HÀNG -------------------
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

    List rawVariants = dish['variants'] ?? [];
    List<Map<String, dynamic>> variants =
        rawVariants.map((v) => Map<String, dynamic>.from(v)).toList();

    List rawToppings = dish['toppings'] ?? [];
    List<Map<String, dynamic>> toppings =
        rawToppings.map((t) => Map<String, dynamic>.from(t)).toList();

    Map<String, dynamic>? selectedVariant =
        variants.isNotEmpty ? variants.first : null;
    List<Map<String, dynamic>> selectedToppings = [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            double currentUnitPrice = selectedVariant != null
                ? (double.tryParse(selectedVariant!['price'].toString()) ?? 0.0)
                : baseUnitPrice;

            // Tính tổng tiền Toppings đã chọn
            double toppingTotal = selectedToppings.fold(0.0, (sum, t) {
              return sum + (double.tryParse(t['price'].toString()) ?? 0.0);
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

            double totalPrice = (currentUnitPrice + toppingTotal) * calculatedQty;

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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(dish['name'],
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
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
                      const Text('Chọn nhanh khối lượng:',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          ...[100, 200, 300, 500].map((g) {
                            return ActionChip(
                              label: Text('+$g g'),
                              onPressed: () {
                                double current =
                                    double.tryParse(weightGramController.text) ?? 0;
                                weightGramController.text =
                                    (current + g).toStringAsFixed(0);
                                qtyController.clear();
                                setModalState(() {});
                              },
                            );
                          }),
                          ActionChip(
                            label: const Text('1 kg'),
                            onPressed: () {
                              qtyController.text = '1';
                              weightGramController.clear();
                              setModalState(() {});
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: weightGramController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Số Gram (VD: 110)',
                                suffixText: 'g',
                                isDense: true,
                              ),
                              onChanged: (_) {
                                qtyController.clear();
                                setModalState(() {});
                              },
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Text('HOẶC', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          ),
                          Expanded(
                            child: TextField(
                              controller: qtyController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Số Kg (VD: 0.35)',
                                suffixText: 'kg',
                                isDense: true,
                              ),
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
                            width: 90,
                            child: TextField(
                              controller: qtyController,
                              textAlign: TextAlign.center,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
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

                    if (variants.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Text('Chọn Biến Thể:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Wrap(
                        spacing: 8,
                        children: variants.map((v) {
                          bool isSel = selectedVariant == v;
                          return ChoiceChip(
                            label: Text('${v['name']} (${formatMoney(double.tryParse(v['price'].toString()) ?? 0)})'),
                            selected: isSel,
                            onSelected: (val) {
                              if (val) setModalState(() => selectedVariant = v);
                            },
                          );
                        }).toList(),
                      ),
                    ],

                    // PHẦN CHỌN TOPPING
                    if (toppings.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Text('Chọn Topping kềnh thêm:',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D9488))),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        children: toppings.map((t) {
                          bool isSel = selectedToppings.any((item) => item['name'] == t['name']);
                          double tPrice = double.tryParse(t['price'].toString()) ?? 0.0;
                          return FilterChip(
                            selectedColor: const Color(0xFFCCFBF1),
                            checkmarkColor: const Color(0xFF0D9488),
                            label: Text('${t['name']} (+${formatMoney(tPrice)})'),
                            selected: isSel,
                            onSelected: (val) {
                              setModalState(() {
                                if (val) {
                                  selectedToppings.add(t);
                                } else {
                                  selectedToppings.removeWhere((item) => item['name'] == t['name']);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],

                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D9488),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: calculatedQty <= 0
                            ? null
                            : () {
                                String displayQty = isWeightUnit
                                    ? (calculatedQty < 1
                                        ? '${(calculatedQty * 1000).toStringAsFixed(0)}g'
                                        : '${calculatedQty.toStringAsFixed(2)}kg')
                                    : '${calculatedQty.toInt()} $unit';

                                String fullName = dish['name'];
                                if (selectedVariant != null) {
                                  fullName += ' (${selectedVariant!['name']})';
                                }
                                if (selectedToppings.isNotEmpty) {
                                  String topNames = selectedToppings.map((t) => t['name']).join(', ');
                                  fullName += ' + [$topNames]';
                                }

                                setState(() {
                                  currentOrder.add({
                                    'dishId': dish['id'],
                                    'name': fullName,
                                    'price': currentUnitPrice + toppingTotal,
                                    'qty': calculatedQty,
                                    'displayQty': displayQty,
                                    'totalPrice': totalPrice,
                                  });
                                });
                                Navigator.pop(ctx);
                              },
                        child: Text(
                          'THÊM VÀO ĐƠN • ${formatMoney(totalPrice)}',
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

  void _showCartBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setCartState) => Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Chi Tiết Đơn Hàng (${currentOrder.length} món)',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    TextButton(
                      onPressed: () {
                        setState(() => currentOrder.clear());
                        Navigator.pop(ctx);
                      },
                      child: const Text('Xóa tất cả',
                          style: TextStyle(color: Colors.red)),
                    )
                  ],
                ),
                const Divider(),
                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: currentOrder.length,
                    itemBuilder: (ctx, idx) {
                      final item = currentOrder[idx];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(item['name'],
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: Text('SL: ${item['displayQty']}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              formatMoney(item['totalPrice']),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close,
                                  color: Colors.grey, size: 18),
                              onPressed: () {
                                setCartState(() {
                                  currentOrder.removeAt(idx);
                                });
                                setState(() {});
                                if (currentOrder.isEmpty) Navigator.pop(ctx);
                              },
                            )
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('TỔNG CỘNG:',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(formatMoney(totalAmount),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                            color: Color(0xFF0D9488))),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D9488),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _submitOrder();
                    },
                    child: const Text('XÁC NHẬN THANH TOÁN',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  void _submitOrder() async {
    if (currentOrder.isEmpty) return;

    final orderData = {
      'timestamp': DateTime.now().toIso8601String(),
      'total': totalAmount,
      'items': List<Map<String, dynamic>>.from(currentOrder),
    };

    bool isSaved = await LocalStorageService.saveOrder(orderData);
    if (mounted && isSaved) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isOnline
              ? 'Thanh toán thành công (Online)!'
              : 'Thanh toán thành công (Lưu Offline)!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
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
        titleSpacing: 12,
        title: SizedBox(
          height: 38,
          child: TextField(
            onChanged: (val) => setState(() => searchQuery = val),
            decoration: InputDecoration(
              hintText: 'Tìm nhanh món...',
              hintStyle: const TextStyle(fontSize: 13),
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
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                setState(() => isOnline = !isOnline);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isOnline ? Colors.green.shade50 : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: isOnline ? Colors.green : Colors.orange),
                ),
                child: Row(
                  children: [
                    Icon(
                      isOnline ? Icons.wifi : Icons.wifi_off,
                      size: 14,
                      color: isOnline ? Colors.green : Colors.orange.shade900,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isOnline ? 'ONLINE' : 'OFFLINE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isOnline ? Colors.green : Colors.orange.shade900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
                    labelStyle: TextStyle(
                      fontSize: 12,
                      color: isSelected ? Colors.white : Colors.black87,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    label: Text(cat),
                    selected: isSelected,
                    selectedColor: const Color(0xFF0D9488),
                    onSelected: (val) {
                      if (val) setState(() => selectedCategory = cat);
                    },
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 4),
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
                      double price =
                          double.tryParse(dish['price'].toString()) ?? 0.0;
                      double stock =
                          double.tryParse(dish['stock'].toString()) ?? 0.0;
                      String unit = dish['unit'] ?? 'phần';

                      Color stockColor = stock > 10
                          ? Colors.teal
                          : (stock > 0 ? Colors.orange : Colors.red);

                      return Card(
                        clipBehavior: Clip.antiAlias,
                        color: stock <= 0 ? Colors.grey.shade100 : Colors.white,
                        child: InkWell(
                          onTap: stock <= 0
                              ? null
                              : () => _openQuantityModal(dish),
                          child: Padding(
                            padding: const EdgeInsets.all(6.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  dish['name'],
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: stock <= 0 ? Colors.grey : Colors.black87,
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      formatMoney(price),
                                      style: const TextStyle(
                                        color: Color(0xFF0D9488),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: stockColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        stock <= 0
                                            ? 'Hết hàng'
                                            : 'Kho: ${stock.toInt()} $unit',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: stockColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  )
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    InkWell(
                      onTap: _showCartBottomSheet,
                      child: Row(
                        children: [
                          Badge(
                            label: Text('${currentOrder.length}'),
                            child: const Icon(Icons.shopping_bag_outlined,
                                color: Color(0xFF0D9488), size: 28),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('TỔNG ĐƠN',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey,
                                      fontWeight: FontWeight.bold)),
                              Text(
                                formatMoney(totalAmount),
                                style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0D9488)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D9488),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _submitOrder,
                      child: const Text('THANH TOÁN',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

// ------------------- 2. MÀN HÌNH QUẢN LÝ THỰC ĐƠN, DANH MỤC & TOPPING -------------------
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

  // DIALOG QUẢN LÝ DANH MỤC
  void _showCategoryManagerDialog() {
    final catCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: const Text('Quản Lý Danh Mục Món',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: catCtrl,
                      decoration: const InputDecoration(
                          hintText: 'Tên danh mục mới (VD: Ăn Vặt)',
                          isDense: true),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: Color(0xFF0D9488)),
                    onPressed: () async {
                      if (catCtrl.text.trim().isNotEmpty) {
                        await LocalStorageService.addCategory(catCtrl.text.trim());
                        catCtrl.clear();
                        final updated = await LocalStorageService.fetchCategories();
                        setDlgState(() => categories = updated);
                        _loadMenuData();
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 180,
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: categories.length,
                  itemBuilder: (c, idx) {
                    String cat = categories[idx];
                    if (cat == 'Tất cả') return const SizedBox.shrink();
                    return ListTile(
                      dense: true,
                      title: Text(cat),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                        onPressed: () async {
                          await LocalStorageService.deleteCategory(cat);
                          final updated = await LocalStorageService.fetchCategories();
                          setDlgState(() => categories = updated);
                          _loadMenuData();
                        },
                      ),
                    );
                  },
                ),
              )
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('Đóng'))
          ],
        ),
      ),
    );
  }

  // DIALOG THÊM / SỬA MÓN (BAO GỒM CỦA CẢ TOPPING)
  void _showItemFormDialog([Map<String, dynamic>? existingItem]) {
    final bool isEdit = existingItem != null;

    final nameCtrl = TextEditingController(text: isEdit ? existingItem['name'] : '');
    String selectedCat = isEdit
        ? existingItem['category']
        : (categories.length > 1 ? categories[1] : 'Khác');
    if (!categories.contains(selectedCat)) selectedCat = categories.first;

    final priceCtrl = TextEditingController(
        text: isEdit ? existingItem['price'].toString() : '');
    final unitCtrl = TextEditingController(
        text: isEdit ? (existingItem['unit'] ?? 'phần') : 'phần');
    final stockCtrl = TextEditingController(
        text: isEdit ? (existingItem['stock'] ?? 100).toString() : '100');

    // Danh sách Toppings tạm thời
    List<Map<String, dynamic>> tempToppings = isEdit
        ? List<Map<String, dynamic>>.from(existingItem['toppings'] ?? [])
        : [];

    final toppingNameCtrl = TextEditingController();
    final toppingPriceCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: Text(isEdit ? 'Chỉnh Sửa Món' : 'Thêm Món Mới',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Tên món'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedCat,
                  decoration: const InputDecoration(labelText: 'Danh mục'),
                  items: categories
                      .where((c) => c != 'Tất cả')
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setDlgState(() => selectedCat = val);
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: priceCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Giá gốc'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: unitCtrl,
                        decoration: const InputDecoration(labelText: 'Đơn vị (ly, kg, tô...)'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: stockCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Số lượng tồn kho'),
                ),
                
                const Divider(height: 24),
                const Text('Cấu hình Topping đi kèm:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0D9488))),
                const SizedBox(height: 6),
                
                // Form thêm topping nhỏ
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: toppingNameCtrl,
                        decoration: const InputDecoration(hintText: 'Tên Topping', isDense: true),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: toppingPriceCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(hintText: 'Giá Topping', isDense: true),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_box, color: Color(0xFF0D9488)),
                      onPressed: () {
                        String tName = toppingNameCtrl.text.trim();
                        double tPrice = double.tryParse(toppingPriceCtrl.text) ?? 0.0;
                        if (tName.isNotEmpty) {
                          setDlgState(() {
                            tempToppings.add({'name': tName, 'price': tPrice});
                            toppingNameCtrl.clear();
                            toppingPriceCtrl.clear();
                          });
                        }
                      },
                    )
                  ],
                ),
                const SizedBox(height: 6),
                
                // Hiển thị danh sách Topping đã tạo
                Wrap(
                  spacing: 6,
                  children: tempToppings.map((t) {
                    return Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text('${t['name']} (+${formatMoney(double.tryParse(t['price'].toString()) ?? 0)})',
                          style: const TextStyle(fontSize: 11)),
                      onDeleted: () {
                        setDlgState(() {
                          tempToppings.remove(t);
                        });
                      },
                    );
                  }).toList(),
                )
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9488),
                  foregroundColor: Colors.white),
              onPressed: () async {
                String name = nameCtrl.text.trim();
                if (name.isEmpty) return;

                Map<String, dynamic> itemData = {
                  'id': isEdit ? existingItem['id'] : null,
                  'name': name,
                  'category': selectedCat,
                  'price': double.tryParse(priceCtrl.text) ?? 0.0,
                  'unit': unitCtrl.text.trim().isEmpty ? 'phần' : unitCtrl.text.trim(),
                  'stock': double.tryParse(stockCtrl.text) ?? 0.0,
                  'variants': isEdit ? existingItem['variants'] : [],
                  'toppings': tempToppings,
                };

                Navigator.pop(ctx);
                if (isEdit) {
                  await LocalStorageService.updateMenuItem(itemData);
                } else {
                  await LocalStorageService.addMenuItem(itemData);
                }
                _loadMenuData();
              },
              child: Text(isEdit ? 'Lưu' : 'Thêm'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản Lý Thực Đơn'),
        actions: [
          TextButton.icon(
            onPressed: _showCategoryManagerDialog,
            icon: const Icon(Icons.category, size: 18, color: Color(0xFF0D9488)),
            label: const Text('Danh Mục', style: TextStyle(color: Color(0xFF0D9488))),
          )
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF0D9488),
        foregroundColor: Colors.white,
        onPressed: () => _showItemFormDialog(),
        child: const Icon(Icons.add),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              itemCount: menuList.length,
              itemBuilder: (ctx, index) {
                final item = menuList[index];
                double price = double.tryParse(item['price'].toString()) ?? 0;
                double stock = double.tryParse(item['stock'].toString()) ?? 0;
                List toppings = item['toppings'] ?? [];

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    dense: true,
                    title: Text('${item['name']} [${item['category']}]',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Giá: ${formatMoney(price)} / ${item['unit']} | Tồn: $stock'),
                        if (toppings.isNotEmpty)
                          Text(
                            'Topping: ${toppings.map((t) => t['name']).join(', ')}',
                            style: const TextStyle(fontSize: 10, color: Color(0xFF0D9488)),
                          ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20, color: Colors.blue),
                          onPressed: () => _showItemFormDialog(item),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                          onPressed: () async {
                            await LocalStorageService.deleteMenuItem(
                                item['id'].toString());
                            _loadMenuData();
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// ------------------- 3. MÀN HÌNH BÁO CÁO TÀI CHÍNH -------------------
class FinancialReportScreen extends StatefulWidget {
  const FinancialReportScreen({super.key});

  @override
  State<FinancialReportScreen> createState() => _FinancialReportScreenState();
}

class _FinancialReportScreenState extends State<FinancialReportScreen> {
  int selectedPeriodDays = 1;

  List<Map<String, dynamic>> orders = [];
  List<Map<String, dynamic>> expenses = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFinancialData();
  }

  Future<void> _loadFinancialData() async {
    setState(() => isLoading = true);
    final oData = await LocalStorageService.fetchOrders();
    final eData = await LocalStorageService.fetchExpenses();
    setState(() {
      orders = List<Map<String, dynamic>>.from(oData);
      expenses = List<Map<String, dynamic>>.from(eData);
      isLoading = false;
    });
  }

  bool _isWithinPeriod(String isoTimeString) {
    DateTime? date = DateTime.tryParse(isoTimeString);
    if (date == null) return false;
    DateTime now = DateTime.now();
    DateTime threshold = now.subtract(Duration(days: selectedPeriodDays));
    return date.isAfter(threshold);
  }

  double get filteredRevenue {
    return orders.where((o) => _isWithinPeriod(o['timestamp'] ?? '')).fold(
        0.0,
        (sum, item) =>
            sum + (double.tryParse(item['total'].toString()) ?? 0.0));
  }

  double get filteredExpenses {
    return expenses.where((e) => _isWithinPeriod(e['timestamp'] ?? '')).fold(
        0.0,
        (sum, item) =>
            sum + (double.tryParse(item['amount'].toString()) ?? 0.0));
  }

  double get netProfit => filteredRevenue - filteredExpenses;

  void _showAddExpenseDialog() {
    String category = 'Gas';
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: const Text('Nhập Chi Phí', style: TextStyle(fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: category,
                decoration: const InputDecoration(labelText: 'Loại chi phí'),
                items: ['Gas', 'Tiền điện', 'Tiền nhà', 'Nhập hàng', 'Khác']
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setDlgState(() => category = val);
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Số tiền (VNĐ)'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(labelText: 'Ghi chú'),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9488),
                  foregroundColor: Colors.white),
              onPressed: () async {
                double amt = double.tryParse(amountCtrl.text) ?? 0.0;
                if (amt > 0) {
                  Navigator.pop(ctx);
                  await LocalStorageService.addExpense(
                      category, amt, noteCtrl.text.trim());
                  _loadFinancialData();
                }
              },
              child: const Text('Lưu'),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Báo Cáo Tài Chính')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment<int>(value: 1, label: Text('Hôm nay')),
                      ButtonSegment<int>(value: 7, label: Text('7 ngày')),
                      ButtonSegment<int>(value: 30, label: Text('30 ngày')),
                    ],
                    selected: {selectedPeriodDays},
                    onSelectionChanged: (Set<int> set) {
                      setState(() => selectedPeriodDays = set.first);
                    },
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: netProfit >= 0
                          ? const Color(0xFFECFDF5)
                          : const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: netProfit >= 0
                            ? const Color(0xFF10B981)
                            : const Color(0xFFEF4444),
                      ),
                    ),
                    child: Column(
                      children: [
                        const Text('LỢI NHUẬN RÒNG',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey)),
                        const SizedBox(height: 4),
                        Text(
                          formatMoney(netProfit),
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: netProfit >= 0
                                ? const Color(0xFF059669)
                                : Colors.red,
                          ),
                        ),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                const Text('Doanh Thu (+)',
                                    style: TextStyle(fontSize: 11)),
                                Text(formatMoney(filteredRevenue),
                                    style: const TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14)),
                              ],
                            ),
                            Column(
                              children: [
                                const Text('Chi Phí (-)',
                                    style: TextStyle(fontSize: 11)),
                                Text(formatMoney(filteredExpenses),
                                    style: const TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14)),
                              ],
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(42),
                      side: const BorderSide(color: Colors.red),
                    ),
                    onPressed: _showAddExpenseDialog,
                    icon: const Icon(Icons.remove_circle_outline,
                        color: Colors.red, size: 18),
                    label: const Text('NHẬP CHI PHÍ (GAS, ĐIỆN, NHÀ, HÀNG)',
                        style: TextStyle(color: Colors.red, fontSize: 12)),
                  ),
                  const SizedBox(height: 16),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Lịch sử chi phí',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                  const SizedBox(height: 6),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: expenses.length,
                    itemBuilder: (ctx, index) {
                      final exp = expenses[expenses.length - 1 - index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 3),
                        child: ListTile(
                          dense: true,
                          title: Text('[${exp['category']}] ${exp['note']}'),
                          subtitle: Text(exp['timestamp'].toString().substring(0, 10)),
                          trailing: Text(
                            '-${formatMoney(double.tryParse(exp['amount'].toString()) ?? 0)}',
                            style: const TextStyle(
                                color: Colors.red, fontWeight: FontWeight.bold),
                          ),
                        ),
                      );
                    },
                  )
                ],
              ),
            ),
    );
  }
}

// ------------------- 4. MÀN HÌNH NHẬT KÝ THAO TÁC -------------------
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
      appBar: AppBar(title: const Text('Nhật Ký Thao Tác')),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: logs.length,
        itemBuilder: (ctx, index) {
          final log = logs[logs.length - 1 - index];
          return ListTile(
            dense: true,
            leading: const Icon(Icons.history, color: Color(0xFF0D9488), size: 20),
            title: Text(log['detail'] ?? '', style: const TextStyle(fontSize: 13)),
            subtitle: Text(log['time'] ?? '', style: const TextStyle(fontSize: 10)),
          );
        },
      ),
    );
  }
}

