import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Thay thế bằng URL MockAPI của bạn
  static const String baseUrl = 'https://66a6f70f9a7e173d95e4sadda.mockapi.io/api/v1';

  // Lấy thực đơn từ Server
  static Future<List<dynamic>> fetchMenu() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/menu'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('Lỗi fetchMenu: $e');
    }
    return [];
  }

  // Thêm món ăn mới lên Server
  static Future<bool> addMenuItem(String name, double price) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/menu'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': name, 'price': price}),
      );
      return response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  // Lưu đơn hàng vừa tạo lên Server
  static Future<bool> saveOrder(Map<String, dynamic> orderData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/orders'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(orderData),
      );
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Lấy lịch sử đơn hàng / báo cáo từ Server
  static Future<List<dynamic>> fetchOrders() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/orders'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('Lỗi fetchOrders: $e');
    }
    return [];
  }
}
