import 'package:app_tinh_tien/lan_service.dart';
import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:http/http.dart' as http;

class LanService {
  static HttpServer? _server;
  static String? serverIp;
  static const int port = 8080;

  /// Lấy địa chỉ IP Wi-Fi cục bộ của thiết bị
  static Future<String?> getLocalIp() async {
    final info = NetworkInfo();
    serverIp = await info.getWifiIP();
    return serverIp;
  }

  /// Khởi chạy HTTP Server trên mạng LAN
  static Future<void> startServer(
    List<Map<String, dynamic>> orders,
    Function(Map<String, dynamic>) onNewOrder,
  ) async {
    final router = Router();

    // Route kiểm tra trạng thái kết nối
    router.get('/ping', (Request request) {
      return Response.ok(
        jsonEncode({'status': 'ok', 'message': 'Server LAN đang hoạt động'}),
        headers: {'content-type': 'application/json'},
      );
    });

    // Route lấy danh sách đơn hàng
    router.get('/orders', (Request request) {
      return Response.ok(
        jsonEncode(orders),
        headers: {'content-type': 'application/json'},
      );
    });

    // Route nhận đơn hàng mới gửi lên từ máy khách
    router.post('/orders', (Request request) async {
      final payload = await request.readAsString();
      final Map<String, dynamic> data = jsonDecode(payload);
      
      onNewOrder(data);

      return Response.ok(
        jsonEncode({'success': true, 'message': 'Đã nhận đơn hàng'}),
        headers: {'content-type': 'application/json'},
      );
    });

    final handler = const Pipeline()
        .addMiddleware(logRequests())
        .addHandler(router.call);

    // Mở server lắng nghe trên tất cả địa chỉ IP mạng nội bộ
    _server = await io.serve(handler, InternetAddress.anyIPv4, port);
    await getLocalIp();
  }

  /// Dừng HTTP Server
  static Future<void> stopServer() async {
    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
    }
  }

  /// Gửi đơn hàng tới thiết bị khác trong cùng mạng LAN
  static Future<bool> sendOrder(String targetIp, Map<String, dynamic> order) async {
    try {
      final response = await http.post(
        Uri.parse('http://$targetIp:$port/orders'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(order),
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
