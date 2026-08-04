import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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
  String id;
  String tableName;
  List<Map<String, dynamic>> items;
  OrderTable({required this.id, required this.tableName, required this.items});

  Map<String, dynamic> toJson() => {'id': id, 'tableName': tableName, 'items': items};
  factory OrderTable.fromJson(Map<String, dynamic> json) => OrderTable(
        id: json['id'] ?? '',
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
  List<OrderTable> tables = [];
  int selectedTableIndex = 0;

  List<Map<String, dynamic>> orderHistory = [];
  final ImagePicker _picker = ImagePicker();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
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
      if (mounted) {
        var loadedTables = snapshot.docs.map((doc) => OrderTable.fromJson(doc.data())).toList();
        if (loadedTables.isEmpty) {
          _initDefaultTables();
        } else {
          setState(() {
            tables = loadedTables;
            if (selectedTableIndex >= tables.length) {
              selectedTableIndex = 0;
            }
          });
        }
      }
    });

    _firestore.collection('config').doc('app_config').snapshots().listen((doc) {
      if (doc.exists && mounted) {
        var data = doc.data();
        if (data != null) {
          setState(() {
            if (data['categories'] != null) {
              categories = List<String>.from(data['categories']);
              if (!categories.contains('Tất cả')) categories.insert(0, 'Tất cả');
            }
            if (data['units'] != null) {
              units = List<String>.from(data['units']);
            }
          });
        }
      } else if (!doc.exists) {
        _saveConfigToCloud();
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

  Future<void> _initDefaultTables() async {
    for (int i = 1; i <= 6; i++) {
      String id = 'table_$i';
      await _firestore.collection('tables').doc(id).set({
        'id': id,
        'tableName': 'Bàn $i',
        'items': [],
      });
    }
  }

  Future<void> _saveConfigToCloud() async {
    await _firestore.collection('config').doc('app_config').set({
      'categories': categories,
      'units': units,
    });
  }

  Future<void> _saveMenuItemToCloud(MenuItem item) async {
    await _firestore.collection('menu').doc(item.id).set(item.toJson());
  }

  Future<void> _syncTableToCloud(OrderTable table) async {
    await _firestore.collection('tables').doc(table.id).set(table.toJson());
  }

  Future<String?> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      return image?.path;
    } catch (_) {
      return null;
    }
  }

  void _showAddTableDialog() {
    final nameCtrl = TextEditingController(text: 'Bàn ${tables.length + 1}');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thêm Bàn Mới'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Tên bàn'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () async {
              String name = nameCtrl.text.trim();
              if (name.isNotEmpty) {
                String id = const Uuid().v4();
                OrderTable newTable = OrderTable(id: id, tableName: name, items: []);
                await _syncTableToCloud(newTable);
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Tạo Bàn'),
          )
        ],
      ),
    );
  }

  void _deleteCurrentTable() {
    if (tables.isEmpty) return;
    var table = tables[selectedTableIndex];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Xóa ${table.tableName}?'),
        content: const Text('Bạn có chắc chắn muốn xóa bàn này khỏi hệ thống?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              await _firestore.collection('tables').doc(table.id).delete();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Xóa'),
          )
        ],
      ),
    );
  }

  void _showManageCategoriesDialog() {
    final catCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: const Text('Quản Lý Danh Mục'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: catCtrl,
                        decoration: const InputDecoration(hintText: 'Tên danh mục mới'),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: Colors.teal),
                      onPressed: () {
                        String name = catCtrl.text.trim();
                        if (name.isNotEmpty && !categories.contains(name)) {
                          setState(() => categories.add(name));
                          _saveConfigToCloud();
                          catCtrl.clear();
                          setDlgState(() {});
                        }
                      },
                    )
                  ],
                ),
                const Divider(),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: categories.length,
                    itemBuilder: (c, i) {
                      String cat = categories[i];
                      if (cat == 'Tất cả') return const SizedBox.shrink();
                      return ListTile(
                        dense: true,
                        title: Text(cat),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                          onPressed: () {
                            setState(() => categories.remove(cat));
                            _saveConfigToCloud();
                            setDlgState(() {});
                          },
                        ),
                      );
                    },
                  ),
                )
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đóng')),
          ],
        ),
      ),
    );
  }

  void _showManageUnitsDialog() {
    final unitCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: const Text('Quản Lý Đơn Vị Tính'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: unitCtrl,
                        decoration: const InputDecoration(hintText: 'Tên đơn vị tính mới'),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: Colors.teal),
                      onPressed: () {
                        String name = unitCtrl.text.trim();
                        if (name.isNotEmpty && !units.contains(name)) {
                          setState(() => units.add(name));
                          _saveConfigToCloud();
                          unitCtrl.clear();
                          setDlgState(() {});
                        }
                      },
                    )
                  ],
                ),
                const Divider(),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: units.length,
                    itemBuilder: (c, i) {
                      String u = units[i];
                      return ListTile(
                        dense: true,
                        title: Text(u),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                          onPressed: () {
                            setState(() => units.remove(u));
                            _saveConfigToCloud();
                            setDlgState(() {});
                          },
                        ),
                      );
                    },
                  ),
                )
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đóng')),
          ],
        ),
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
                TextField(controller: priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Giá mặc định (VNĐ)')),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: categories.contains(cat) ? cat : (categories.length > 1 ? categories[1] : categories.first),
                  items: categories.where((c) => c != 'Tất cả').map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setDlgState(() => cat = v!),
                  decoration: const InputDecoration(labelText: 'Danh mục'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: units.contains(unit) ? unit : units.first,
                  items: units.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                  onChanged: (v) => setDlgState(() => unit = v!),
                  decoration: const InputDecoration(labelText: 'Đơn vị tính'),
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
                        Expanded(child: TextFormField(initialValue: varItem.price.toStringAsFixed(0), keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: 'Giá VNĐ'), onChanged: (v) => varItem.price = double.tryParse(v) ?? 0)),
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
                        Expanded(child: TextFormField(initialValue: topItem.price.toStringAsFixed(0), keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: 'Giá thêm VNĐ'), onChanged: (v) => topItem.price = double.tryParse(v) ?? 0)),
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
    final kgCtrl = TextEditingController(text: '0');
    final gramCtrl = TextEditingController(text: '500');

    ProductVariant? selectedVariant = item.variants.isNotEmpty ? item.variants.first : null;
    List<ToppingItem> selectedToppings = [];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          bool isByWeight = item.unit.toLowerCase() == 'kg' || item.unit.toLowerCase() == 'g';

          double kgVal = double.tryParse(kgCtrl.text) ?? 0;
          double gramVal = double.tryParse(gramCtrl.text) ?? 0;
          double totalWeightGrams = (kgVal * 1000) + gramVal;

          double unitBasePrice = selectedVariant != null ? selectedVariant!.price : item.basePrice;
          double totalToppingPrice = selectedToppings.fold<double>(0.0, (sum, t) => sum + t.price);
          double singlePortionPrice = unitBasePrice + totalToppingPrice;

          double finalTotalPrice = 0;
          if (isByWeight) {
            finalTotalPrice = (singlePortionPrice / (item.unit.toLowerCase() == 'kg' ? 1000 : 1)) * totalWeightGrams;
          } else {
            finalTotalPrice = singlePortionPrice * selectedQty;
          }

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
                    const Text('Nhập trọng lượng:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: kgCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Số Kg',
                              border: OutlineInputBorder(),
                              suffixText: 'kg',
                            ),
                            onChanged: (_) => setDlgState(() {}),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: gramCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Số Gram',
                              border: OutlineInputBorder(),
                              suffixText: 'g',
                            ),
                            onChanged: (_) => setDlgState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('Tổng cân: ${(totalWeightGrams / 1000).toStringAsFixed(2)} kg (${totalWeightGrams.toStringAsFixed(0)}g)',
                        style: const TextStyle(fontSize: 13, color: Colors.grey)),
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
                  if (tables.isEmpty) return;
                  String fullName = selectedVariant != null ? selectedVariant!.name : item.name;
                  if (selectedToppings.isNotEmpty) {
                    fullName += " (${selectedToppings.map((t) => t.name).join(', ')})";
                  }

                  tables[selectedTableIndex].items.add({
                    'itemId': item.id,
                    'name': fullName,
                    'unit': item.unit,
                    'quantity': isByWeight ? (totalWeightGrams / 1000) : selectedQty,
                    'totalPrice': finalTotalPrice,
                  });

                  _syncTableToCloud(tables[selectedTableIndex]);
                  Navigator.pop(ctx);
                },
                child: Text('Thêm • ${finalTotalPrice.toStringAsFixed(0)} VNĐ'),
              )
            ],
          );
        },
      ),
    );
  }

  void _checkoutTable() async {
    if (tables.isEmpty) return;
    var table = tables[selectedTableIndex];
    if (table.items.isEmpty) return;

    double total = table.items.fold<double>(
      0.0, 
      (sum, i) => sum + ((i['totalPrice'] as num?)?.toDouble() ?? 0.0)
    );
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
    await _syncTableToCloud(table);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Thanh toán thành công ${total.toStringAsFixed(0)} VNĐ')));
    }
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
    var currentTable = tables.isNotEmpty ? tables[selectedTableIndex] : null;
    
    // Đã sửa lỗi ép kiểu Null Safety tại dòng này
    double currentTotal = currentTable?.items.fold<double>(
      0.0, 
      (sum, i) => sum + ((i['totalPrice'] as num?)?.toDouble() ?? 0.0)
    ) ?? 0.0;

    return Column(
      children: [
        SizedBox(
          height: 50,
          child: Row(
            children: [
              Expanded(
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
              if (currentRole == 'Admin')
                IconButton(
                  icon: const Icon(Icons.add_circle, color: Colors.teal, size: 30),
                  onPressed: _showAddTableDialog,
                  tooltip: 'Thêm bàn mới',
                )
            ],
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
                      Text('${item.basePrice.toStringAsFixed(0)} VNĐ/${item.unit}', style: const TextStyle(color: Colors.teal, fontSize: 12)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        if (currentTable != null)
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
                      if (currentRole == 'Admin')
                        TextButton.icon(
                          style: TextButton.styleFrom(foregroundColor: Colors.red),
                          onPressed: _deleteCurrentTable,
                          icon: const Icon(Icons.delete, size: 16),
                          label: const Text('Xóa bàn này', style: TextStyle(fontSize: 12)),
                        )
                    ],
                  ),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: currentTable.items.length,
                    itemBuilder: (c, idx) {
                      final order = currentTable.items[idx];
                      double itemTotal = (order['totalPrice'] as num? ?? 0).toDouble();
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(order['name'] ?? ''),
                        subtitle: Text("Số lượng: ${order['quantity']} ${order['unit']}"),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('${itemTotal.toStringAsFixed(0)} VNĐ', style: const TextStyle(fontWeight: FontWeight.bold)),
                            IconButton(
                              icon: const Icon(Icons.remove_circle, color: Colors.red, size: 18),
                              onPressed: () {
                                currentTable.items.removeAt(idx);
                                _syncTableToCloud(currentTable);
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
                      onPressed: _showManageCategoriesDialog,
                      icon: const Icon(Icons.category, size: 18),
                      label: const Text('Quản Lý Danh Mục'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _showManageUnitsDialog,
                      icon: const Icon(Icons.square_foot, size: 18),
                      label: const Text('Quản Lý Đơn Vị'),
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
                  subtitle: Text('Loại: ${item.category} | Giá: ${item.basePrice.toStringAsFixed(0)} VNĐ / ${item.unit}\nBiến thể: ${item.variants.length} | Topping: ${item.toppings.length}'),
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
          trailing: Text('${(orderHistory[i]['total'] as num? ?? 0).toStringAsFixed(0)} VNĐ', style: const TextStyle(fontWeight: FontWeight.bold)),
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

