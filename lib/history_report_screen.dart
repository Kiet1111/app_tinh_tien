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

  // Ghi nhật ký thao tác điều chỉnh
  Future<void> _logAction(String action) async {
    await FirebaseFirestore.instance.collection('logs').add({
      'action': action,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // DIALOG ĐIỀU CHỈNH HÓA ĐƠN
  void _showAdjustOrderDialog(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final double currentTotal = (data['totalAmount'] ?? 0).toDouble();
    final String currentStatus = data['status'] ?? 'pending';
    final String currentNote = data['adjustmentNote'] ?? '';

    final totalController = TextEditingController(text: currentTotal.toStringAsFixed(0));
    final noteController = TextEditingController(text: currentNote);
    String selectedStatus = currentStatus;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              title: Text('Điều chỉnh Hóa đơn #${doc.id.substring(0, 5)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Trạng thái hóa đơn:', style: TextStyle(fontWeight: FontWeight.bold)),
                    DropdownButton<String>(
                      isExpanded: true,
                      value: selectedStatus,
                      items: const [
                        DropdownMenuItem(value: 'pending', child: Text('⏳ Đang chờ / Chưa thanh toán')),
                        DropdownMenuItem(value: 'completed', child: Text('✅ Đã thanh toán')),
                        DropdownMenuItem(value: 'adjusted', child: Text('🛠️ Đã điều chỉnh')),
                        DropdownMenuItem(value: 'cancelled', child: Text('❌ Đã hủy hóa đơn')),
                      ],
                      onChanged: (val) {
                        if (val != null) setDlgState(() => selectedStatus = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    const Text('Tổng tiền hóa đơn (VNĐ):', style: TextStyle(fontWeight: FontWeight.bold)),
                    TextField(
                      controller: totalController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                        hintText: 'Nhập số tiền mới',
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('Lý do / Ghi chú điều chỉnh:', style: TextStyle(fontWeight: FontWeight.bold)),
                    TextField(
                      controller: noteController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'VD: Khách trả lại món, giảm giá 10%, sai trọng lượng kg...',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
                ElevatedButton(
                  onPressed: () async {
                    final double? newTotal = double.tryParse(totalController.text.trim());
                    final String note = noteController.text.trim();

                    if (newTotal == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Số tiền không hợp lệ!')));
                      return;
                    }

                    // Cập nhật hóa đơn trong Firestore
                    await FirebaseFirestore.instance.collection('orders').doc(doc.id).update({
                      'totalAmount': newTotal,
                      'status': selectedStatus,
                      'adjustmentNote': note,
                      'updatedAt': FieldValue.serverTimestamp(),
                    });

                    // Ghi log chi tiết
                    String logText = 'Điều chỉnh HĐ #${doc.id.substring(0, 5)}: '
                        'Tiền cũ ${currentTotal.toStringAsFixed(0)} -> ${newTotal.toStringAsFixed(0)} VNĐ. '
                        'Trạng thái: $selectedStatus. Lý do: ${note.isEmpty ? "Không có" : note}';
                    await _logAction(logText);

                    if (mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã cập nhật hóa đơn thành công!')));
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange),
                  child: const Text('LƯU ĐIỀU CHỈNH', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // DIALOG XEM CHI TIẾT HÓA ĐƠN
  void _showOrderDetailDialog(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final List items = data['items'] ?? [];
    final double totalAmount = (data['totalAmount'] ?? 0).toDouble();
    final String status = data['status'] ?? 'pending';
    final String note = data['adjustmentNote'] ?? '';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Chi Tiết Hóa Đơn #${doc.id.substring(0, 5)}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Trạng thái: ${_getStatusText(status)}'),
              const Divider(),
              const Text('Danh sách món:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              ...items.map((item) {
                final addOnsStr = (item['addOns'] as List? ?? []).isNotEmpty ? ' (+${(item['addOns'] as List).join(', ')})' : '';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text('- ${item['name']}$addOnsStr x ${item['quantityDisplay'] ?? item['quantity']}'),
                      ),
                      Text('${(item['totalPrice'] ?? 0).toStringAsFixed(0)} VNĐ'),
                    ],
                  ),
                );
              }).toList(),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('TỔNG TIỀN:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('${totalAmount.toStringAsFixed(0)} VNĐ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.deepOrange)),
                ],
              ),
              if (note.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('📝 Ghi chú điều chỉnh: $note', style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.blueGrey)),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đóng')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showAdjustOrderDialog(doc);
            },
            child: const Text('Điều chỉnh'),
          ),
        ],
      ),
    );
  }

  // HIỂN THỊ TRẠNG THÁI BẰNG NHÃN
  Widget _buildStatusChip(String status) {
    Color color;
    String text;
    switch (status) {
      case 'completed':
        color = Colors.green; text = 'Đã thanh toán'; break;
      case 'adjusted':
        color = Colors.blue; text = 'Đã điều chỉnh'; break;
      case 'cancelled':
        color = Colors.red; text = 'Đã hủy'; break;
      case 'pending':
      default:
        color = Colors.orange; text = 'Đang chờ'; break;
    }
    return Chip(
      label: Text(text, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
      backgroundColor: color,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'completed': return 'Đã thanh toán';
      case 'adjusted': return 'Đã điều chỉnh';
      case 'cancelled': return 'Đã hủy';
      default: return 'Đang chờ';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tra Cứu & Điều Chỉnh Hóa Đơn'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 1. THANH TÌM KIẾM
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Tra cứu theo mã HĐ hoặc ngày (VD: 2026-08-04)...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                isDense: true,
              ),
              onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
            ),
          ),

          // 2. BỘ LỌC TRẠNG THÁI
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: ['Tất cả', 'pending', 'completed', 'adjusted', 'cancelled'].map((st) {
                String labelText = st == 'Tất cả' ? 'Tất cả' : _getStatusText(st);
                return Padding(
                  padding: const EdgeInsets.only(right: 6.0),
                  child: ChoiceChip(
                    label: Text(labelText),
                    selected: _statusFilter == st,
                    onSelected: (sel) {
                      if (sel) setState(() => _statusFilter = st);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(),

          // 3. DANH SÁCH HÓA ĐƠN TRA CỨU
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('orders')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                var docs = snapshot.data!.docs;

                // Lọc theo từ khóa tìm kiếm & trạng thái
                docs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final idMatch = doc.id.toLowerCase().contains(_searchQuery);
                  final dateMatch = (data['dateString'] ?? '').toString().toLowerCase().contains(_searchQuery);
                  final matchesSearch = idMatch || dateMatch;

                  final matchesStatus = (_statusFilter == 'Tất cả') || (data['status'] == _statusFilter);

                  return matchesSearch && matchesStatus;
                }).toList();

                if (docs.isEmpty) {
                  return const Center(child: Text('Không tìm thấy hóa đơn nào phù hợp.'));
                }

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final double totalAmount = (data['totalAmount'] ?? 0).toDouble();
                    final String status = data['status'] ?? 'pending';
                    final String dateStr = data['dateString'] ?? '';

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      child: ListTile(
                        onTap: () => _showOrderDetailDialog(doc),
                        title: Row(
                          children: [
                            Text('HĐ #${doc.id.substring(0, 5)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(width: 8),
                            _buildStatusChip(status),
                          ],
                        ),
                        subtitle: Text('Ngày: $dateStr\nTổng tiền: ${totalAmount.toStringAsFixed(0)} VNĐ'),
                        isThreeLine: true,
                        trailing: ElevatedButton.icon(
                          onPressed: () => _showAdjustOrderDialog(doc),
                          icon: const Icon(Icons.edit, size: 16),
                          label: const Text('Sửa'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange.shade100,
                            foregroundColor: Colors.deepOrange,
                            elevation: 0,
                          ),
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
