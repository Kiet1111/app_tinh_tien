// lib/services/api_service.dart

import 'dart:async';
import 'package:uuid/uuid.dart'; // Đảm bảo đã thêm pubspec.yaml ở các bước trước

class ApiService {
  // Danh sách món ăn được lưu trong bộ nhớ điện thoại (mô phỏng backend)
  static List<Map<String, dynamic>> _mockMenu = [
    {'id': '1', 'name': 'Cháo lòng', 'price': 25000.0},
    {'id': '2', 'name': 'Cháo gà', 'price': 25000.0},
    {'id': '3', 'name': 'Hủ tiếu', 'price': 30000.0},
    {'id': '4', 'name': 'Cà phê sữa', 'price': 15000.0},
  ];

  static final _uuid = const Uuid(); // Để tạo ID độc nhất cho món ăn mới

  // 1. Lấy danh sách menu (trả về danh sách cục bộ)
  static Future<List<Map<String, dynamic>>> fetchMenu() async {
    // Mô phỏng độ trễ mạng
    await Future.delayed(const Duration(milliseconds: 500));
    // Trả về một bản sao của danh sách để tránh sửa đổi trực tiếp
    return List<Map<String, dynamic>>.from(_mockMenu);
  }

  // 2. Thêm món mới vào menu (thao tác trên danh sách cục bộ)
  static Future<bool> addMenuItem(String name, double price) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _mockMenu.add({
      'id': _uuid.v4(), // Tạo ID ngẫu nhiên cho món mới
      'name': name,
      'price': price,
    });
    return true; // Luôn thành công
  }

  // 3. Xóa món khỏi menu (thao tác trên danh sách cục bộ)
  static Future<bool> deleteMenuItem(String id) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _mockMenu.removeWhere((item) => item['id'] == id);
    return true; // Luôn thành công
  }

  // 4. Lưu đơn hàng / thanh toán (giả lập thành công)
  static Future<bool> saveOrder(Map<String, dynamic> orderData) async {
    await Future.delayed(const Duration(milliseconds: 300));
    // Dữ liệu đơn hàng có thể được xử lý ở đây nếu cần lưu trữ thực tế
    return true; // Luôn thành công
  }

  // 5. Lấy danh sách báo cáo đơn hàng (giả lập trống vì không lưu)
  static Future<List<dynamic>> fetchOrders() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return []; // Trả về danh sách trống vì không thực sự lưu đơn hàng
  }
}
