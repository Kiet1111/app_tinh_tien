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

// 1. Model Biến thể món ăn (CHỈ CHỌN 1: Bún riêu thịt xắt, Bún riêu xương nạc, v.v.)
class ProductVariant {
  String id;
  String name;
  double price; // Giá của riêng biến thể này

  ProductVariant({required this.id, required this.name, required this.price});

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'price': price};
  factory ProductVariant.fromJson(Map<String, dynamic> json) => ProductVariant(
        id: json['id'],
        name: json['name'],
        price: (json['price'] as num).toDouble(),
      );
}

// 2. Model Đồ gọi thêm / Topping (CHỌN NHIỀU: Thêm giò, Thêm xương, Thêm trứng)
class ToppingItem {
  String id;
  String name;
  double price; // Giá cộng thêm khi gọi

  ToppingItem({required this.id, required this.name, required this.price});

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'price': price};
  factory ToppingItem.fromJson(Map<String, dynamic> json) => ToppingItem(
        id: json['id'],
        name: json['name'],
        price: (json['price'] as num).toDouble(),
      );
}

// 3. Model Món ăn chính
class MenuItem {
  String id;
  String name;
  double basePrice;
  String category;
  String unit;
  String? imagePath;
  bool isAvailable;
  List<ProductVariant> variants; // Danh sách các biến thể
  List<ToppingItem> toppings;     // Danh sách đồ gọi thêm

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
}

