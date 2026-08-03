import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Lỗi khởi tạo Firebase: $e");
  }
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

class ProductVariant {
  String id;
  String name;
  double price;

  ProductVariant({required this.id, required this.name, required this.price});

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'price': price};
  factory ProductVariant.fromJson(Map<String, dynamic> json) => ProductVariant(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        price: (json['price'] as num? ?? 0).toDouble(),
      );
}

class ToppingItem {
  String id;
  String name;
  double price;

  ToppingItem({required this.id, required this.name, required this.price});

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'price': price};
  factory ToppingItem.fromJson(Map<String, dynamic> json) => ToppingItem(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        price: (json['price'] as num? ?? 0).toDouble(),
      );
}

class MenuItem {
  String id;
  String name;
  double basePrice;
  String category;
  String unit;
  String? imagePath;
  bool isAvailable;
  List<ProductVariant> variants;
  List<ToppingItem> toppings;

  MenuItem({
    required this.id,
    required this.name,
    required this.basePrice,
    required this.category,
    required this.unit,
    this.imagePath,
    this.isAvailable = true,
    required this.variants,
    required this.toppings,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'basePrice': basePrice,
        'category': category,
        'unit': unit,
        'imagePath': imagePath,
        'isAvailable': isAvailable,
        'variants': variants.map((v) => v.toJson()).toList(),
        'toppings': toppings.map((t) => t.toJson()).toList(),
      };

  factory MenuItem.fromJson(Map<String, dynamic> json) => MenuItem(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        basePrice: (json['basePrice'] as num? ?? 0).toDouble(),
        category: json['category'] ?? 'Đồ Ăn',
        unit: json['unit'] ?? 'tô',
        imagePath: json['imagePath'],
        isAvailable: json['isAvailable'] ?? true,
        variants: (json['variants'] as List? ?? []).map((v) => ProductVariant.fromJson(v)).toList(),
        toppings: (json['toppings'] as List? ?? []).map((t) => ToppingItem.fromJson(t)).toList(),
      );
}

class OrderTable {
  String tableName;
  List<Map<String, dynamic>> items;
  OrderTable({required this.tableName, required this.items});

  Map<String, dynamic> toJson() => {'tableName': tableName, 'items': items};
  factory OrderTable.fromJson(Map<String, dynamic> json) => OrderTable(
        tableName: json['tableName'] ?? '',
        items: List<Map<String, dynamic>>.from(json['items'] ?? []),
      );
}

class MainHomeScreen extends StatefulWidget {
  const MainHomeScreen({super.key});

  @override
  State<MainHomeScreen> createState() => _MainHomeScreenState();
}

class _MainHomeScreenState extends State<MainHomeScreen> {
  int _currentIndex = 0;
  String currentRole = 'Admin';

  List<String> categories = ['Tất cả', 'Đồ Ăn', 'Đồ Uống', 'Đồ Cân'];
  List<String> units = ['tô', 'dĩa', 'ly', 'kg', 'g', 'phần', 'chai', 'lon'];
  String selectedCategory = 'Tất cả';

  List<MenuItem> menuItems = [];
  List<OrderTable> tables = List.generate(6, (i) => OrderTable(tableName: 'Bàn ${i + 1}', items: []));
  int selectedTableIndex = 0;

  List<Map<String, dynamic>> orderHistory = [];
  final ImagePicker _picker = ImagePicker();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _loadCustomCategoriesAndUnits();
    _listenToFirestoreRealtime();
  }

  void _listenToFirestoreRealtime() {
    _firestore.collection('menu').snapshots().listen((snapshot) {
      if (mounted) {
        setState(() {
          menuItems = snapshot.docs.map((doc) => MenuItem.fromJson(doc.data())).toList();
        });
      }
    });

    _firestore.collection('tables').snapshots().listen((snapshot) {
      if (snapshot.docs.isNotEmpty && mounted) {
        setState(() {
          tables = snapshot.docs.map((doc) => OrderTable.fromJson(doc.data())).toList();
        });
      }
    });

    _firestore.collection('orders').orderBy('time', descending: true).snapshots().listen((snapshot) {
      if (mounted) {
        setState(() {
          orderHistory = snapshot.docs.map((doc) => doc.data()).toList();
        });
      }
    });
  }

