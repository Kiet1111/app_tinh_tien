// lib/main.dart

import 'dart:math';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalStorageService.initDeviceId();
  runApp(const MyApp());
}

// Định dạng tiền tệ VNĐ
String formatMoney(double amount) {
  String str = amount.toStringAsFixed(0);
  RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
  return '${str.replaceAllMapped(reg, (Match m) => '${m[1]}.')}đ';
}

// ------------------- QUẢN LÝ DỮ LIỆU & PHÂN QUYỀN -------------------
class LocalStorageService {
  static const String masterCode = "000"; // Mã PIN Master
  static String myDeviceId = ""; // Mã định danh của thiết bị hiện tại

  // Khởi tạo Mã Định Danh cho thiết bị
  static Future<void> initDeviceId() async {
    if (myDeviceId.isEmpty) {
      final random = Random();
      int code = 1000 + random.nextInt(9000);
      myDeviceId = "DEV-$code";
    }
    // Mặc định cấp full quyền cho máy đầu tiên để tiện thử nghiệm
    if (!_devicePermissions.containsKey(myDeviceId)) {
      _devicePermissions[myDeviceId] = {
        'viewOrderHistory': true,
        'viewLogs': true,
        'createItem': true,
        'isAdmin': true,
      };
    }
  }

  // Cấu trúc lưu trữ quyền theo Mã Định Danh Thiết Bị (Device ID)
  static final Map<String, Map<String, bool>> _devicePermissions = {};

  // Kiểm tra thiết bị có quyền cụ thể hay không
  static bool hasPermission(String permKey, {String? deviceId}) {
    String targetDev = deviceId ?? myDeviceId;
    var perms = _devicePermissions[targetDev];
    if (perms == null) return false;
    // Nếu có quyền Admin thì tự động có tất cả các quyền khác
    if (perms['isAdmin'] == true) return true;
    return perms[permKey] == true;
  }

  // Admin Cấp hoặc Thu hồi quyền của một Device ID
  static void togglePermission(String targetDeviceId, String permKey, bool value) {
    if (!_devicePermissions.containsKey(targetDeviceId)) {
      _devicePermissions[targetDeviceId] = {
        'viewOrderHistory': false,
        'viewLogs': false,
        'createItem': false,
        'isAdmin': false,
      };
    }
    _devicePermissions[targetDeviceId]![permKey] = value;
    _addLog('Admin đã ${value ? "cấp" : "thu hồi"} quyền [$permKey] cho thiết bị $targetDeviceId');
  }

  static Map<String, Map<String, bool>> getAllPermissions() => _devicePermissions;

  // --- DỮ LIỆU THỰC ĐƠN & ĐƠN HÀNG ---
  static final List<String> _categories = ['Tất cả', 'Đồ Uống', 'Đồ Ăn', 'Đồ Cân'];

  static final List<Map<String, dynamic>> _menuList = [
    {
      'id': '1',
      'name': 'Cà Phê Sữa Đá',
      'category': 'Đồ Uống',
      'price': 25000.0,
      'unit': 'ly',
      'stock': 50.0,
      'toppings': [
        {'name': 'Trân châu đen', 'price': 5000.0},
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
      'toppings': [
        {'name': 'Trân châu 3Q', 'price': 5000.0},
        {'name': 'Pudding trứng', 'price': 7000.0},
      ]
    },
    {
      'id': '3',
      'name': 'Dừa Nạo Sợi',
      'category': 'Đồ Cân',
      'price': 60000.0,
      'unit': 'kg',
      'stock': 10.0,
      'toppings': []
    },
  ];

  static final List<Map<String, dynamic>> _orders = [];
  static final List<Map<String, dynamic>> _logs = [
    {
      'detail': 'Khởi động ứng dụng POS - Thiết bị: $myDeviceId',
      'time': DateTime.now().toString().substring(0, 16),
    }
  ];

  static Future<List<String>> fetchCategories() async => List<String>.from(_categories);
  static Future<List<Map<String, dynamic>>> fetchMenu() async => List<Map<String, dynamic>>.from(_menuList);

  // THÊM MÓN (Cần quyền hoặc mã PIN)
  static Future<void> addMenuItem(Map<String, dynamic> item) async {
    item['id'] = DateTime.now().millisecondsSinceEpoch.toString();
    _menuList.add(item);
    _addLog('Tạo món mới: ${item['name']} bởi $myDeviceId');
  }

  // TẠO ĐƠN HÀNG (Không cần mã PIN)
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
    _addLog('Tạo đơn #${order['id']} (${formatMoney(order['total'] ?? 0)})');
    return true;
  }

