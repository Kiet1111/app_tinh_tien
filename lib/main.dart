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
      title: 'POS Bán Hàng & Tính Tiền',
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
    const MenuManagementScreen(),
    const FinancialReportScreen(),
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
            icon: Icon(Icons.edit_note),
            label: 'Quản Lý Món',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics),
            label: 'Báo Cáo & Chi Phí',
          ),
          NavigationDestination(
            icon: Icon(Icons.history),
            label: 'Nhật Ký',
          ),
        ],
      ),
    );
  }
}

// ------------------- 1. MÀN HÌNH TÍNH TIỀN (POS) -------------------
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool isOnline = true; // Chế độ Online / Offline
  bool isLoadingMenu = true;

  List<Map<String, dynamic>> menuList = [];
  List<Map<String, dynamic>> currentOrder = [];
  String selectedCategory = 'Tất cả';

  @override
  void initState() {
    super.initState();
    _loadMenu();
  }

  Future<void> _loadMenu() async {
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
      0.0, (sum, item) => sum + (item['totalPrice'] as double));

  // HỘP THOẠI CHỌN SỐ LƯỢNG / TRỌNG LƯỢNG LẺ (VD: 110 gram hoặc 0.35 kg)
  void _openQuantityModal(Map<String, dynamic> dish) {
    String unit = dish['unit']?.toString().toLowerCase() ?? 'phần';
    bool isWeightUnit = unit == 'kg' || unit == 'g' || unit == 'gram';

    final qtyController = TextEditingController(text: isWeightUnit ? '' : '1');
    final weightGramController = TextEditingController();
    double baseUnitPrice = double.tryParse(dish['price'].toString()) ?? 0.0;

    List rawVariants = dish['variants'] ?? [];
    List rawToppings = dish['toppings'] ?? [];
    List<Map<String, dynamic>> variants =
        rawVariants.map((v) => Map<String, dynamic>.from(v)).toList();
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

            double calculatedQty = 1.0;
            if (isWeightUnit) {
              if (weightGramController.text.isNotEmpty) {
                double grams = double.tryParse(weightGramController.text) ?? 0;
                calculatedQty = grams / 1000.0; // Đổi gram ra kg
              } else if (qtyController.text.isNotEmpty) {
                calculatedQty = double.tryParse(qtyController.text) ?? 0.0;
              }
            } else {
              calculatedQty = double.tryParse(qtyController.text) ?? 1.0;
            }

            double toppingsPrice = selectedToppings.fold(
                0.0, (sum, t) => sum + (double.tryParse(t['price'].toString()) ?? 0.0));

            double totalPrice = (currentUnitPrice * calculatedQty) + toppingsPrice;

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
                        Text(dish['name'],
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        Text('${baseUnitPrice.toStringAsFixed(0)}đ / $unit',
                            style: const TextStyle(
                                color: Colors.teal, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const Divider(),

                    // NẾU LÀ MÓN BÁN THEO KG / TRỌNG LƯỢNG
                    if (isWeightUnit) ...[
                      const Text('Nhập trọng lượng mua:',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, color: Colors.teal)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: weightGramController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Nhập số Gram (VD: 110)',
                                suffixText: 'g',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              onChanged: (val) {
                                if (val.isNotEmpty) qtyController.clear();
                                setModalState(() {});
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text('HOẶC',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, color: Colors.grey)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: qtyController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Nhập số Kg (VD: 0.35)',
                                suffixText: 'kg',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              onChanged: (val) {
                                if (val.isNotEmpty) weightGramController.clear();
                                setModalState(() {});
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ] else ...[
                      // MÓN THƯỜNG (SỐ LƯỢNG SỐ NGUYÊN)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton.outlined(
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
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              onChanged: (_) => setModalState(() {}),
                            ),
                          ),
                          IconButton.outlined(
                            icon: const Icon(Icons.add),
                            onPressed: () {
                              int current = int.tryParse(qtyController.text) ?? 1;
                              qtyController.text = (current + 1).toString();
                              setModalState(() {});
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],

                    // BIẾN THỂ NẾU CÓ
                    if (variants.isNotEmpty) ...[
                      const Text('Biến thể:',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Wrap(
                        spacing: 8,
                        children: variants.map((v) {
                          bool isSel = selectedVariant == v;
                          return ChoiceChip(
                            label: Text('${v['name']} (${v['price']}đ)'),
                            selected: isSel,
                            onSelected: (val) {
                              if (val) setModalState(() => selectedVariant = v);
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // TOPPING NẾU CÓ
                    if (toppings.isNotEmpty) ...[
                      const Text('Món thêm:',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Column(
                        children: toppings.map((t) {
                          bool isChecked = selectedToppings.contains(t);
                          return CheckboxListTile(
                            dense: true,
                            title: Text('${t['name']} (+${t['price']}đ)'),
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

                    // NÚT THÊM
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
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

                                String fullName = dish['name'];
                                if (selectedVariant != null) {
                                  fullName += ' (${selectedVariant!['name']})';
                                }

                                setState(() {
                                  currentOrder.add({
                                    'dishId': dish['id'],
                                    'name': fullName,
                                    'price': currentUnitPrice,
                                    'qty': calculatedQty,
                                    'displayQty': displayQty,
                                    'totalPrice': totalPrice,
                                  });
                                });
                                Navigator.pop(ctx);
                              },
                        child: Text(
                          'THÊM VÀO ĐƠN - ${totalPrice.toStringAsFixed(0)} VNĐ',
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
              ? 'Thanh toán thành công (Đã đồng bộ Online)!'
              : 'Thanh toán thành công (Lưu Offline)!'),
          backgroundColor: Colors.green,
        ),
      );
      setState(() => currentOrder.clear());
      _loadMenu();
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
            InkWell(
              onTap: () {
                setState(() => isOnline = !isOnline);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isOnline
                        ? 'Đã chuyển sang chế độ ONLINE'
                        : 'Đã chuyển sang chế độ OFFLINE'),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isOnline ? Colors.green.shade100 : Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(12),
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
            )
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadMenu),
        ],
      ),
      body: Column(
        children: [
          // DANH MỤC
          SizedBox(
            height: 48,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
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

          // DANH SÁCH MÓN
          Expanded(
            flex: 1,
            child: isLoadingMenu
                ? const Center(child: CircularProgressIndicator())
                : GridView.builder(
                    padding: const EdgeInsets.all(8),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 1.3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: filteredMenu.length,
                    itemBuilder: (ctx, index) {
                      final dish = filteredMenu[index];
                      double price =
                          double.tryParse(dish['price'].toString()) ?? 0.0;
                      double stock =
                          double.tryParse(dish['stock'].toString()) ?? 0.0;
                      String unit = dish['unit'] ?? 'phần';

                      return Card(
                        color: stock <= 0 ? Colors.grey.shade200 : Colors.teal.shade50,
                        child: InkWell(
                          onTap: stock <= 0
                              ? null
                              : () => _openQuantityModal(dish),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  dish['name'],
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${price.toStringAsFixed(0)}đ / $unit',
                                  style: const TextStyle(
                                      color: Colors.teal,
                                      fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  stock <= 0 ? 'HẾT HÀNG' : 'Kho: $stock $unit',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: stock <= 0 ? Colors.red : Colors.grey.shade700,
                                    fontWeight: stock <= 0
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const Divider(height: 1),

          // GIỎ HÀNG THỜI GIAN THỰC
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Đơn hàng',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      Text('Tổng: ${totalAmount.toStringAsFixed(0)} VNĐ',
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
                          title: Text(item['name']),
                          subtitle: Text('S.Lượng: ${item['displayQty']}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${(item['totalPrice'] as double).toStringAsFixed(0)}đ',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete,
                                    color: Colors.red, size: 20),
                                onPressed: () => setState(
                                    () => currentOrder.removeAt(index)),
                              )
                            ],
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
                      label: Text(
                        'THANH TOÁN (${totalAmount.toStringAsFixed(0)}đ)',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
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

// ------------------- 2. MÀN HÌNH QUẢN LÝ MÓN (THÊM & SỬA MÓN) -------------------
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
    _loadMenu();
  }

  Future<void> _loadMenu() async {
    setState(() => isLoading = true);
    final data = await LocalStorageService.fetchMenu();
    setState(() {
      menuList = List<Map<String, dynamic>>.from(data);
      isLoading = false;
    });
  }

  // DIALOG THÊM / CHỈNH SỬA MÓN
  void _showItemFormDialog([Map<String, dynamic>? existingItem]) {
    final bool isEdit = existingItem != null;

    final nameCtrl = TextEditingController(text: isEdit ? existingItem['name'] : '');
    final catCtrl = TextEditingController(text: isEdit ? existingItem['category'] : '');
    final priceCtrl =
        TextEditingController(text: isEdit ? existingItem['price'].toString() : '');
    final unitCtrl =
        TextEditingController(text: isEdit ? (existingItem['unit'] ?? 'phần') : 'phần');
    final stockCtrl =
        TextEditingController(text: isEdit ? (existingItem['stock'] ?? 100).toString() : '100');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? 'Chỉnh Sửa Món Đã Lưu' : 'Thêm Món Mới'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                    labelText: 'Tên món', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: catCtrl,
                decoration: const InputDecoration(
                    labelText: 'Danh mục (VD: Đồ khô, Nước uống)',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: priceCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'Giá bán (VNĐ)',
                          border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: unitCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Đơn vị (kg, phần...)',
                          border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: stockCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Số lượng kho / Tồn kho',
                    border: OutlineInputBorder()),
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
              if (name.isEmpty) return;

              Map<String, dynamic> itemData = {
                'id': isEdit ? existingItem['id'] : null,
                'name': name,
                'category': catCtrl.text.trim().isEmpty ? 'Khác' : catCtrl.text.trim(),
                'price': double.tryParse(priceCtrl.text) ?? 0.0,
                'unit': unitCtrl.text.trim().isEmpty ? 'phần' : unitCtrl.text.trim(),
                'stock': double.tryParse(stockCtrl.text) ?? 0.0,
                'variants': isEdit ? existingItem['variants'] : [],
                'toppings': isEdit ? existingItem['toppings'] : [],
              };

              Navigator.pop(ctx);
              if (isEdit) {
                await LocalStorageService.updateMenuItem(itemData);
              } else {
                await LocalStorageService.addMenuItem(itemData);
              }
              _loadMenu();
            },
            child: Text(isEdit ? 'Cập Nhật' : 'Lưu Món'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản Lý Thực Đơn'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle, color: Colors.teal),
            onPressed: () => _showItemFormDialog(),
          )
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: menuList.length,
              itemBuilder: (ctx, index) {
                final item = menuList[index];
                double price = double.tryParse(item['price'].toString()) ?? 0;
                double stock = double.tryParse(item['stock'].toString()) ?? 0;

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: ListTile(
                    title: Text(item['name'],
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                        'Giá: ${price.toStringAsFixed(0)}đ / ${item['unit'] ?? 'phần'} | Tồn kho: $stock'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _showItemFormDialog(item),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () async {
                            await LocalStorageService.deleteMenuItem(
                                item['id'].toString());
                            _loadMenu();
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

// ------------------- 3. MÀN HÌNH BÁO CÁO DOANH THU & LỢI NHUẬN RÒNG -------------------
class FinancialReportScreen extends StatefulWidget {
  const FinancialReportScreen({super.key});

  @override
  State<FinancialReportScreen> createState() => _FinancialReportScreenState();
}

class _FinancialReportScreenState extends State<FinancialReportScreen> {
  int selectedPeriodDays = 1; // 1: 1 ngày, 7: 1 tuần, 30: 1 tháng

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

  // DIALOG GHI NHẬN CHI PHÍ
  void _showAddExpenseDialog() {
    String category = 'Gas';
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulWidget(
        builder: (context, setDlgState) => AlertDialog(
          title: const Text('Nhập Chi Phí Vận Hành'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: category,
                decoration: const InputDecoration(
                    labelText: 'Loại chi phí', border: OutlineInputBorder()),
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
                decoration: const InputDecoration(
                    labelText: 'Số tiền (VNĐ)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(
                    labelText: 'Ghi chú thêm', border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
            ElevatedButton(
              onPressed: () async {
                double amt = double.tryParse(amountCtrl.text) ?? 0.0;
                if (amt > 0) {
                  Navigator.pop(ctx);
                  await LocalStorageService.addExpense(
                      category, amt, noteCtrl.text.trim());
                  _loadFinancialData();
                }
              },
              child: const Text('Lưu Chi Phí'),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Báo Cáo & Lợi Nhuận Ròng'),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh), onPressed: _loadFinancialData)
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  // LỌC THỜI GIAN
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FilterChip(
                        label: const Text('1 Ngày (Hôm nay)'),
                        selected: selectedPeriodDays == 1,
                        onSelected: (_) => setState(() => selectedPeriodDays = 1),
                      ),
                      const SizedBox(width: 6),
                      FilterChip(
                        label: const Text('1 Tuần'),
                        selected: selectedPeriodDays == 7,
                        onSelected: (_) => setState(() => selectedPeriodDays = 7),
                      ),
                      const SizedBox(width: 6),
                      FilterChip(
                        label: const Text('1 Tháng'),
                        selected: selectedPeriodDays == 30,
                        onSelected: (_) =>
                            setState(() => selectedPeriodDays = 30),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // THẺ TỔNG HỢP LỢI NHUẬN RÒNG
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: netProfit >= 0
                          ? Colors.teal.shade50
                          : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: netProfit >= 0 ? Colors.teal : Colors.red),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'LỢI NHUẬN RÒNG (${selectedPeriodDays == 1 ? 'HÔM NAY' : '$selectedPeriodDays NGÀY'})',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${netProfit.toStringAsFixed(0)} VNĐ',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: netProfit >= 0 ? Colors.teal : Colors.red,
                          ),
                        ),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                const Text('Tổng Doanh Thu'),
                                Text(
                                  '+${filteredRevenue.toStringAsFixed(0)}đ',
                                  style: const TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold),
                                )
                              ],
                            ),
                            Column(
                              children: [
                                const Text('Tổng Chi Phí'),
                                Text(
                                  '-${filteredExpenses.toStringAsFixed(0)}đ',
                                  style: const TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold),
                                )
                              ],
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // NÚT NHẬP CHI PHÍ
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12)),
                      onPressed: _showAddExpenseDialog,
                      icon: const Icon(Icons.remove_circle_outline,
                          color: Colors.red),
                      label: const Text('NHẬP CHI PHÍ (GAS, ĐIỆN, NHÀ, NHẬP HÀNG)'),
                    ),
                  ),

                  const SizedBox(height: 16),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Lịch Sử Chi Phí Gần Đây',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  const SizedBox(height: 8),

                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: expenses.length,
                    itemBuilder: (ctx, index) {
                      final exp = expenses[expenses.length - 1 - index];
                      return Card(
                        child: ListTile(
                          dense: true,
                          title: Text('[${exp['category']}] - ${exp['note']}'),
                          subtitle: Text(exp['timestamp'].toString().substring(0, 10)),
                          trailing: Text(
                            '-${(double.tryParse(exp['amount'].toString()) ?? 0).toStringAsFixed(0)}đ',
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

