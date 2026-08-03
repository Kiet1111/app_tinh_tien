// lib/services/api_service.dart

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class LocalStorageService {
  static const String _keyMenu = 'app_menu_list';
  static const String _keyOrders = 'app_orders_list';
  static const String _keyLogs = 'app_activity_logs';

  static final _uuid = const Uuid();

  // Menu mặc định hoạt động Offline
  static final List<Map<String, dynamic>> _defaultMenu = [
    {
      'id': '1',
      'name': 'Cháo',
      'category': 'Món ăn',
      'price': 10000.0,
      'variants': [
        {'name': 'Cháo 10.000đ', 'price': 10000.0},
        {'name': 'Cháo 20.000đ', 'price': 20000.0},
        {'name': 'Cháo xương', 'price': 35000.0},
      ],
      'toppings': [
        {'name': 'Trứng gà', 'price': 5000.0},
        {'name': 'Quẩy', 'price': 5000.0},
        {'name': 'Thêm thịt', 'price': 10000.0},
      ]
    },
    {
      'id': '2',
      'name': 'Nước ngọt',
      'category': 'Nước uống',
      'price': 15000.0,
      'variants': [
        {'name': 'Coca Cola', 'price': 15000.0},
        {'name': 'Pepsi', 'price': 15000.0},
        {'name': 'Sting đỏ', 'price': 15000.0},
      ],
      'toppings': [
        {'name': 'Thêm đá', 'price': 0.0},
        {'name': 'Ít đường', 'price': 0.0},
      ]
    },
  ];

  // 1. CHẾ ĐỘ OFFLINE & QUẢN LÝ MENU
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

  static Future<bool> addMenuItem({
    required String name,
    required String category,
    required double defaultPrice,
    required List<Map<String, dynamic>> variants,
    required List<Map<String, dynamic>> toppings,
  }) async {
    List<Map<String, dynamic>> currentMenu = await fetchMenu();
    String newId = _uuid.v4();

    currentMenu.add({
      'id': newId,
      'name': name,
      'category': category.isEmpty ? 'Món khác' : category,
      'price': defaultPrice,
      'variants': variants,
      'toppings': toppings,
    });

    bool success = await saveMenu(currentMenu);
    if (success) {
      await addLog('ADMIN_ADD_ITEM', 'Thêm món: $name [$category]');
    }
    return success;
  }

  static Future<bool> deleteMenuItem(String id) async {
    List<Map<String, dynamic>> currentMenu = await fetchMenu();
    var itemToRemove = currentMenu.firstWhere((item) => item['id'] == id, orElse: () => {});
    String itemName = itemToRemove['name'] ?? id;

    currentMenu.removeWhere((item) => item['id'] == id);
    bool success = await saveMenu(currentMenu);
    if (success) {
      await addLog('ADMIN_DELETE_ITEM', 'Xóa món khỏi Menu: $itemName');
    }
    return success;
  }

  // 2. NHẬT KÝ THAO TÁC (AUDIT LOGS)
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

  // 3. LƯU ĐƠN HÀNG OFFLINE
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
      await addLog('PAYMENT', 'Thanh toán đơn #${orderData['id']} - ${total.toStringAsFixed(0)}đ');
    }
    return success;
  }
}