  // XÓA ĐƠN HÀNG (Không cần mã PIN)
  static Future<void> deleteOrder(String orderId) async {
    _orders.removeWhere((o) => o['id'].toString() == orderId.toString());
    _addLog('Đã xóa đơn hàng #$orderId');
  }

  static Future<List<Map<String, dynamic>>> fetchOrders() async => List<Map<String, dynamic>>.from(_orders);
  static Future<List<Map<String, dynamic>>> fetchLogs() async => List<Map<String, dynamic>>.from(_logs);

  static void _addLog(String detail) {
    _logs.add({
      'detail': detail,
      'time': DateTime.now().toString().substring(0, 16),
    });
  }

  static bool verifyMasterCode(String code) => code == masterCode;
}

// ------------------- GIAO DIỆN CHÍNH -------------------
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'POS Phân Quyền Thiết Bị',
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
    const HistoryAndLogsScreen(),
    const AdminPermissionScreen(),
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
            label: 'Lợi Nhuận',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history, color: Color(0xFF0D9488)),
            label: 'Lịch Sử',
          ),
          NavigationDestination(
            icon: Icon(Icons.admin_panel_settings_outlined),
            selectedIcon: Icon(Icons.admin_panel_settings, color: Color(0xFF0D9488)),
            label: 'Cấp Quyền',
          ),
        ],
      ),
    );
  }
}

