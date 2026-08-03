import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'package:app_tinh_tien/lan_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PosApp());
}

class PosApp extends StatelessWidget {
  const PosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quản Lý Tính Tiền',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        useMaterial3: true,
      ),
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  String currentUserRole = 'Admin'; // Admin hoặc Staff

  // Dữ liệu chung
  List<Map<String, dynamic>> categories = ['Tất cả', 'Đồ uống', 'Món ăn']
      .map((e) => {'id': e, 'name': e})
      .toList();
  List<Map<String, dynamic>> products = [];
  List<Map<String, dynamic>> cart = [];
  List<Map<String, dynamic>> expenses = [];
  List<Map<String, dynamic>> orderLogs = [];
  List<Map<String, dynamic>> actionLogs = [];
  List<Map<String, dynamic>> dailyRevenueLogs = [];
  List<Map<String, dynamic>> monthlyRevenueLogs = [];

  double todayRevenue = 0;
  double monthRevenue = 0;
  String lastDateStr = '';
  int lastMonthInt = 0;

  bool isOnlineLAN = false;
  String? localIp;
  final TextEditingController _serverIpController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadDataAndCheckReset();
    _initLanStatus();
  }

  Future<void> _initLanStatus() async {
    final ip = await LanService.getLocalIp();
    setState(() {
      localIp = ip;
    });
  }

  // KHU VỰC TỰ ĐỘNG RESET DOANH THU & LƯU NHẬT KÝ
  Future<void> _loadDataAndCheckReset() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final todayStr = "${now.year}-${now.month}-${now.day}";

    lastDateStr = prefs.getString('last_date') ?? todayStr;
    lastMonthInt = prefs.getInt('last_month') ?? now.month;

    todayRevenue = prefs.getDouble('today_revenue') ?? 0;
    monthRevenue = prefs.getDouble('month_revenue') ?? 0;

    String? actionLogsJson = prefs.getString('action_logs');
    if (actionLogsJson != null) actionLogs = List<Map<String, dynamic>>.from(jsonDecode(actionLogsJson));

    String? orderLogsJson = prefs.getString('order_logs');
    if (orderLogsJson != null) orderLogs = List<Map<String, dynamic>>.from(jsonDecode(orderLogsJson));

    String? dailyLogsJson = prefs.getString('daily_revenue_logs');
    if (dailyLogsJson != null) dailyRevenueLogs = List<Map<String, dynamic>>.from(jsonDecode(dailyLogsJson));

    String? monthlyLogsJson = prefs.getString('monthly_revenue_logs');
    if (monthlyLogsJson != null) monthlyRevenueLogs = List<Map<String, dynamic>>.from(jsonDecode(monthlyLogsJson));

    String? expenseJson = prefs.getString('expenses');
    if (expenseJson != null) expenses = List<Map<String, dynamic>>.from(jsonDecode(expenseJson));

    String? productsJson = prefs.getString('products');
    if (productsJson != null) {
      products = List<Map<String, dynamic>>.from(jsonDecode(productsJson));
    } else {
      products = [
        {
          'id': '1',
          'name': 'Cà phê sữa',
          'category': 'Đồ uống',
          'price': 25000.0,
          'toppings': [
            {'name': 'Trân châu', 'price': 5000.0, 'quantity': 0},
            {'name': 'Thạch', 'price': 5000.0, 'quantity': 0}
          ]
        }
      ];
    }

    // Reset tự động ngày
    if (lastDateStr != todayStr) {
      if (todayRevenue > 0) {
        dailyRevenueLogs.add({
          'date': lastDateStr,
          'amount': todayRevenue,
        });
      }
      todayRevenue = 0;
      prefs.setString('last_date', todayStr);
      _logAction("Hệ thống tự động reset doanh thu ngày mới ($todayStr)");
    }

    // Reset tự động tháng
    if (lastMonthInt != now.month) {
      if (monthRevenue > 0) {
        monthlyRevenueLogs.add({
          'month': "${now.year}-$lastMonthInt",
          'amount': monthRevenue,
        });
      }
      monthRevenue = 0;
      prefs.setInt('last_month', now.month);
      _logAction("Hệ thống tự động reset doanh thu tháng mới (${now.month}/${now.year})");
    }

    _saveData();
    setState(() {});
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('today_revenue', todayRevenue);
    await prefs.setDouble('month_revenue', monthRevenue);
    await prefs.setString('action_logs', jsonEncode(actionLogs));
    await prefs.setString('order_logs', jsonEncode(orderLogs));
    await prefs.setString('daily_revenue_logs', jsonEncode(dailyRevenueLogs));
    await prefs.setString('monthly_revenue_logs', jsonEncode(monthlyRevenueLogs));
    await prefs.setString('expenses', jsonEncode(expenses));
    await prefs.setString('products', jsonEncode(products));
  }

  void _logAction(String message) {
    final log = {
      'time': DateTime.now().toString().substring(0, 19),
      'user': currentUserRole,
      'action': message,
    };
    actionLogs.insert(0, log);
    _saveData();
  }

  // XỬ LÝ ĐƠN HÀNG VÀ BÁN HÀNG
  void _addToCart(Map<String, dynamic> product) {
    int index = cart.indexWhere((item) => item['id'] == product['id']);
    if (index != -1) {
      cart[index]['quantity']++;
    } else {
      List<Map<String, dynamic>> copiedToppings = (product['toppings'] as List)
          .map((t) => {'name': t['name'], 'price': t['price'], 'quantity': 0})
          .toList();
      cart.add({
        'id': product['id'],
        'name': product['name'],
        'price': product['price'],
        'quantity': 1,
        'toppings': copiedToppings
      });
    }
    setState(() {});
  }

  void _checkout() async {
    if (cart.isEmpty) return;
    double total = 0;
    for (var item in cart) {
      double itemTotal = item['price'] * item['quantity'];
      for (var t in item['toppings']) {
        itemTotal += (t['price'] * t['quantity']) * item['quantity'];
      }
      total += itemTotal;
    }

    final orderData = {
      'orderId': const Uuid().v4().substring(0, 8),
      'time': DateTime.now().toString().substring(0, 19),
      'items': List.from(cart),
      'total': total,
    };

    if (isOnlineLAN && _serverIpController.text.isNotEmpty) {
      await LanService.sendOrder(_serverIpController.text.trim(), orderData);
    }

    _processNewOrder(orderData);
    setState(() {
      cart.clear();
    });
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Thanh toán thành công: ${total.toStringAsFixed(0)} VNĐ')),
    );
  }

  void _processNewOrder(Map<String, dynamic> order) {
    double total = order['total'];
    todayRevenue += total;
    monthRevenue += total;

    orderLogs.insert(0, order);
    _logAction("Tạo đơn hàng thành công #${order['orderId']} - Tổng: ${total.toStringAsFixed(0)}đ");
    _saveData();
  }

  // TÍNH TOÁN LỢI NHUẬN RÒNG
  double get totalExpenses => expenses.fold(0, (sum, item) => sum + (item['amount'] as double));
  double get netProfitToday => todayRevenue - totalExpenses;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('POS LAN - Quyền: $currentUserRole'),
        actions: [
          IconButton(
            icon: Icon(isOnlineLAN ? Icons.wifi : Icons.wifi_off, color: isOnlineLAN ? Colors.green : Colors.red),
            onPressed: _showLanConfigDialog,
          ),
          PopupMenuButton<String>(
            onSelected: (val) {
              setState(() {
                currentUserRole = val;
              });
              _logAction("Chuyển quyền sang: $val");
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'Admin', child: Text('Quyền Admin')),
              const PopupMenuItem(value: 'Staff', child: Text('Quyền Nhân viên')),
            ],
          )
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildPOSView(),
          _buildProductManagementView(),
          _buildFinanceView(),
          _buildLogsView(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.point_of_sale), label: 'Bán hàng'),
          BottomNavigationBarItem(icon: Icon(Icons.restaurant_menu), label: 'Món ăn'),
          BottomNavigationBarItem(icon: Icon(Icons.monetization_on), label: 'Doanh thu'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Nhật ký'),
        ],
      ),
    );
  }

  // DIALOG CẤU HÌNH MẠNG LAN (ONLINE / OFFLINE)
  void _showLanConfigDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Cấu hình Mạng LAN / Offline'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('IP thiết bị này: ${localIp ?? "Không kết nối Wi-Fi"}'),
              const SizedBox(height: 10),
              SwitchListTile(
                title: const Text('Chế độ Server LAN'),
                value: isOnlineLAN,
                onChanged: (val) async {
                  if (val) {
                    await LanService.startServer(orderLogs, (newOrder) {
                      setState(() {
                        _processNewOrder(newOrder);
                      });
                    });
                  } else {
                    await LanService.stopServer();
                  }
                  setDialogState(() {
                    isOnlineLAN = val;
                  });
                  setState(() {});
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _serverIpController,
                decoration: const InputDecoration(
                  labelText: 'IP Máy Chủ để đồng bộ (nếu là máy phụ)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Đóng'))
          ],
        ),
      ),
    );
  }

  // 1. MÀN HÌNH BÁN HÀNG (POS)
  Widget _buildPOSView() {
    return Column(
      children: [
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, childAspectRatio: 1.2, crossAxisSpacing: 8, mainAxisSpacing: 8),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final p = products[index];
              return Card(
                color: Colors.orange.shade50,
                child: InkWell(
                  onTap: () => _addToCart(p),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(p['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 4),
                        Text('${p['price'].toStringAsFixed(0)} VNĐ', style: const TextStyle(color: Colors.deepOrange)),
                        const SizedBox(height: 8),
                        const Icon(Icons.add_shopping_cart, color: Colors.deepOrange),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey.shade200,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Giỏ hàng: ${cart.length} món', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange, foregroundColor: Colors.white),
                onPressed: _showCartBottomSheet,
                icon: const Icon(Icons.shopping_cart),
                label: const Text('Xem Giỏ Hàng'),
              )
            ],
          ),
        )
      ],
    );
  }

  void _showCartBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          double cartTotal = 0;
          for (var item in cart) {
            double itemTotal = item['price'] * item['quantity'];
            for (var t in item['toppings']) {
              itemTotal += (t['price'] * t['quantity']) * item['quantity'];
            }
            cartTotal += itemTotal;
          }

          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text('Chi Tiết Đơn Hàng', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Divider(),
                Expanded(
                  child: ListView.builder(
                    itemCount: cart.length,
                    itemBuilder: (context, index) {
                      final item = cart[index];
                      return Card(
                        child: ExpansionTile(
                          title: Text('${item['name']} x${item['quantity']}'),
                          subtitle: Text('Giá: ${item['price'].toStringAsFixed(0)}đ'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: () {
                                  setSheetState(() {
                                    if (item['quantity'] > 1) {
                                      item['quantity']--;
                                    } else {
                                      cart.removeAt(index);
                                    }
                                  });
                                  setState(() {});
                                },
                              ),
                              Text('${item['quantity']}'),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                onPressed: () {
                                  setSheetState(() {
                                    item['quantity']++;
                                  });
                                  setState(() {});
                                },
                              ),
                            ],
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Topping:', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ...List.generate(item['toppings'].length, (tIdx) {
                                    final top = item['toppings'][tIdx];
                                    return Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('${top['name']} (+${top['price'].toStringAsFixed(0)}đ)'),
                                        Row(
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.remove, size: 16),
                                              onPressed: () {
                                                setSheetState(() {
                                                  if (top['quantity'] > 0) top['quantity']--;
                                                });
                                                setState(() {});
                                              },
                                            ),
                                            Text('${top['quantity']}'),
                                            IconButton(
                                              icon: const Icon(Icons.add, size: 16),
                                              onPressed: () {
                                                setSheetState(() {
                                                  top['quantity']++;
                                                });
                                                setState(() {});
                                              },
                                            ),
                                          ],
                                        )
                                      ],
                                    );
                                  })
                                ],
                              ),
                            )
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Text('Tổng thanh toán: ${cartTotal.toStringAsFixed(0)} VNĐ',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                    onPressed: cart.isEmpty ? null : _checkout,
                    child: const Text('XÁC NHẬN THANH TOÁN'),
                  ),
                )
              ],
            ),
          );
        },
      ),
    );
  }

  // 2. MÀN HÌNH QUẢN LÝ MÓN ÁN & DANH MỤC (CHỈ ADMIN)
  Widget _buildProductManagementView() {
    if (currentUserRole != 'Admin') {
      return const Center(child: Text('Bạn không có quyền Admin để chỉnh sửa danh mục món ăn.'));
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditProductDialog(),
        child: const Icon(Icons.add),
      ),
      body: ListView.builder(
        itemCount: products.length,
        itemBuilder: (context, index) {
          final p = products[index];
          return ListTile(
            title: Text(p['name']),
            subtitle: Text('Danh mục: ${p['category']} - Giá: ${p['price']}đ\nTopping: ${p['toppings'].length} loại'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () => _showAddEditProductDialog(product: p, index: index),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    setState(() {
                      products.removeAt(index);
                    });
                    _logAction("Xóa món ăn: ${p['name']}");
                    _saveData();
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showAddEditProductDialog({Map<String, dynamic>? product, int? index}) {
    final nameController = TextEditingController(text: product != null ? product['name'] : '');
    final priceController = TextEditingController(text: product != null ? product['price'].toString() : '');
    String selectedCategory = product != null ? product['category'] : 'Đồ uống';
    List<Map<String, dynamic>> localToppings = product != null
        ? List<Map<String, dynamic>>.from(product['toppings'])
        : [
            {'name': 'Trân châu', 'price': 5000.0, 'quantity': 0}
          ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(product == null ? 'Thêm món ăn mới' : 'Chỉnh sửa món ăn'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Tên món')),
                TextField(
                    controller: priceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Giá tiền')),
                DropdownButton<String>(
                  value: selectedCategory,
                  isExpanded: true,
                  items: ['Đồ uống', 'Món ăn']
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (val) => setDialogState(() => selectedCategory = val!),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Danh sách Topping:', style: TextStyle(fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: Colors.green),
                      onPressed: () {
                        setDialogState(() {
                          localToppings.add({'name': 'Topping mới', 'price': 5000.0, 'quantity': 0});
                        });
                      },
                    )
                  ],
                ),
                ...List.generate(localToppings.length, (tIdx) {
                  return Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: const InputDecoration(hintText: 'Tên topping'),
                          controller: TextEditingController(text: localToppings[tIdx]['name']),
                          onChanged: (val) => localToppings[tIdx]['name'] = val,
                        ),
                      ),
                      const SizedBox(width: 5),
                      SizedBox(
                        width: 70,
                        child: TextField(
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(hintText: 'Giá'),
                          controller: TextEditingController(text: localToppings[tIdx]['price'].toString()),
                          onChanged: (val) => localToppings[tIdx]['price'] = double.tryParse(val) ?? 0,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.remove_circle, color: Colors.red),
                        onPressed: () {
                          setDialogState(() {
                            localToppings.removeAt(tIdx);
                          });
                        },
                      )
                    ],
                  );
                })
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
            ElevatedButton(
              onPressed: () {
                final newP = {
                  'id': product != null ? product['id'] : const Uuid().v4(),
                  'name': nameController.text,
                  'category': selectedCategory,
                  'price': double.tryParse(priceController.text) ?? 0,
                  'toppings': localToppings,
                };
                setState(() {
                  if (index != null) {
                    products[index] = newP;
                    _logAction("Sửa thông tin món: ${newP['name']}");
                  } else {
                    products.add(newP);
                    _logAction("Thêm món ăn mới: ${newP['name']}");
                  }
                });
                _saveData();
                Navigator.pop(context);
              },
              child: const Text('Lưu'),
            )
          ],
        ),
      ),
    );
  }

  // 3. MÀN HÌNH QUẢN LÝ DOANH THU & CHI PHÍ LỢI NHUẬN RÒNG
  Widget _buildFinanceView() {
    final expenseTitleController = TextEditingController();
    final expenseAmountController = TextEditingController();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            color: Colors.blue.shade50,
            child: ListTile(
              title: const Text('Doanh thu Hôm nay'),
              trailing: Text('${todayRevenue.toStringAsFixed(0)}đ',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue)),
            ),
          ),
          Card(
            color: Colors.purple.shade50,
            child: ListTile(
              title: const Text('Doanh thu Tháng này'),
              trailing: Text('${monthRevenue.toStringAsFixed(0)}đ',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.purple)),
            ),
          ),
          Card(
            color: Colors.green.shade50,
            child: ListTile(
              title: const Text('Lợi nhuận ròng (Doanh thu - Chi phí)'),
              trailing: Text('${netProfitToday.toStringAsFixed(0)}đ',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green)),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Ghi chú Chi phí / Tiêu dùng:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              if (currentUserRole == 'Admin')
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Thêm chi phí'),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Thêm khoản chi'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextField(
                                controller: expenseTitleController,
                                decoration: const InputDecoration(labelText: 'Tiêu vào việc gì')),
                            TextField(
                                controller: expenseAmountController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(labelText: 'Số tiền chi')),
                          ],
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
                          ElevatedButton(
                            onPressed: () {
                              final amount = double.tryParse(expenseAmountController.text) ?? 0;
                              if (amount > 0) {
                                setState(() {
                                  expenses.add({
                                    'title': expenseTitleController.text,
                                    'amount': amount,
                                    'time': DateTime.now().toString().substring(0, 19)
                                  });
                                });
                                _logAction("Thêm chi phí: ${expenseTitleController.text} - $amount đ");
                                _saveData();
                              }
                              Navigator.pop(context);
                            },
                            child: const Text('Lưu'),
                          )
                        ],
                      ),
                    );
                  },
                )
            ],
          ),
          Expanded(
            child: ListView.builder(
              itemCount: expenses.length,
              itemBuilder: (context, index) {
                final ex = expenses[index];
                return ListTile(
                  title: Text(ex['title']),
                  subtitle: Text(ex['time']),
                  trailing: Text('-${ex['amount'].toStringAsFixed(0)}đ', style: const TextStyle(color: Colors.red)),
                );
              },
            ),
          )
        ],
      ),
    );
  }

  // 4. MÀN HÌNH QUẢN LÝ NHẬT KÝ (LOGS)
  Widget _buildLogsView() {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: const TabBar(
          tabs: [
            Tab(text: 'Nhật ký thao tác'),
            Tab(text: 'Nhật ký đơn hàng'),
            Tab(text: 'Lịch sử doanh thu'),
          ],
        ),
        body: TabBarView(
          children: [
            // Nhật ký thao tác
            ListView.builder(
              itemCount: actionLogs.length,
              itemBuilder: (context, index) {
                final log = actionLogs[index];
                return ListTile(
                  title: Text(log['action']),
                  subtitle: Text('${log['time']} | Người thực hiện: ${log['user']}'),
                );
              },
            ),

            // Nhật ký đơn hàng
            ListView.builder(
              itemCount: orderLogs.length,
              itemBuilder: (context, index) {
                final order = orderLogs[index];
                return ListTile(
                  title: Text('Đơn #${order['orderId']} - Tổng: ${order['total'].toStringAsFixed(0)}đ'),
                  subtitle: Text('Thời gian: ${order['time']}'),
                );
              },
            ),

            // Nhật ký doanh thu ngày và tháng
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text('Doanh thu các ngày trước:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ...dailyRevenueLogs.map((d) => ListTile(
                      title: Text('Ngày: ${d['date']}'),
                      trailing: Text('${d['amount'].toStringAsFixed(0)}đ', style: const TextStyle(color: Colors.blue)),
                    )),
                const Divider(),
                const Text('Doanh thu các tháng trước:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ...monthlyRevenueLogs.map((m) => ListTile(
                      title: Text('Tháng: ${m['month']}'),
                      trailing: Text('${m['amount'].toStringAsFixed(0)}đ', style: const TextStyle(color: Colors.purple)),
                    )),
              ],
            )
          ],
        ),
      ),
    );
  }
}
