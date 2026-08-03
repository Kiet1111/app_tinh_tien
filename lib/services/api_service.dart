import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'https://example.com/api'; // Thay bằng URL API thực tế nếu có

  // 1. Lấy danh sách menu
  static Future<List<dynamic>> fetchMenu() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/menu'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('Error fetching menu: $e');
    }
    return [];
  }

  // 2. Thêm món mới vào menu
  static Future<bool> addMenuItem(String name, double price) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/menu'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': name, 'price': price}),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('Error adding menu item: $e');
      return false;
    }
  }

  // 3. Xóa món khỏi menu
  static Future<bool> deleteMenuItem(String id) async {
    try {
      final response = await http.delete(Uri.parse('$baseUrl/menu/$id'));
      return response.statusCode == 200;
    } catch (e) {
      print('Error deleting menu item: $e');
      return false;
    }
  }

  // 4. Lưu đơn hàng / thanh toán
  static Future<bool> saveOrder(Map<String, dynamic> orderData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/orders'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(orderData),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('Error saving order: $e');
      return false;
    }
  }

  // 5. Lấy danh sách báo cáo đơn hàng
  static Future<List<dynamic>> fetchOrders() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/orders'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('Error fetching orders: $e');
    }
    return [];
  }
}