// ------------------- 1. MÀN HÌNH BÁN HÀNG (+/- TOPPING, KHÔNG CẦN PIN) -------------------
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

  double get totalAmount => currentOrder.fold(0.0, (sum, item) => sum + (item['totalPrice'] as double));

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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            double toppingTotal = toppingList.fold(0.0, (sum, t) => sum + (t['price'] as double) * (t['qty'] as int));

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
                          child: Text(dish['name'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                        Text('${formatMoney(baseUnitPrice)} / $unit',
                            style: const TextStyle(color: Color(0xFF0D9488), fontWeight: FontWeight.bold, fontSize: 16)),
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

                    if (toppingList.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text('Chọn Topping (+ / -):',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D9488))),
                      const SizedBox(height: 8),
                      ...toppingList.map((t) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${t['name']} (+${formatMoney(t['price'])})'),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 22),
                                    onPressed: t['qty'] > 0 ? () => setModalState(() => t['qty']--) : null,
                                  ),
                                  Text('${t['qty']}', style: const TextStyle(fontWeight: FontWeight.bold)),
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

  // TẠO ĐƠN HÀNG - KHÔNG YÊU CẦU MÃ PIN
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
        const SnackBar(content: Text('Tạo đơn hàng thành công! (Không cần mã PIN)'), backgroundColor: Colors.green),
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
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(isOnline ? Icons.wifi : Icons.wifi_off, color: isOnline ? Colors.green : Colors.orange),
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
                      return Card(
                        child: InkWell(
                          onTap: () => _openQuantityModal(dish),
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
                                    style: const TextStyle(color: Color(0xFF0D9488), fontWeight: FontWeight.bold, fontSize: 12)),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (currentOrder.isNotEmpty) ...[
            Container(
              color: Colors.white,
              child: Column(
                children: [
                  const Divider(height: 1),
                  ListTile(
                    title: Text('Đơn hàng hiện tại (${currentOrder.length} món)'),
                    subtitle: Text('Tạo & Xóa món không cần nhập mã', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    trailing: TextButton.icon(
                      icon: const Icon(Icons.delete_sweep, color: Colors.red),
                      label: const Text('Xóa hết đơn', style: TextStyle(color: Colors.red)),
                      onPressed: () => setState(() => currentOrder.clear()), // XÓA ĐƠN KHÔNG CẦN PIN
                    ),
                  ),
                ],
              ),
            )
          ]
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
                child: Text('TẠO ĐƠN HÀNG • ${formatMoney(totalAmount)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
    );
  }
}

// ------------------- 2. THỰC ĐƠN (CẦN QUYỀN TẠO MÓN HOẶC MÃ PIN 000) -------------------
class MenuManagementScreen extends StatefulWidget {
  const MenuManagementScreen({super.key});

  @override
  State<MenuManagementScreen> createState() => _MenuManagementScreenState();
}

class _MenuManagementScreenState extends State<MenuManagementScreen> {
  List<Map<String, dynamic>> menuList = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMenuData();
  }

  Future<void> _loadMenuData() async {
    setState(() => isLoading = true);
    final data = await LocalStorageService.fetchMenu();
    setState(() {
      menuList = List<Map<String, dynamic>>.from(data);
      isLoading = false;
    });
  }

  // KIỂM TRẢ QUYỀN TRƯỚC KHI TẠO MÓN
  void _addNewItemProcess() {
    bool canCreateDirectly = LocalStorageService.hasPermission('createItem');

    if (canCreateDirectly) {
      _showCreateItemModal();
    } else {
      // Nếu chưa được cấp quyền -> Yêu cầu nhập mã PIN
      _showPinPromptDialog();
    }
  }

  void _showPinPromptDialog() {
    final pinController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Yêu cầu Mã PIN Tạo Món'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Thiết bị này chưa được cấp quyền Tạo Món. Vui lòng nhập mã PIN (000) để tiếp tục:'),
              const SizedBox(height: 12),
              TextField(
                controller: pinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, letterSpacing: 6),
                decoration: const InputDecoration(hintText: '***'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
            ElevatedButton(
              onPressed: () {
                if (LocalStorageService.verifyMasterCode(pinController.text.trim())) {
                  Navigator.pop(ctx);
                  _showCreateItemModal();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Mã PIN không đúng!'), backgroundColor: Colors.red),
                  );
                }
              },
              child: const Text('Xác nhận'),
            ),
          ],
        );
      },
    );
  }

  void _showCreateItemModal() {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    String category = 'Đồ Uống';
    String unit = 'ly';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            top: 16, left: 16, right: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Tạo Món Mới Vẫn Giữ Cấu Trúc', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Tên món')),
              TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Giá bán (VNĐ)'),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D9488), foregroundColor: Colors.white),
                  onPressed: () async {
                    if (nameController.text.isNotEmpty && priceController.text.isNotEmpty) {
                      await LocalStorageService.addMenuItem({
                        'name': nameController.text.trim(),
                        'category': category,
                        'price': double.tryParse(priceController.text) ?? 0.0,
                        'unit': unit,
                        'stock': 100.0,
                        'toppings': [
                          {'name': 'Topping Thêm 1', 'price': 5000.0}
                        ]
                      });
                      Navigator.pop(ctx);
                      _loadMenuData();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Tạo món thành công!'), backgroundColor: Colors.green),
                      );
                    }
                  },
                  child: const Text('LƯU MÓN MỚI'),
                ),
              )
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thực Đơn Món'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle, color: Color(0xFF0D9488), size: 28),
            onPressed: _addNewItemProcess, // Bấm vào để kiểm tra quyền / nhập PIN
          )
        ],
      ),
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

// ------------------- 3. MÀN HÌNH CHỐT LỢI NHUẬN CUỐI NGÀY -------------------
class EndOfDayReportScreen extends StatefulWidget {
  const EndOfDayReportScreen({super.key});

  @override
  State<EndOfDayReportScreen> createState() => _EndOfDayReportScreenState();
}

