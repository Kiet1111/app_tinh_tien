// lib/services/api_service.dart

import 'dart0:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class LocalStorageService {
  static const String _keyMenu = 'app_menu_list';
  static const String _keyOrders = 'app_orders_list';
  static const String _keyExpenses = 'app_expenses_list';
  static const String _keyLogs = 'app_activity_logs';

  static final _uuid = const Uuid();

  // Menu mặc định có hỗ trợ đơn vị tính (kg, phần...) và số lượng tồn kho
  static final List<Map<String, dynamic>> _defaultMenu = [
    {
      'id': '1',
      'name': 'Nước cốt dừa / Dừa nạo',
      'category': 'Đồ khô & Đồ làm sẵn',
      'price': 40000.0,
      'unit': 'kg',
      'stock': 50.0,
      'variants': [],
      'toppings': []
    },
    {
      'id': '2',
      'name': 'Cá khô / Tôm khô',
      'category': 'Đồ khô & Đồ làm sẵn',
      'price': 170000.0,
      'unit': 'kg',
      'stock': 20.0,
      'variants': [],
      'toppings': []
    },
    {
      'id': '3',
      'name': 'Cháo đặc biệt',
      'category': 'Món ăn',
      'price': 25000.0,
      'unit': 'phần',
      'stock': 100.0,
      'variants': [
        {'name': 'Tô vừa', 'price': 20000.0},
        {'name': 'Tô lớn', 'price': 30000.0},
      ],
      'toppings': [
        {'name': 'Thêm trứng', 'price': 5000.0},
        {'name': 'Thêm quẩy', 'price': 5000.0},
      ]
    },
  ];

  // 1. QUẢN LÝ THỰC ĐƠN & CHỈNH SỬA MÓN ĐÃ LƯU
  static Future<List<Map<String, dynamic>>> fetchMenu() async {
    final prefs = await SharedPreferences.getInstance();
    final String? menuJson = prefs.getString(_keyMenu);

    if (menuJson == null || menuJson.isEmpty) {
      await saveMenu(_defaultMenu);
      return List<Map<String, dynamic>>.from(_defaultMenu);
    }

    try {
      List<dynamic> decoded = jsonDecode(menuJson);
      return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      return List<Map<String, dynamic>>.from(_defaultMenu);
    }
  }

  static Future<bool> saveMenu(List<Map<String, dynamic>> menu) async {
    final prefs = await SharedPreferences.getInstance();
    return await prefs.setString(_keyMenu, jsonEncode(menu));
  }

  static Future<bool> addMenuItem(Map<String, dynamic> item) async {
    List<Map<String, dynamic>> currentMenu = await fetchMenu();
    item['id'] = _uuid.v4();
    currentMenu.add(item);
    bool success = await saveMenu(currentMenu);
    if (success) {
      await addLog('ADMIN_ADD_ITEM', 'Thêm món mới: ${item['name']}');
    }
    return success;
  }

  static Future<bool> updateMenuItem(Map<String, dynamic> updatedItem) async {
    List<Map<String, dynamic>> currentMenu = await fetchMenu();
    int index = currentMenu.indexWhere((element) => element['id'] == updatedItem['id']);
    if (index != -1) {
      currentMenu[index] = updatedItem;
      bool success = await saveMenu(currentMenu);
      if (success) {
        await addLog('ADMIN_UPDATE_ITEM', 'Chỉnh sửa món: ${updatedItem['name']}');
      }
      return success;
    }
    return false;
  }

  static Future<bool> deleteMenuItem(String id) async {
    List<Map<String, dynamic>> currentMenu = await fetchMenu();
    var itemToRemove = currentMenu.firstWhere((item) => item['id'] == id, orElse: () => {});
    String itemName = itemToRemove['name'] ?? id;

    currentMenu.removeWhere((item) => item['id'] == id);
    bool success = await saveMenu(currentMenu);
    if (success) {
      await addLog('ADMIN_DELETE_ITEM', 'Xóa món: $itemName');
    }
    return success;
  }

  // TRỪ SỐ LƯỢNG TỒN KHO KHI BÁN
  static Future<void> deductStock(List<Map<String, dynamic>> orderItems) async {
    List<Map<String, dynamic>> currentMenu = await fetchMenu();
    for (var orderItem in orderItems) {
      String? dishId = orderItem['dishId'];
      double qty = (orderItem['qty'] as num).toDouble();
      if (dishId != null) {
        int idx = currentMenu.indexWhere((m) => m['id'] == dishId);
        if (idx != -1) {
          double currentStock = double.tryParse(currentMenu[idx]['stock'].toString()) ?? 0.0;
          currentMenu[idx]['stock'] = (currentStock - qty).clamp(0.0, 999999.0);
        }
      }
    }
    await saveMenu(currentMenu);
  }

  // 2. LƯU VÀ LẤY ĐƠN HÀNG
  static Future<List<Map<String, dynamic>>> fetchOrders() async {
    final prefs = await SharedPreferences.getInstance();
    final String? ordersJson = prefs.getString(_keyOrders);
    if (ordersJson == null || ordersJson.isEmpty) return [];

    try {
      List<dynamic> decoded = jsonDecode(ordersJson);
      return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      return [];
    }
  }

  static Future<bool> saveOrder(Map<String, dynamic> orderData) async {
    final prefs = await SharedPreferences.getInstance();
    List<Map<String, dynamic>> currentOrders = await fetchOrders();

    orderData['id'] = _uuid.v4().substring(0, 8).toUpperCase();
    currentOrders.add(orderData);

    bool success = await prefs.setString(_keyOrders, jsonEncode(currentOrders));
    if (success) {
      double total = double.tryParse(orderData['total'].toString()) ?? 0.0;
      await deductStock(List<Map<String, dynamic>>.from(orderData['items']));
      await addLog('PAYMENT', 'Thanh toán đơn #${orderData['id']} - ${total.toStringAsFixed(0)}đ');
    }
    return success;
  }

  // 3. QUẢN LÝ CHI PHÍ (GAS, ĐIỆN, NHÀ, NHẬP HÀNG...)
  static Future<List<Map<String, dynamic>>> fetchExpenses() async {
    final prefs = await SharedPreferences.getInstance();
    final String? expJson = prefs.getString(_keyExpenses);
    if (expJson == null || expJson.isEmpty) return [];

    try {
      List<dynamic> decoded = jsonDecode(expJson);
      return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      return [];
    }
  }

  static Future<bool> addExpense(String category, double amount, String note) async {
    final prefs = await SharedPreferences.getInstance();
    List<Map<String, dynamic>> expenses = await fetchExpenses();

    expenses.add({
      'id': _uuid.v4(),
      'category': category, // Gas, Điện, Tiền nhà, Nhập hàng, Khác
      'amount': amount,
      'note': note,
      'timestamp': DateTime.now().toIso8601String(),
    });

    bool success = await prefs.setString(_keyExpenses, jsonEncode(expenses));
    if (success) {
      await addLog('EXPENSE', 'Ghi nhận chi phí [$category]: ${amount.toStringAsFixed(0)}đ');
    }
    return success;
  }

  // 4. NHẬT KÝ THAO TÁC (AUDIT LOGS)
  static Future<void> addLog(String actionType, String detail) async {
    final prefs = await SharedPreferences.getInstance();
    List<Map<String, dynamic>> currentLogs = await fetchLogs();

    currentLogs.add({
      'time': DateTime.now().toString().substring(0, 19),
      'type': actionType,
      'detail': detail,
    });

    if (currentLogs.length > 200) {
      currentLogs = currentLogs.sublist(currentLogs.length - 200);
    }

    await prefs.setString(_keyLogs, jsonEncode(currentLogs));
  }

  static Future<List<Map<String, dynamic>>> fetchLogs() async {
    final prefs = await SharedPreferences.getInstance();
    final String? logsJson = prefs.getString(_keyLogs);
    if (logsJson == null || logsJson.isEmpty) return [];

    try {
      List<dynamic> decoded = jsonDecode(logsJson);
      return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      return [];
    }
  }
}

