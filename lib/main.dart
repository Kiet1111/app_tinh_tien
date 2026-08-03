import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Quản Lý Bán Hàng',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        useMaterial3: true,
      ),
      home: const MainHomeScreen(),
    );
  }
}

// Model Biến thể món
class ProductVariant {
  String id;
  String name;
  double pricePrice;

  ProductVariant({required this.id, required this.name, required this.pricePrice});

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'pricePrice': pricePrice};
  factory ProductVariant.fromJson(Map<String, dynamic> json) => ProductVariant(
        id: json['id'],
        name: json['name'],
        pricePrice: (json['pricePrice'] as num).toDouble(),
      );
}

// Model Topping
class ToppingItem {
  String id;
  String name;
  double price;

  ToppingItem({required this.id, required this.name, required this.price});

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'price': price};
  factory ToppingItem.fromJson(Map<String, dynamic> json) => ToppingItem(
        id: json['id'],
        name: json['name'],
        price: (json['price'] as num).toDouble(),
      );
}

// Model Món ăn
class MenuItem {
  String id;
  String name;
  double basePrice;
  String category;
  String unit;
  String? imagePath;
  bool isAvailable;
  List<ToppingItem> toppings;
  List<ProductVariant> variants;

  MenuItem({
    required this.id,
    required this.name,
    required this.basePrice,
    required this.category,
    required this.unit,
    this.imagePath,
    this.isAvailable = true,
    required this.toppings,
    required this.variants,
  });
}

// Model Bàn / Hóa đơn
class OrderTable {
  String tableName;
  List<Map<String, dynamic>> items;
  OrderTable({required this.tableName, required this.items});
}

class MainHomeScreen extends StatefulWidget {
  const MainHomeScreen({super.key});

  @override
  State<MainHomeScreen> createState() => _MainHomeScreenState();
}

class _MainHomeScreenState extends State<MainHomeScreen> {
  int _currentIndex = 0;
  String currentRole = 'Admin';
  bool isOnlineMode = true;

  List<String> categories = ['Tất cả', 'Đồ Uống', 'Đồ Ăn', 'Đồ Cân'];
  List<String> units = ['ly', 'đĩa', 'bịch', 'kg', 'g', 'phần'];
  String selectedCategory = 'Tất cả';

  List<MenuItem> menuItems = [
    MenuItem(
      id: '1',
      name: 'Cà Phê Sữa Đá',
      basePrice: 25000,
      category: 'Đồ Uống',
      unit: 'ly',
      toppings: [
        ToppingItem(id: 't1', name: 'Trân châu đen', price: 5000),
        ToppingItem(id: 't2', name: 'Kem cheese', price: 10000),
      ],
      variants: [
        ProductVariant(id: 'v1', name: 'Size M', pricePrice: 0),
        ProductVariant(id: 'v2', name: 'Size L', pricePrice: 5000),
      ],
    ),
    MenuItem(
      id: '2',
      name: 'Dừa Nạo Sợi',
      basePrice: 60000,
      category: 'Đồ Cân',
      unit: 'kg',
      toppings: [],
      variants: [],
    )
  ];

  List<OrderTable> tables = List.generate(6, (i) => OrderTable(tableName: 'Bàn ${i + 1}', items: []));
  int selectedTableIndex = 0;