class _EndOfDayReportScreenState extends State<EndOfDayReportScreen> {
  DateTime selectedDate = DateTime.now();
  List<Map<String, dynamic>> orders = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final allOrders = await LocalStorageService.fetchOrders();
    String targetDateStr = selectedDate.toIso8601String().substring(0, 10);
    setState(() {
      orders = allOrders.where((o) => o['timestamp'].toString().startsWith(targetDateStr)).toList();
    });
  }

  double get dayRevenue => orders.fold(0.0, (sum, o) => sum + (double.tryParse(o['total'].toString()) ?? 0.0));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Báo Cáo Lợi Nhuận')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF10B981)),
              ),
              child: Column(
                children: [
                  const Text('TỔNG DOANH THU HÔM NAY', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 8),
                  Text(formatMoney(dayRevenue),
                      style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: orders.length,
                itemBuilder: (ctx, idx) {
                  final order = orders[idx];
                  return Card(
                    child: ListTile(
                      title: Text('Đơn hàng #${order['id']}'),
                      subtitle: Text(order['timestamp'].toString().substring(11, 16)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(formatMoney(double.tryParse(order['total'].toString()) ?? 0),
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () async {
                              // XÓA ĐƠN TRONG LỊCH SỬ - KHÔNG CẦN PIN
                              await LocalStorageService.deleteOrder(order['id'].toString());
                              _loadData();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Đã xóa đơn hàng thành công!')),
                              );
                            },
                          )
                        ],
                      ),
                    ),
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}

// ------------------- 4. MÀN HÌNH LỊCH SỬ ĐƠN & THAO TÁC (KIỂM TRẢ QUYỀN) -------------------
class HistoryAndLogsScreen extends StatefulWidget {
  const HistoryAndLogsScreen({super.key});

  @override
  State<HistoryAndLogsScreen> createState() => _HistoryAndLogsScreenState();
}

class _HistoryAndLogsScreenState extends State<HistoryAndLogsScreen> {
  List<Map<String, dynamic>> logs = [];
  List<Map<String, dynamic>> orders = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final l = await LocalStorageService.fetchLogs();
    final o = await LocalStorageService.fetchOrders();
    setState(() {
      logs = List<Map<String, dynamic>>.from(l);
      orders = List<Map<String, dynamic>>.from(o);
    });
  }

  @override
  Widget build(BuildContext context) {
    bool canViewOrders = LocalStorageService.hasPermission('viewOrderHistory');
    bool canViewLogs = LocalStorageService.hasPermission('viewLogs');

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Lịch Sử & Nhật Ký'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Lịch Sử Đơn Hàng'),
              Tab(text: 'Nhật Ký Thao Tác'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Tab 1: Lịch sử đơn hàng
            canViewOrders
                ? ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: orders.length,
                    itemBuilder: (ctx, idx) {
                      final order = orders[idx];
                      return ListTile(
                        leading: const Icon(Icons.receipt_long, color: Color(0xFF0D9488)),
                        title: Text('Đơn #${order['id']}'),
                        subtitle: Text(order['timestamp'].toString().substring(0, 16)),
                        trailing: Text(formatMoney(double.tryParse(order['total'].toString()) ?? 0),
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                      );
                    },
                  )
                : _buildPermissionDeniedWidget('Quyền xem Lịch Sử Đơn Hàng'),

            // Tab 2: Nhật ký thao tác
            canViewLogs
                ? ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: logs.length,
                    itemBuilder: (ctx, idx) {
                      final log = logs[logs.length - 1 - idx];
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.info_outline, color: Colors.blueGrey),
                        title: Text(log['detail'] ?? ''),
                        subtitle: Text(log['time'] ?? ''),
                      );
                    },
                  )
                : _buildPermissionDeniedWidget('Quyền xem Nhật Ký Thao Tác'),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionDeniedWidget(String permName) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_person_outlined, size: 64, color: Colors.orange),
            const SizedBox(height: 16),
            Text('Thiết bị chưa được cấp $permName',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Mã thiết bị của bạn là: ${LocalStorageService.myDeviceId}',
                style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            const Text('Vui lòng liên hệ Admin để cấp quyền cho thiết bị này.', textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ------------------- 5. MÀN HÌNH ADMIN QUẢN LÝ CẤP QUYỀN -------------------
class AdminPermissionScreen extends StatefulWidget {
  const AdminPermissionScreen({super.key});

  @override
  State<AdminPermissionScreen> createState() => _AdminPermissionScreenState();
}

class _AdminPermissionScreenState extends State<AdminPermissionScreen> {
  bool isUnlocked = false;
  final pinController = TextEditingController();
  final targetDeviceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Nếu thiết bị hiện tại có quyền Admin sẵn thì tự động mở
    if (LocalStorageService.hasPermission('isAdmin')) {
      isUnlocked = true;
    }
  }

  void _verifyAdmin() {
    if (LocalStorageService.verifyMasterCode(pinController.text.trim())) {
      setState(() => isUnlocked = true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mã PIN Admin không đúng! (Mã mặc định: 000)'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!isUnlocked) {
      return Scaffold(
        appBar: AppBar(title: const Text('Quản Lý Phân Quyền')),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.admin_panel_settings, size: 72, color: Color(0xFF0D9488)),
              const SizedBox(height: 16),
              const Text('Nhập Mã PIN Admin (Mã mặc định 000) để vào Bảng Cấp Quyền:',
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
                onPressed: _verifyAdmin,
                child: const Text('MỞ KHÓA ADMIN'),
              ),
            ],
          ),
        ),
      );
    }

    final allPermissions = LocalStorageService.getAllPermissions();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bảng Cấp Quyền Bằng Device ID'),
        actions: [
          IconButton(
            icon: const Icon(Icons.lock),
            onPressed: () => setState(() => isUnlocked = false),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // THÔNG TIN THIẾT BỊ HIỆN TẠI
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  const Icon(Icons.phone_android, color: Color(0xFF0D9488)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Mã Định Danh Máy Này: ${LocalStorageService.myDeviceId}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            const Text('Danh Sách Các Thiết Bị Đã Được Cấp Quyền:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),

            ...allPermissions.entries.map((entry) {
              String devId = entry.key;
              Map<String, bool> perms = entry.value;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Mã Thiết Bị: $devId',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0D9488))),
                          if (devId == LocalStorageService.myDeviceId)
                            const Chip(label: Text('Máy này'), backgroundColor: Color(0xFFCCFBF1))
                        ],
                      ),
                      const Divider(),
                      SwitchListTile(
                        dense: true,
                        title: const Text('Quyền Xem Lịch Sử Đơn Hàng'),
                        value: perms['viewOrderHistory'] ?? false,
                        onChanged: (val) {
                          setState(() {
                            LocalStorageService.togglePermission(devId, 'viewOrderHistory', val);
                          });
                        },
                      ),
                      SwitchListTile(
                        dense: true,
                        title: const Text('Quyền Xem Nhật Ký Thao Tác'),
                        value: perms['viewLogs'] ?? false,
                        onChanged: (val) {
                          setState(() {
                            LocalStorageService.togglePermission(devId, 'viewLogs', val);
                          });
                        },
                      ),
                      SwitchListTile(
                        dense: true,
                        title: const Text('Quyền Tạo Món Mới'),
                        value: perms['createItem'] ?? false,
                        onChanged: (val) {
                          setState(() {
                            LocalStorageService.togglePermission(devId, 'createItem', val);
                          });
                        },
                      ),
                      SwitchListTile(
                        dense: true,
                        title: const Text('Quyền Admin (Toàn Quyền)'),
                        value: perms['isAdmin'] ?? false,
                        onChanged: (val) {
                          setState(() {
                            LocalStorageService.togglePermission(devId, 'isAdmin', val);
                          });
                        },
                      ),
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: 16),
            const Divider(),
            const Text('Cấp Quyền Cho Thiết Bị Mới Bằng Mã Device ID:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: targetDeviceController,
                    decoration: const InputDecoration(
                      hintText: 'Nhập mã ví dụ: DEV-9999',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D9488), foregroundColor: Colors.white),
                  onPressed: () {
                    String newDevId = targetDeviceController.text.trim();
                    if (newDevId.isNotEmpty) {
                      setState(() {
                        LocalStorageService.togglePermission(newDevId, 'viewOrderHistory', true);
                        targetDeviceController.clear();
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Đã khởi tạo và cấp quyền cho thiết bị $newDevId')),
                      );
                    }
                  },
                  child: const Text('Thêm Máy'),
                )
              ],
            )
          ],
        ),
      ),
    );
  }
}

