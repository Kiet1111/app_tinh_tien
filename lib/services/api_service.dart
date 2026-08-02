import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Thay đường dẫn dưới đây bằng link API Endpoint của bạn trên MockAPI
  static const String baseUrl = 'https://66a6f70f9a7e173d95e4sadda.mockapi.io/api/v1';

  static Future<List<dynamic>> fetchMenu() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/menu'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('Lỗi kết nối Server: $e');
    }
    return [];
  }

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
}