  Future<void> _saveMenuItemToCloud(MenuItem item) async {
    await _firestore.collection('menu').doc(item.id).set(item.toJson());
  }

  Future<void> _syncTableToCloud(int index) async {
    await _firestore.collection('tables').doc('table_$index').set(tables[index].toJson());
  }

  Future<void> _loadCustomCategoriesAndUnits() async {
    final prefs = await SharedPreferences.getInstance();
    List<String>? savedCats = prefs.getStringList('saved_categories');
    List<String>? savedUnits = prefs.getStringList('saved_units');

    if (savedCats != null && savedCats.isNotEmpty) setState(() => categories = savedCats);
    if (savedUnits != null && savedUnits.isNotEmpty) setState(() => units = savedUnits);
  }

  Future<void> _saveCustomCategoriesAndUnits() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('saved_categories', categories);
    await prefs.setStringList('saved_units', units);
  }

  Future<String?> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      return image?.path;
    } catch (_) {
      return null;
    }
  }

  void _showAddCategoryDialog([Function(String)? onCategoryAdded]) {
    final catCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thêm Danh Mục Mới'),
        content: TextField(controller: catCtrl, autofocus: true, decoration: const InputDecoration(labelText: 'Tên danh mục')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () {
              String name = catCtrl.text.trim();
              if (name.isNotEmpty && !categories.contains(name)) {
                setState(() => categories.add(name));
                _saveCustomCategoriesAndUnits();
                if (onCategoryAdded != null) onCategoryAdded(name);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Thêm'),
          )
        ],
      ),
    );
  }

  void _showAddUnitDialog([Function(String)? onUnitAdded]) {
    final unitCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thêm Đơn Vị Tính Mới'),
        content: TextField(controller: unitCtrl, autofocus: true, decoration: const InputDecoration(labelText: 'Tên đơn vị')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () {
              String name = unitCtrl.text.trim();
              if (name.isNotEmpty && !units.contains(name)) {
                setState(() => units.add(name));
                _saveCustomCategoriesAndUnits();
                if (onUnitAdded != null) onUnitAdded(name);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Thêm'),
          )
        ],
      ),
    );
  }

  void _showAddEditItemDialog({MenuItem? itemToEdit}) {
    final nameCtrl = TextEditingController(text: itemToEdit?.name ?? '');
    final priceCtrl = TextEditingController(text: itemToEdit?.basePrice.toString() ?? '');
    String cat = itemToEdit?.category ?? (categories.length > 1 ? categories[1] : 'Đồ Ăn');
    String unit = itemToEdit?.unit ?? units.first;
    bool isAvail = itemToEdit?.isAvailable ?? true;
    String? imagePath = itemToEdit?.imagePath;
    List<ProductVariant> currentVariants = itemToEdit != null ? List.from(itemToEdit.variants) : [];
    List<ToppingItem> currentToppings = itemToEdit != null ? List.from(itemToEdit.toppings) : [];

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
                    height: 90,
                    width: double.infinity,
                    color: Colors.grey.shade200,
                    child: imagePath == null
                        ? const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_a_photo), Text('Chọn ảnh minh họa')])
                        : Image.file(File(imagePath!), fit: BoxFit.cover),
                  ),
                ),
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Tên món chính')),
                TextField(controller: priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Giá mặc định')),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: categories.contains(cat) ? cat : categories.where((c) => c != 'Tất cả').first,
                        items: categories.where((c) => c != 'Tất cả').map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                        onChanged: (v) => setDlgState(() => cat = v!),
                        decoration: const InputDecoration(labelText: 'Danh mục'),
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.teal), onPressed: () => _showAddCategoryDialog((n) => setDlgState(() => cat = n))),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: units.contains(unit) ? unit : units.first,
                        items: units.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                        onChanged: (v) => setDlgState(() => unit = v!),
                        decoration: const InputDecoration(labelText: 'Đơn vị tính'),
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.teal), onPressed: () => _showAddUnitDialog((n) => setDlgState(() => unit = n))),
                  ],
                ),
                SwitchListTile(title: const Text('Đang kinh doanh'), value: isAvail, onChanged: (v) => setDlgState(() => isAvail = v)),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Biến thể món (Chọn 1)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                    IconButton(icon: const Icon(Icons.add_circle, color: Colors.teal), onPressed: () => setDlgState(() => currentVariants.add(ProductVariant(id: const Uuid().v4(), name: '', price: 35000))))
                  ],
                ),
                ...currentVariants.map((varItem) => Row(
                      children: [
                        Expanded(child: TextFormField(initialValue: varItem.name, decoration: const InputDecoration(hintText: 'Tên biến thể'), onChanged: (v) => varItem.name = v)),
                        const SizedBox(width: 5),
                        Expanded(child: TextFormField(initialValue: varItem.price.toStringAsFixed(0), keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: 'Giá'), onChanged: (v) => varItem.price = double.tryParse(v) ?? 0)),
                        IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => setDlgState(() => currentVariants.remove(varItem)))
                      ],
                    )),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Đồ gọi thêm (Chọn nhiều)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                    IconButton(icon: const Icon(Icons.add_circle, color: Colors.orange), onPressed: () => setDlgState(() => currentToppings.add(ToppingItem(id: const Uuid().v4(), name: '', price: 10000))))
                  ],
                ),
                ...currentToppings.map((topItem) => Row(
                      children: [
                        Expanded(child: TextFormField(initialValue: topItem.name, decoration: const InputDecoration(hintText: 'Tên đồ thêm'), onChanged: (v) => topItem.name = v)),
                        const SizedBox(width: 5),
                        Expanded(child: TextFormField(initialValue: topItem.price.toStringAsFixed(0), keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: 'Giá thêm'), onChanged: (v) => topItem.price = double.tryParse(v) ?? 0)),
                        IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => setDlgState(() => currentToppings.remove(topItem)))
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
                  MenuItem item = MenuItem(
                    id: itemToEdit?.id ?? const Uuid().v4(),
                    name: nameCtrl.text,
                    basePrice: double.tryParse(priceCtrl.text) ?? 0,
                    category: cat,
                    unit: unit,
                    imagePath: imagePath,
                    isAvailable: isAvail,
                    variants: currentVariants,
                    toppings: currentToppings,
                  );
                  _saveMenuItemToCloud(item);
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Lưu & Đồng Bộ'),
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
    List<ToppingItem> selectedToppings = [];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          bool isByWeight = item.unit == 'kg' || item.unit == 'g';
          double unitBasePrice = selectedVariant != null ? selectedVariant!.price : item.basePrice;
          double totalToppingPrice = selectedToppings.fold(0, (sum, t) => sum + t.price);
          double singlePortionPrice = unitBasePrice + totalToppingPrice;
          double finalTotalPrice = isByWeight
              ? (singlePortionPrice / (item.unit == 'kg' ? 1000 : 1)) * weightInGrams
              : singlePortionPrice * selectedQty;

          return AlertDialog(
            title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (item.variants.isNotEmpty) ...[
                    const Text('Chọn loại món (Chỉ chọn 1):', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                    ...item.variants.map((v) => RadioListTile<ProductVariant>(
                          title: Text(v.name),
                          subtitle: Text('${v.price.toStringAsFixed(0)} VNĐ'),
                          value: v,
                          groupValue: selectedVariant,
                          onChanged: (val) => setDlgState(() => selectedVariant = val),
                        )),
                    const Divider(),
                  ],
                  if (item.toppings.isNotEmpty) ...[
                    const Text('Gọi thêm (Chọn nhiều):', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                    ...item.toppings.map((t) => CheckboxListTile(
                          title: Text(t.name),
                          subtitle: Text('+${t.price.toStringAsFixed(0)} VNĐ'),
                          value: selectedToppings.contains(t),
                          onChanged: (checked) {
                            setDlgState(() {
                              if (checked == true) {
                                selectedToppings.add(t);
                              } else {
                                selectedToppings.remove(t);
                              }
                            });
                          },
                        )),
                    const Divider(),
                  ],
                  if (isByWeight) ...[
                    Text('Trọng lượng: ${weightInGrams.toStringAsFixed(0)}g'),
                    Slider(
                      value: weightInGrams,
                      min: 50,
                      max: 5000,
                      divisions: 99,
                      onChanged: (v) => setDlgState(() => weightInGrams = v),
                    ),
                  ] else ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Số lượng: '),
                        IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: selectedQty > 1 ? () => setDlgState(() => selectedQty--) : null),
                        Text('${selectedQty.toInt()}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () => setDlgState(() => selectedQty++)),
                      ],
                    ),
                  ]
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                onPressed: () {
                  String fullName = selectedVariant != null ? selectedVariant!.name : item.name;
                  if (selectedToppings.isNotEmpty) {
                    fullName += " (${selectedToppings.map((t) => t.name).join(', ')})";
                  }

                  tables[selectedTableIndex].items.add({
                    'itemId': item.id,
                    'name': fullName,
                    'unit': item.unit,
                    'quantity': isByWeight ? (weightInGrams / 1000) : selectedQty,
                    'totalPrice': finalTotalPrice,
                  });

                  _syncTableToCloud(selectedTableIndex);
                  Navigator.pop(ctx);
                },
                child: Text('Thêm • ${finalTotalPrice.toStringAsFixed(0)}đ'),
              )
            ],
          );
        },
      ),
    );
  }

  void _checkoutTable() async {
    var table = tables[selectedTableIndex];
    if (table.items.isEmpty) return;

    double total = table.items.fold(0, (sum, i) => sum + (i['totalPrice'] as double));
    String orderId = const Uuid().v4().substring(0, 6);

    Map<String, dynamic> orderData = {
      'id': orderId,
      'table': table.tableName,
      'total': total,
      'time': DateTime.now().toString().substring(0, 19),
      'items': List.from(table.items),
    };

    await _firestore.collection('orders').doc(orderId).set(orderData);
    table.items.clear();
    await _syncTableToCloud(selectedTableIndex);

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Thanh toán thành công ${total.toStringAsFixed(0)}đ')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bán Hàng ($currentRole)'),
        actions: [
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
                  ],
                ),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: currentTable.items.length,
                  itemBuilder: (c, idx) {
                    final order = currentTable.items[idx];
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(order['name']),
                      subtitle: Text("Số lượng: ${order['quantity']} ${order['unit']}"),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${(order['totalPrice'] as double).toStringAsFixed(0)}đ', style: const TextStyle(fontWeight: FontWeight.bold)),
                          IconButton(
                            icon: const Icon(Icons.remove_circle, color: Colors.red, size: 18),
                            onPressed: () {
                              currentTable.items.removeAt(idx);
                              _syncTableToCloud(selectedTableIndex);
                            },
                          )
                        ],
                      ),
                    );
                  },
                ),
                const Divider(),
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
      body: Column(
        children: [
          if (currentRole == 'Admin')
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showAddCategoryDialog(),
                      icon: const Icon(Icons.category, size: 18),
                      label: const Text('+ Thêm Danh Mục'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showAddUnitDialog(),
                      icon: const Icon(Icons.square_foot, size: 18),
                      label: const Text('+ Thêm Đơn Vị'),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: menuItems.length,
              itemBuilder: (c, i) {
                final item = menuItems[i];
                return ListTile(
                  title: Text(item.name),
                  subtitle: Text('Loại: ${item.category} | Giá: ${item.basePrice.toStringAsFixed(0)}đ / ${item.unit}\nBiến thể: ${item.variants.length} | Topping: ${item.toppings.length}'),
                  isThreeLine: true,
                  trailing: currentRole == 'Admin'
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _showAddEditItemDialog(itemToEdit: item)),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                _firestore.collection('menu').doc(item.id).delete();
                              },
                            ),
                          ],
                        )
                      : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    return Scaffold(
      appBar: AppBar(title: const Text('Lịch Sử Đơn Hàng Đồng Bộ')),
      body: ListView.builder(
        itemCount: orderHistory.length,
        itemBuilder: (c, i) => ListTile(
          title: Text("Đơn #${orderHistory[i]['id']} - ${orderHistory[i]['table']}"),
          subtitle: Text(orderHistory[i]['time'] ?? ''),
          trailing: Text('${(orderHistory[i]['total'] as num? ?? 0).toStringAsFixed(0)}đ', style: const TextStyle(fontWeight: FontWeight.bold)),
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
