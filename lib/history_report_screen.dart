import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HistoryReportScreen extends StatefulWidget {
  const HistoryReportScreen({Key? key}) : super(key: key);

  @override
  State<HistoryReportScreen> createState() => _HistoryReportScreenState();
}

class _HistoryReportScreenState extends State<HistoryReportScreen> {
  String _searchQuery = '';
  String _statusFilter = 'Tất cả';

  // WIDGET THỐNG KÊ DOANH THU & LỢI NHUẬN
  Widget _buildRevenueSummaryCard() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('orders').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        double dailyRevenue = 0;
        double weeklyRevenue = 0;
        double monthlyRevenue = 0;
        double totalProfit = 0;

        final now = DateTime.now();
        final todayStr = now.toIso8601String().substring(0, 10);
        final currentMonthStr = todayStr.substring(0, 7); // YYYY-MM
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));

        for (var doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final String status = data['status'] ?? 'completed';

          // Bỏ qua đơn bị hủy
          if (status == 'cancelled') continue;

          final double amount = (data['totalAmount'] ?? 0).toDouble();
          final double cost = (data['totalCostAmount'] ?? 0).toDouble();
          final String dateStr = data['dateString'] ?? '';

          // Tính toán Doanh thu Ngày
          if (dateStr == todayStr) {
            dailyRevenue += amount;
          }

          // Tính toán Doanh thu Tháng
          if (dateStr.startsWith(currentMonthStr)) {
            monthlyRevenue += amount;
            totalProfit += (amount - cost); // Lợi nhuận gộp trong tháng
          }

          // Tính toán Doanh thu Tuần
          if (dateStr.isNotEmpty) {
            try {
              DateTime orderDate = DateTime.parse(dateStr);
              if (orderDate.isAfter(startOfWeek.subtract(const Duration(days: 1)))) {
                weeklyRevenue += amount;
              }
            } catch (_) {}
          }
        }

        return Container(
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.deepOrange.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.deepOrange.shade200),
          ),
          child: Column(
            children: [
              const Text('📊 BÁO CÁO DOANH THU & LỢI NHUẬN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.deepOrange)),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatColumn('Hôm nay', dailyRevenue, Colors.blue),
                  _buildStatColumn('Tuần này', weeklyRevenue, Colors.orange),
                  _buildStatColumn('Tháng này', monthlyRevenue, Colors.purple),
                ],
              ),
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.monetization_on, color: Colors.green, size: 20),
                  const SizedBox(width: 6),
                  Text(
                    'Lợi Nhuận Tháng Này: ${totalProfit.toStringAsFixed(0)} VNĐ',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.green),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatColumn(String title, double value, Color color) {
    return Column(
      children: [
        Text(title, style: const TextStyle(fontSize: 12, color: Colors.black54)),
        const SizedBox(height: 4),
        Text(
          '${value.toStringAsFixed(0)}đ',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color),
        ),
      ],
    );
  }

  // DIALOG ĐIỀU CHỈNH HÓA ĐƠN
  void _showAdjustOrderDialog(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final double currentTotal = (data['totalAmount'] ?? 0).toDouble();
    final String currentStatus = data['status'] ?? 'completed';

    final totalController = TextEditingController(text: currentTotal.toStringAsFixed(0));
    String selectedStatus = currentStatus;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              title: Text('Điều chỉnh HĐ #${doc.id.substring(0, 5)}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Trạng thái:'),
                  DropdownButton<String>(
                    isExpanded: true,
                    value: selectedStatus,
                    items: const [
                      DropdownMenuItem(value: 'completed', child: Text('✅ Đã thanh toán')),
                      DropdownMenuItem(value: 'adjusted', child: Text('🛠️ Đã điều chỉnh')),
                      DropdownMenuItem(value: 'cancelled', child: Text('❌ Đã hủy')),
                    ],
                    onChanged: (val) { if (val != null) setDlgState(() => selectedStatus = val); },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: totalController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Số tiền thực thu (VNĐ)'),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
                ElevatedButton(
                  onPressed: () async {
                    final double? newTotal = double.tryParse(totalController.text.trim());
                    if (newTotal != null) {
                      await FirebaseFirestore.instance.collection('orders').doc(doc.id).update({
                        'totalAmount': newTotal,
                        'status': selectedStatus,
                      });
                      if (mounted) Navigator.pop(ctx);
                    }
                  },
                  child: const Text('Lưu'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tra Cứu & Báo Cáo Doanh Thu'), centerTitle: true),
      body: Column(
        children: [
          // 1. CARD THỐNG KÊ DOANH THU NGÀY / TUẦN / THÁNG & LỢI NHUẬN
          _buildRevenueSummaryCard(),

          // 2. Ô TÌM KIẾM HÓA ĐƠN
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Tra cứu theo Mã HĐ hoặc Ngày (YYYY-MM-DD)...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                isDense: true,
              ),
              onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
            ),
          ),
          const Divider(),

          // 3. DANH SÁCH LỊCH SỬ HÓA ĐƠN
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('orders').orderBy('createdAt', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                var docs = snapshot.data!.docs;
                docs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final idMatch = doc.id.toLowerCase().contains(_searchQuery);
                  final dateMatch = (data['dateString'] ?? '').toString().toLowerCase().contains(_searchQuery);
                  return idMatch || dateMatch;
                }).toList();

                if (docs.isEmpty) return const Center(child: Text('Không có dữ liệu hóa đơn.'));

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final double totalAmount = (data['totalAmount'] ?? 0).toDouble();
                    final String status = data['status'] ?? 'completed';

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: ListTile(
                        title: Text('HĐ #${doc.id.substring(0, 5)} - Trạng thái: $status', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Ngày: ${data['dateString']}\nThành tiền: ${totalAmount.toStringAsFixed(0)} VNĐ'),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit, color: Colors.orange),
                          onPressed: () => _showAdjustOrderDialog(doc),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
