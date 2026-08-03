// lib/services/api_service.dart

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class LocalStorageService {
  static const String _keyMenu = 'app_menu_list';
  static const String _keyOrders = 'app_orders_list';
  static const String _keyLogs = 'app_activity_logs';

  static final _uuid = const Uuid();

  // Danh sách menu mặc định ban đầu (khi mới cài app lần đầu)
  static final List<Map<String, dynamic>> _defaultMenu = [
    {'id': '1', 'name': 'Cháo lòng', 'price': 25000.0},
    {'id': '2', 'name': 'Cháo gà', 'price': 25000.0},
    {'id': '3', 'name': 'Hủ tiếu', 'price': 30000.0},
    {'id': '4', 'name': 'Cà phê sữa', 'price': 15000.0},
  ];

  // ---------------- QUẢN LÝ MENU ----------------

  // 1. Lấy danh sách menu từ bộ nhớ điện thoại
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

  // 2. Lưu toàn bộ menu vào bộ nhớ điện thoại
  static Future<bool> saveMenu(List<Map<String, dynamic>> menu) async {
    final prefs = await SharedPreferences.getInstance();
    String encoded = jsonEncode(menu);
    return await prefs.setString(_keyMenu, encoded);
  }

  // 3. Thêm món mới vào bộ nhớ điện thoại
  static Future<bool> addMenuItem(String name, double price) async {
    List<Map<String, dynamic>> currentMenu = await fetchMenu();
    String newId = _uuid.v4();
    currentMenu.add({
      'id': newId,
      'name': name,
      'price': price,
    });
    bool success = await saveMenu(currentMenu);
    if (success) {
      await addLog('ADMIN_ADD_ITEM', 'Thêm món mới: $name ($price VNĐ)');
    }
    return success;
  }

  // 4. Xóa món khỏi bộ nhớ điện thoại
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

  // ---------------- QUẢN LÝ ĐƠN HÀNG ----------------

  // 5. Lấy danh sách đơn hàng đã lưu trên điện thoại
  static Future<List<Map<String, dynamic>>> fetchOrders() async {
    final prefs = await SharedPreferences.getInstance();
    final String? ordersJson = prefs.getString(_keyOrders);

    if (ordersJson == null || ordersJson.isEmpty) {
      return [];
    }

    try {
      List<dynamic> decoded = jsonDecode(ordersJson);
      return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      return [];
    }
  }

  // 6. Lưu đơn hàng mới vào điện thoại
  static Future<bool> saveOrder(Map<String, dynamic> orderData) async {
    final prefs = await SharedPreferences.getInstance();
    List<Map<String, dynamic>> currentOrders = await fetchOrders();

    orderData['id'] = _uuid.v4().substring(0, 8).toUpperCase();
    currentOrders.add(orderData);

    String encoded = jsonEncode(currentOrders);
    bool success = await prefs.setString(_keyOrders, encoded);

    if (success) {
      double total = double.tryParse(orderData['total'].toString()) ?? 0.0;
      await addLog('NEW_ORDER', 'Thanh toán đơn #${orderData['id']} - Tổng: ${total.toStringAsFixed(0)}đ');
    }
    return success;
  }

  // ---------------- NHẬT KÝ THAO TÁC HỆ THỐNG ----------------

  // 7. Ghi lại nhật ký thao tác
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

    prefs.setString(_keyLogs, jsonEncode(currentLogs));
  }

  // 8. Lấy danh sách nhật ký thao tác
  static Future<List<Map<String, dynamic>>> fetchLogs() async {
    final prefs = await SharedPreferences.getInstance();
    final String? logsJson = prefs.getString(_keyLogs);

    if (logsJson == null || logsJson.isEmpty) {
      return [];
    }

    try {
      List<dynamic> decoded = jsonDecode(logsJson);
      return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      return [];
    }
  }
}