  double todayRevenue = 0;
  double monthRevenue = 0;
  double totalExpenses = 0;
  List<String> actionLogs = [];
  List<Map<String, dynamic>> orderHistory = [];
  List<Map<String, dynamic>> dailyRevenueLogs = [];
  List<Map<String, dynamic>> monthlyRevenueLogs = [];
  List<Map<String, dynamic>> expenseLogs = [];

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _checkAndResetRevenue();
  }

  Future<void> _checkAndResetRevenue() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final todayStr = "${now.year}-${now.month}-${now.day}";
    final monthStr = "${now.year}-${now.month}";

    String lastDate = prefs.getString('lastDate') ?? todayStr;
    String lastMonth = prefs.getString('lastMonth') ?? monthStr;

    todayRevenue = prefs.getDouble('todayRevenue') ?? 0;
    monthRevenue = prefs.getDouble('monthRevenue') ?? 0;

    if (lastDate != todayStr) {
      dailyRevenueLogs.add({'date': lastDate, 'revenue': todayRevenue});
      todayRevenue = 0;
      prefs.setString('lastDate', todayStr);
    }

    if (lastMonth != monthStr) {
      monthlyRevenueLogs.add({'month': lastMonth, 'revenue': monthRevenue});
      monthRevenue = 0;
      prefs.setString('lastMonth', monthStr);
    }

    _saveFinanceData();
  }

  Future<void> _saveFinanceData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('todayRevenue', todayRevenue);
    await prefs.setDouble('monthRevenue', monthRevenue);
  }

  void _addLog(String text) {
    setState(() {
      actionLogs.insert(0, "[${DateTime.now().toString().substring(11, 19)}] $text");
    });
  }

  Future<String?> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      return image?.path;
    } catch (_) {
      return null;
    }
  }

  void _showAddEditItemDialog({MenuItem? itemToEdit}) {
    final nameCtrl = TextEditingController(text: itemToEdit?.name ?? '');
    final priceCtrl = TextEditingController(text: itemToEdit?.basePrice.toString() ?? '');
    String cat = itemToEdit?.category ?? (categories.length > 1 ? categories[1] : 'Chung');
    String unit = itemToEdit?.unit ?? 'ly';
    bool isAvail = itemToEdit?.isAvailable ?? true;
    String? imagePath = itemToEdit?.imagePath;
    List<ToppingItem> currentToppings = itemToEdit != null ? List.from(itemToEdit.toppings) : [];
    List<ProductVariant> currentVariants = itemToEdit != null ? List.from(itemToEdit.variants) : [];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: Text(itemToEdit == null ? 'Tạo Món Mới' : 'Chỉnh Sửa Món'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () async {
                    String? path = await _pickImage();
                    if (path != null) setDlgState(() => imagePath = path);
                  },
                  child: Container(
                    height: 100,
                    width: double.infinity,
                    color: Colors.grey.shade200,
                    child: imagePath == null
                        ? const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_a_photo), Text('Chọn ảnh minh họa')])
                        : Image.file(File(imagePath!), fit: BoxFit.cover),
                  ),
                ),
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Tên món')),
                TextField(controller: priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Giá gốc (VNĐ)')),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: cat,
                        items: categories.where((c) => c != 'Tất cả').map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                        onChanged: (v) => setDlgState(() => cat = v!),
                        decoration: const InputDecoration(labelText: 'Danh mục'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: unit,
                        items: units.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                        onChanged: (v) => setDlgState(() => unit = v!),
                        decoration: const InputDecoration(labelText: 'Đơn vị tính'),
                      ),
                    ),
                  ],
                ),
                SwitchListTile(
                  title: const Text('Đang kinh doanh'),
                  subtitle: Text(isAvail ? 'Hiện trên thực đơn' : 'Tạm ngừng bán'),
                  value: isAvail,
                  onChanged: (v) => setDlgState(() => isAvail = v),
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Biến thể món', style: TextStyle(fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () {
                        setDlgState(() {
                          currentVariants.add(ProductVariant(id: const Uuid().v4(), name: 'Biến thể mới', pricePrice: 0));
                        });
                      },
                    )
                  ],
                ),
                ...currentVariants.map((varItem) => Row(
                      children: [
                        Expanded(child: TextFormField(initialValue: varItem.name, onChanged: (v) => varItem.name = v)),
                        const SizedBox(width: 5),
                        Expanded(child: TextFormField(initialValue: varItem.pricePrice.toString(), keyboardType: TextInputType.number, onChanged: (v) => varItem.pricePrice = double.tryParse(v) ?? 0)),
                        IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => setDlgState(() => currentVariants.remove(varItem)))
                      ],
                    )),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
            ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.isNotEmpty) {
                  setState(() {
                    if (itemToEdit == null) {
                      menuItems.add(MenuItem(
                        id: const Uuid().v4(),
                        name: nameCtrl.text,
                        basePrice: double.tryParse(priceCtrl.text) ?? 0,
                        category: cat,
                        unit: unit,
                        imagePath: imagePath,
                        isAvailable: isAvail,
                        toppings: currentToppings,
                        variants: currentVariants,
                      ));
                      _addLog("Tạo món mới: ${nameCtrl.text}");
                    } else {
                      itemToEdit.name = nameCtrl.text;
                      itemToEdit.basePrice = double.tryParse(priceCtrl.text) ?? 0;
                      itemToEdit.category = cat;
                      itemToEdit.unit = unit;
                      itemToEdit.imagePath = imagePath;
                      itemToEdit.isAvailable = isAvail;
                      itemToEdit.toppings = currentToppings;
                      itemToEdit.variants = currentVariants;
                      _addLog("Cập nhật món: ${nameCtrl.text}");
                    }
                  });
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddToCartDialog(MenuItem item) {
    double selectedQty = 1;
    double weightInGrams = 500;
    ProductVariant? selectedVariant = item.variants.isNotEmpty ? item.variants.first : null;
    Map<String, int> toppingQtyMap = {};
    for (var t in item.toppings) {
      toppingQtyMap[t.id] = 0;
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          bool isByWeight = item.unit == 'kg' || item.unit == 'g';
          double basePriceCalculated = item.basePrice + (selectedVariant?.pricePrice ?? 0);
          double totalItemPrice = 0;

          if (isByWeight) {
            totalItemPrice = (basePriceCalculated / (item.unit == 'kg' ? 1000 : 1)) * weightInGrams;
          } else {
            totalItemPrice = basePriceCalculated * selectedQty;
          }

          for (var t in item.toppings) {
            totalItemPrice += (toppingQtyMap[t.id] ?? 0) * t.price;
          }

          return AlertDialog(
            title: Text(item.name),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (item.variants.isNotEmpty) ...[
                    const Align(alignment: Alignment.centerLeft, child: Text('Chọn Biến thể:', style: TextStyle(fontWeight: FontWeight.bold))),
                    DropdownButton<ProductVariant>(
                      value: selectedVariant,
                      isExpanded: true,
                      items: item.variants
                          .map((v) => DropdownMenuItem(value: v, child: Text("${v.name} (+${v.pricePrice.toStringAsFixed(0)}đ)")))
                          .toList(),
                      onChanged: (v) => setDlgState(() => selectedVariant = v),
                    ),
                  ],
                  const SizedBox(height: 10),
                  if (isByWeight) ...[
                    Text('Số Gram (g): ${weightInGrams.toStringAsFixed(0)}g'),
                    Slider(
                      value: weightInGrams,
                      min: 50,
                      max: 5000,
                      divisions: 99,
                      label: '${weightInGrams.toStringAsFixed(0)}g',
                      onChanged: (v) => setDlgState(() => weightInGrams = v),
                    ),
                  ] else ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(icon: const Icon(Icons.remove_circle), onPressed: selectedQty > 1 ? () => setDlgState(() => selectedQty--) : null),
                        Text('${selectedQty.toInt()}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        IconButton(icon: const Icon(Icons.add_circle), onPressed: () => setDlgState(() => selectedQty++)),
                      ],
                    ),
                  ],
                  if (item.toppings.isNotEmpty) ...[
                    const Divider(),
                    const Align(alignment: Alignment.centerLeft, child: Text('Chọn Topping:', style: TextStyle(fontWeight: FontWeight.bold))),
                    ...item.toppings.map((top) {
                      int count = toppingQtyMap[top.id] ?? 0;
                      return ListTile(
                        dense: true,
                        title: Text("${top.name} (+${top.price.toStringAsFixed(0)}đ)"),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(icon: const Icon(Icons.remove), onPressed: count > 0 ? () => setDlgState(() => toppingQtyMap[top.id] = count - 1) : null),
                            Text('$count'),
                            IconButton(icon: const Icon(Icons.add), onPressed: () => setDlgState(() => toppingQtyMap[top.id] = count + 1)),
                          ],
                        ),
                      );
                    }),
                  ]
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    tables[selectedTableIndex].items.add({
                      'itemId': item.id,
                      'name': "${item.name} ${selectedVariant != null ? '(${selectedVariant!.name})' : ''}",
                      'unit': item.unit,
                      'quantity': isByWeight ? (weightInGrams / 1000) : selectedQty,
                      'totalPrice': totalItemPrice,
                    });
                    _addLog("Thêm ${item.name} vào ${tables[selectedTableIndex].tableName}");
                  });
                  Navigator.pop(ctx);
                },
                child: Text('Thêm • ${totalItemPrice.toStringAsFixed(0)}đ'),
              )
            ],
          );
        },
      ),
    );
  }

  void _showSplitMergeDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quản Lý Bàn & Hóa Đơn'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.merge_type),
              label: const Text('Gộp Bàn Khác Vào Bàn Hiện Tại'),
              onPressed: () {
                Navigator.pop(ctx);
                _mergeTableDialog();
              },
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              icon: const Icon(Icons.call_split),
              label: const Text('Chia Tiền Theo Số Người'),
              onPressed: () {
                Navigator.pop(ctx);
                _splitBillByPeopleDialog();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _mergeTableDialog() {
    int sourceIndex = 0;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Gộp vào ${tables[selectedTableIndex].tableName}'),
        content: DropdownButton<int>(
          value: sourceIndex,
          items: List.generate(tables.length, (i) => i)
              .where((i) => i != selectedTableIndex)
              .map((i) => DropdownMenuItem(value: i, child: Text(tables[i].tableName)))
              .toList(),
          onChanged: (v) => sourceIndex = v!,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () {
              setState(() {
                tables[selectedTableIndex].items.addAll(tables[sourceIndex].items);
                tables[sourceIndex].items.clear();
                _addLog("Đã gộp ${tables[sourceIndex].tableName} vào ${tables[selectedTableIndex].tableName}");
              });
              Navigator.pop(ctx);
            },
            child: const Text('Xác nhận Gộp'),
          )
        ],
      ),
    );
  }

  void _splitBillByPeopleDialog() {
    int people = 2;
    double total = tables[selectedTableIndex].items.fold(0, (sum, i) => sum + (i['totalPrice'] as double));
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: const Text('Chia Tiền Hóa Đơn'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Tổng tiền: ${total.toStringAsFixed(0)} VNĐ'),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Số người: '),
                  IconButton(icon: const Icon(Icons.remove), onPressed: people > 1 ? () => setDlgState(() => people--) : null),
                  Text('$people', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  IconButton(icon: const Icon(Icons.add), onPressed: () => setDlgState(() => people++)),
                ],
              ),
              const Divider(),
              Text('Mỗi người: ${(total / people).toStringAsFixed(0)} VNĐ', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal, fontSize: 16)),
            ],
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đóng'))],
        ),
      ),
    );
  }

  void _checkoutTable() {
    var table = tables[selectedTableIndex];
    if (table.items.isEmpty) return;

    double total = table.items.fold(0, (sum, i) => sum + (i['totalPrice'] as double));

    setState(() {
      todayRevenue += total;
      monthRevenue += total;
      orderHistory.insert(0, {
        'id': const Uuid().v4().substring(0, 6),
        'table': table.tableName,
        'total': total,
        'time': DateTime.now().toString().substring(0, 19),
        'items': List.from(table.items),
      });
      table.items.clear();
    });

    _saveFinanceData();
    _addLog("Thanh toán ${table.tableName}: ${total.toStringAsFixed(0)}đ");
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Thanh toán thành công ${total.toStringAsFixed(0)}đ')));
  }

  void _addExpenseDialog() {
    final noteCtrl = TextEditingController();
    final amountCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ghi Nhận Chi Phí'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: noteCtrl, decoration: const InputDecoration(labelText: 'Nội dung chi')),
            TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Số tiền (VNĐ)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () {
              double amt = double.tryParse(amountCtrl.text) ?? 0;
              if (amt > 0) {
                setState(() {
                  totalExpenses += amt;
                  expenseLogs.insert(0, {'note': noteCtrl.text, 'amount': amt, 'time': DateTime.now().toString()});
                  _addLog("Chi tiêu: ${noteCtrl.text} (-${amt.toStringAsFixed(0)}đ)");
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text('Lưu'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bán Hàng ($currentRole)'),
        actions: [
          IconButton(
            icon: Icon(isOnlineMode ? Icons.wifi : Icons.wifi_off, color: isOnlineMode ? Colors.green : Colors.grey),
            onPressed: () => setState(() => isOnlineMode = !isOnlineMode),
          ),
          PopupMenuButton<String>(
            onSelected: (r) => setState(() => currentRole = r),
            itemBuilder: (c) => [
              const PopupMenuItem(value: 'Admin', child: Text('Quyền: Admin')),
              const PopupMenuItem(value: 'Nhân viên', child: Text('Quyền: Nhân viên')),
            ],
          )
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildSalesTab(),
          _buildMenuManagementTab(),
          _buildProfitTab(),
          _buildHistoryTab(),
          _buildRoleTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.store), label: 'Bán Hàng'),
          NavigationDestination(icon: Icon(Icons.restaurant_menu), label: 'Thực Đơn'),
          NavigationDestination(icon: Icon(Icons.attach_money), label: 'Lợi Nhuận'),
          NavigationDestination(icon: Icon(Icons.history), label: 'Lịch Sử'),
          NavigationDestination(icon: Icon(Icons.security), label: 'Cấp Quyền'),
        ],
      ),
    );
  }

  Widget _buildSalesTab() {
    var currentTable = tables[selectedTableIndex];
    double currentTotal = currentTable.items.fold(0, (sum, i) => sum + (i['totalPrice'] as double));

    return Column(
      children: [
        SizedBox(
          height: 50,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: tables.length,
            itemBuilder: (c, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: ChoiceChip(
                label: Text("${tables[i].tableName} (${tables[i].items.length})"),
                selected: selectedTableIndex == i,
                onSelected: (v) => setState(() => selectedTableIndex = i),
              ),
            ),
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: categories
                .map((cat) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: FilterChip(
                        label: Text(cat),
                        selected: selectedCategory == cat,
                        onSelected: (v) => setState(() => selectedCategory = cat),
                      ),
                    ))
                .toList(),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 0.85, crossAxisSpacing: 8, mainAxisSpacing: 8),
            itemCount: menuItems.length,
            itemBuilder: (c, i) {
              final item = menuItems[i];
              if (selectedCategory != 'Tất cả' && item.category != selectedCategory) return const SizedBox.shrink();
              return GestureDetector(
                onTap: item.isAvailable ? () => _showAddToCartDialog(item) : null,
                child: Card(
                  color: item.isAvailable ? Colors.white : Colors.grey.shade300,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: item.imagePath != null
                            ? Image.file(File(item.imagePath!), fit: BoxFit.cover)
                            : const Icon(Icons.fastfood, size: 40, color: Colors.teal),
                      ),
                      Text(item.name, style: TextStyle(fontWeight: FontWeight.bold, decoration: item.isAvailable ? null : TextDecoration.lineThrough)),
                      Text('${item.basePrice.toStringAsFixed(0)}đ/${item.unit}', style: const TextStyle(color: Colors.teal, fontSize: 12)),
                      if (!item.isAvailable) const Text('Tạm ngưng', style: TextStyle(color: Colors.red, fontSize: 10)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Card(
          margin: const EdgeInsets.all(8),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Đơn hàng: ${currentTable.tableName}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.more_vert), onPressed: _showSplitMergeDialog),
                  ],
                ),
                Text('Tổng tiền: ${currentTotal.toStringAsFixed(0)} VNĐ', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal)),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(40)),
                  onPressed: currentTable.items.isNotEmpty ? _checkoutTable : null,
                  icon: const Icon(Icons.payment),
                  label: const Text('Thanh Toán Đơn'),
                )
              ],
            ),
          ),
        )
      ],
    );
  }

  Widget _buildMenuManagementTab() {
    return Scaffold(
      floatingActionButton: currentRole == 'Admin'
          ? FloatingActionButton(
              onPressed: () => _showAddEditItemDialog(),
              child: const Icon(Icons.add),
            )
          : null,
      body: ListView.builder(
        itemCount: menuItems.length,
        itemBuilder: (c, i) {
          final item = menuItems[i];
          return ListTile(
            leading: item.imagePath != null
                ? Image.file(File(item.imagePath!), width: 50, height: 50, fit: BoxFit.cover)
                : const Icon(Icons.fastfood),
            title: Text(item.name),
            subtitle: Text('Giá: ${item.basePrice.toStringAsFixed(0)}đ / ${item.unit} | ${item.isAvailable ? "Đang bán" : "Tạm ngưng"}'),
            trailing: currentRole == 'Admin'
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _showAddEditItemDialog(itemToEdit: item)),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => setState(() {
                          menuItems.removeAt(i);
                          _addLog("Đã xóa món ${item.name}");
                        }),
                      ),
                    ],
                  )
                : null,
          );
        },
      ),
    );
  }

  Widget _buildProfitTab() {
    double netProfit = monthRevenue - totalExpenses;
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Card(
            color: Colors.teal.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(children: [const Text('Doanh Thu Hôm Nay'), Text('${todayRevenue.toStringAsFixed(0)}đ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green))]),
                      Column(children: [const Text('Doanh Thu Tháng'), Text('${monthRevenue.toStringAsFixed(0)}đ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue))]),
                    ],
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(children: [const Text('Tổng Chi Phí'), Text('${totalExpenses.toStringAsFixed(0)}đ', style: const TextStyle(color: Colors.red))]),
                      Column(children: [const Text('Lợi Nhuận Ròng'), Text('${netProfit.toStringAsFixed(0)}đ', style: TextStyle(fontWeight: FontWeight.bold, color: netProfit >= 0 ? Colors.green : Colors.red))]),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (currentRole == 'Admin')
            ElevatedButton.icon(onPressed: _addExpenseDialog, icon: const Icon(Icons.add), label: const Text('Ghi Nhận Chi Tiêu Chi Phí')),
          const Divider(),
          const Align(alignment: Alignment.centerLeft, child: Text('Nhật ký Chi Phí:', style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(
            child: ListView.builder(
              itemCount: expenseLogs.length,
              itemBuilder: (c, i) => ListTile(
                title: Text(expenseLogs[i]['note']),
                subtitle: Text(expenseLogs[i]['time']),
                trailing: Text('-${(expenseLogs[i]['amount'] as double).toStringAsFixed(0)}đ', style: const TextStyle(color: Colors.red)),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: const TabBar(
          tabs: [
            Tab(text: 'Đơn Hàng'),
            Tab(text: 'Thao Tác'),
            Tab(text: 'Doanh Thu'),
          ],
        ),
        body: TabBarView(
          children: [
            ListView.builder(
              itemCount: orderHistory.length,
              itemBuilder: (c, i) => ListTile(
                title: Text("Đơn #${orderHistory[i]['id']} - ${orderHistory[i]['table']}"),
                subtitle: Text(orderHistory[i]['time']),
                trailing: Text('${(orderHistory[i]['total'] as double).toStringAsFixed(0)}đ', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            ListView.builder(
              itemCount: actionLogs.length,
              itemBuilder: (c, i) => ListTile(title: Text(actionLogs[i])),
            ),
            ListView(
              children: [
                const ListTile(title: Text('Doanh Thu Theo Ngày', style: TextStyle(fontWeight: FontWeight.bold))),
                ...dailyRevenueLogs.map((e) => ListTile(title: Text(e['date']), trailing: Text('${e['revenue']}đ'))),
                const Divider(),
                const ListTile(title: Text('Doanh Thu Theo Tháng', style: TextStyle(fontWeight: FontWeight.bold))),
                ...monthlyRevenueLogs.map((e) => ListTile(title: Text(e['month']), trailing: Text('${e['revenue']}đ'))),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildRoleTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Quyền hiện tại: $currentRole', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => setState(() => currentRole = currentRole == 'Admin' ? 'Nhân viên' : 'Admin'),
            child: Text('Đổi sang ${currentRole == 'Admin' ? "Nhân viên" : "Admin"}'),
          )
        ],
      ),
    );
  }
}