// 4. Model Bàn ăn
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

  // Danh mục & Đơn vị tính (Có thể thêm mới)
  List<String> categories = ['Tất cả', 'Đồ Ăn', 'Đồ Uống', 'Đồ Cân'];
  List<String> units = ['tô', 'dĩa', 'ly', 'kg', 'g', 'phần', 'chai', 'lon'];
  String selectedCategory = 'Tất cả';

  List<MenuItem> menuItems = [
    MenuItem(
      id: 'bun_rieu',
      name: 'Bún Riêu',
      basePrice: 35000,
      category: 'Đồ Ăn',
      unit: 'tô',
      variants: [
        ProductVariant(id: 'v1', name: 'Bún riêu thịt xắt', price: 35000),
        ProductVariant(id: 'v2', name: 'Bún riêu xương nạc', price: 40000),
        ProductVariant(id: 'v3', name: 'Bún riêu thập cẩm', price: 50000),
      ],
      toppings: [
        ToppingItem(id: 't1', name: 'Thêm giò', price: 10000),
        ToppingItem(id: 't2', name: 'Thêm xương', price: 15000),
        ToppingItem(id: 't3', name: 'Thêm trứng cút', price: 5000),
      ],
    ),
    MenuItem(
      id: 'ca_phe',
      name: 'Cà Phê',
      basePrice: 20000,
      category: 'Đồ Uống',
      unit: 'ly',
      variants: [
        ProductVariant(id: 'v4', name: 'Cà phê đen', price: 20000),
        ProductVariant(id: 'v5', name: 'Cà phê sữa', price: 25000),
      ],
      toppings: [
        ToppingItem(id: 't4', name: 'Kem cheese', price: 10000),
        ToppingItem(id: 't5', name: 'Trân châu', price: 5000),
      ],
    ),
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
    _loadCustomCategoriesAndUnits();
    _checkAndResetRevenue();
  }

  // Tải danh mục & đơn vị tính từ bộ nhớ
  Future<void> _loadCustomCategoriesAndUnits() async {
    final prefs = await SharedPreferences.getInstance();
    List<String>? savedCats = prefs.getStringList('saved_categories');
    List<String>? savedUnits = prefs.getStringList('saved_units');

    if (savedCats != null && savedCats.isNotEmpty) {
      setState(() => categories = savedCats);
    }
    if (savedUnits != null && savedUnits.isNotEmpty) {
      setState(() => units = savedUnits);
    }
  }

  // Lưu danh mục & đơn vị tính vào bộ nhớ
  Future<void> _saveCustomCategoriesAndUnits() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('saved_categories', categories);
    await prefs.setStringList('saved_units', units);
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

  // HỘP THOẠI TẠO DANH MỤC MỚI
  void _showAddCategoryDialog([Function(String)? onCategoryAdded]) {
    final catCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thêm Danh Mục Mới'),
        content: TextField(
          controller: catCtrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Tên danh mục (VD: Tráng Miệng, Sinh Tố)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () {
              String name = catCtrl.text.trim();
              if (name.isNotEmpty) {
                if (!categories.contains(name)) {
                  setState(() {
                    categories.add(name);
                  });
                  _saveCustomCategoriesAndUnits();
                  _addLog("Đã thêm danh mục mới: $name");
                  if (onCategoryAdded != null) onCategoryAdded(name);
                }
                Navigator.pop(ctx);
              }
            },
            child: const Text('Thêm'),
          )
        ],
      ),
    );
  }

  // HỘP THOẠI TẠO ĐƠN VỊ TÍNH MỚI
  void _showAddUnitDialog([Function(String)? onUnitAdded]) {
    final unitCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thêm Đơn Vị Tính Mới'),
        content: TextField(
          controller: unitCtrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Tên đơn vị (VD: hũ, chai, phần lớn)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () {
              String name = unitCtrl.text.trim();
              if (name.isNotEmpty) {
                if (!units.contains(name)) {
                  setState(() {
                    units.add(name);
                  });
                  _saveCustomCategoriesAndUnits();
                  _addLog("Đã thêm đơn vị tính mới: $name");
                  if (onUnitAdded != null) onUnitAdded(name);
                }
                Navigator.pop(ctx);
              }
            },
            child: const Text('Thêm'),
          )
        ],
      ),
    );
  }

  // QUẢN LÝ TẠO/SỬA MÓN ĂN
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
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Tên món chính (VD: Bún Riêu)')),
                TextField(controller: priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Giá mặc định (VNĐ)')),
                
                const SizedBox(height: 10),
                // LỰA CHỌN DANH MỤC + NÚT TẠO MỚI
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
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, color: Colors.teal),
                      tooltip: 'Tạo danh mục mới',
                      onPressed: () {
                        _showAddCategoryDialog((newCat) {
                          setDlgState(() => cat = newCat);
                        });
                      },
                    )
                  ],
                ),

                const SizedBox(height: 10),
                // LỰA CHỌN ĐƠN VỊ TÍNH + NÚT TẠO MỚI
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
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, color: Colors.teal),
                      tooltip: 'Tạo đơn vị tính mới',
                      onPressed: () {
                        _showAddUnitDialog((newUnit) {
                          setDlgState(() => unit = newUnit);
                        });
                      },
                    )
                  ],
                ),

                SwitchListTile(
                  title: const Text('Đang kinh doanh'),
                  value: isAvail,
                  onChanged: (v) => setDlgState(() => isAvail = v),
                ),
                const Divider(),
                
                // TẠO BIẾN THỂ MÓN
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Biến thể món (Chọn 1)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: Colors.teal),
                      onPressed: () {
                        setDlgState(() {
                          currentVariants.add(ProductVariant(id: const Uuid().v4(), name: '', price: 35000));
                        });
                      },
                    )
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
                
                // TẠO ĐỒ GỌI THÊM / TOPPING
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Đồ gọi thêm (Chọn nhiều)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: Colors.orange),
                      onPressed: () {
                        setDlgState(() {
                          currentToppings.add(ToppingItem(id: const Uuid().v4(), name: '', price: 10000));
                        });
                      },
                    )
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
                        variants: currentVariants,
                        toppings: currentToppings,
                      ));
                    } else {
                      itemToEdit.name = nameCtrl.text;
                      itemToEdit.basePrice = double.tryParse(priceCtrl.text) ?? 0;
                      itemToEdit.category = cat;
                      itemToEdit.unit = unit;
                      itemToEdit.imagePath = imagePath;
                      itemToEdit.isAvailable = isAvail;
                      itemToEdit.variants = currentVariants;
                      itemToEdit.toppings = currentToppings;
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

  // DIALOG ĐẶT MÓN VÀO BÀN
  void _showAddToCartDialog(MenuItem item) {
    double selectedQty = 1;
    double weightInGrams = 500;
    
    // Biến thể: Mặc định chọn biến thể đầu tiên (nếu có)
    ProductVariant? selectedVariant = item.variants.isNotEmpty ? item.variants.first : null;
    
    // Đồ gọi thêm: Danh sách các topping được tích chọn (Chọn nhiều)
    List<ToppingItem> selectedToppings = [];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          bool isByWeight = item.unit == 'kg' || item.unit == 'g';

          // 1. Lấy giá nền (Nếu có chọn biến thể thì lấy giá biến thể, ngược lại lấy giá gốc)
          double unitBasePrice = selectedVariant != null ? selectedVariant!.price : item.basePrice;

          // 2. Tính tổng tiền các đồ gọi thêm
          double totalToppingPrice = selectedToppings.fold(0, (sum, t) => sum + t.price);

          // 3. Tính tổng tiền cuối cùng
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
                  // --- MỤC 1: CHỌN BIẾN THỂ (CHỈ ĐƯỢC CHỌN 1) ---
                  if (item.variants.isNotEmpty) ...[
                    const Text('Chọn loại món (Bắt buộc chọn 1):', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                    const SizedBox(height: 5),
                    ...item.variants.map((v) => RadioListTile<ProductVariant>(
                          title: Text(v.name),
                          subtitle: Text('${v.price.toStringAsFixed(0)} VNĐ'),
                          value: v,
                          groupValue: selectedVariant,
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          onChanged: (val) => setDlgState(() => selectedVariant = val),
                        )),
                    const Divider(),
                  ],

                  // --- MỤC 2: CHỌN ĐỒ GỌI THÊM / TOPPING (CHỌN NHIỀU) ---
                  if (item.toppings.isNotEmpty) ...[
                    const Text('Gọi thêm (Chọn 0 hoặc nhiều):', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                    const SizedBox(height: 5),
                    ...item.toppings.map((t) {
                      bool isChecked = selectedToppings.contains(t);
                      return CheckboxListTile(
                        title: Text(t.name),
                        subtitle: Text('+${t.price.toStringAsFixed(0)} VNĐ'),
                        value: isChecked,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (bool? checked) {
                          setDlgState(() {
                            if (checked == true) {
                              selectedToppings.add(t);
                            } else {
                              selectedToppings.remove(t);
                            }
                          });
                        },
                      );
                    }),
                    const Divider(),
                  ],

                  // --- MỤC 3: CHỌN SỐ LƯỢNG HOẶC TRỌNG LƯỢNG ---
                  if (isByWeight) ...[
                    Text('Trọng lượng: ${weightInGrams.toStringAsFixed(0)}g'),
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
                        const Text('Số lượng: ', style: TextStyle(fontWeight: FontWeight.bold)),
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
                  // Tạo tên đầy đủ hiển thị trên hóa đơn
                  String fullName = selectedVariant != null ? selectedVariant!.name : item.name;
                  if (selectedToppings.isNotEmpty) {
                    String toppingNames = selectedToppings.map((t) => t.name).join(', ');
                    fullName += " ($toppingNames)";
                  }

                  setState(() {
                    tables[selectedTableIndex].items.add({
                      'itemId': item.id,
                      'name': fullName,
                      'unit': item.unit,
                      'quantity': isByWeight ? (weightInGrams / 1000) : selectedQty,
                      'totalPrice': finalTotalPrice,
                    });
                    _addLog("Thêm $fullName vào ${tables[selectedTableIndex].tableName}");
                  });
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
                            onPressed: () => setState(() => currentTable.items.removeAt(idx)),
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
                  leading: item.imagePath != null
                      ? Image.file(File(item.imagePath!), width: 50, height: 50, fit: BoxFit.cover)
                      : const Icon(Icons.fastfood),
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
          ),
        ],
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
