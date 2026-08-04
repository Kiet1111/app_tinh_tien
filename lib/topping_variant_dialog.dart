import 'package:flutter/material.dart';

// Hàm định dạng tiền dùng dấu chấm phân cách hàng trăm nghìn
String formatMoney(num amount) {
  String str = amount.toInt().toString();
  return str.replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (Match m) => '${m[1]}.',
  );
}

// ============================================================================
// DIALOG CHỌN TOPPING (ĐA SỐ LƯỢNG) & BIẾN THỂ (CHỌN 1) KHI TẠO ĐƠN HÀNG
// ============================================================================
class SelectToppingVariantDialog extends StatefulWidget {
  final Map<String, dynamic> menuItem;
  final Function(Map<String, dynamic> selectedOrderData) onConfirm;

  const SelectToppingVariantDialog({
    Key? key,
    required this.menuItem,
    required this.onConfirm,
  }) : super(key: key);

  @override
  State<SelectToppingVariantDialog> createState() => _SelectToppingVariantDialogState();
}

class _SelectToppingVariantDialogState extends State<SelectToppingVariantDialog> {
  int _itemQuantity = 1;
  Map<String, dynamic>? _selectedVariant; // Chỉ chọn 1 biến thể
  final Map<int, int> _toppingQuantities = {}; // {index_topping: số_lượng}

  @override
  void initState() {
    super.initState();
    final List variants = widget.menuItem['variants'] ?? [];
    if (variants.isNotEmpty) {
      _selectedVariant = variants.first; // Mặc định chọn biến thể đầu tiên
    }

    final List toppings = widget.menuItem['addOns'] ?? [];
    for (int i = 0; i < toppings.length; i++) {
      _toppingQuantities[i] = 0; // Mặc định chưa chọn topping nào
    }
  }

  double _calculateTotal() {
    double basePrice = (widget.menuItem['price'] ?? 0).toDouble();
    double variantPrice = _selectedVariant != null ? (_selectedVariant!['price'] ?? 0).toDouble() : 0.0;

    double toppingsTotalPrice = 0.0;
    final List toppings = widget.menuItem['addOns'] ?? [];
    _toppingQuantities.forEach((index, qty) {
      if (qty > 0 && index < toppings.length) {
        double tPrice = (toppings[index]['price'] ?? 0).toDouble();
        toppingsTotalPrice += tPrice * qty;
      }
    });

    return (basePrice + variantPrice + toppingsTotalPrice) * _itemQuantity;
  }

  @override
  Widget build(BuildContext context) {
    final List toppings = widget.menuItem['addOns'] ?? [];
    final List variants = widget.menuItem['variants'] ?? [];
    final String unit = widget.menuItem['unit'] ?? 'Phần';

    return AlertDialog(
      title: Text(
        widget.menuItem['name'] ?? '',
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Giá gốc: ${formatMoney(widget.menuItem['price'] ?? 0)} VNĐ / $unit',
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 12),

            // TĂNG GIẢM SỐ LƯỢNG MÓN CHÍNH
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Số lượng món:', style: TextStyle(fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                      onPressed: () {
                        if (_itemQuantity > 1) {
                          setState(() => _itemQuantity--);
                        }
                      },
                    ),
                    Text('$_itemQuantity', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                      onPressed: () => setState(() => _itemQuantity++),
                    ),
                  ],
                ),
              ],
            ),

            // 1. CHỌN BIẾN THỂ (CHỈ ĐƯỢC CHỌN 1)
            if (variants.isNotEmpty) ...[
              const Divider(height: 20),
              const Text('Biến thể / Size (Chọn 1):', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange)),
              const SizedBox(height: 6),
              Column(
                children: variants.map((v) {
                  return RadioListTile<Map<String, dynamic>>(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text('${v['name']} (+${formatMoney(v['price'] ?? 0)} VNĐ)'),
                    value: v,
                    groupValue: _selectedVariant,
                    onChanged: (val) => setState(() => _selectedVariant = val),
                  );
                }).toList(),
              ),
            ],

            // 2. CHỌN TOPPING (CHỌN NHIỀU LOẠI & NHIỀU SỐ LƯỢNG)
            if (toppings.isNotEmpty) ...[
              const Divider(height: 20),
              const Text('Topping kèm theo (Tùy chọn số lượng):', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange)),
              const SizedBox(height: 6),
              Column(
                children: List.generate(toppings.length, (index) {
                  final t = toppings[index];
                  final int currentQty = _toppingQuantities[index] ?? 0;

                  return Padding(
                    padding: const EdgeInsets.vertical: 4.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w500)),
                              Text('+${formatMoney(t['price'] ?? 0)} VNĐ', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove, size: 18, color: Colors.red),
                              onPressed: () {
                                if (currentQty > 0) {
                                  setState(() => _toppingQuantities[index] = currentQty - 1);
                                }
                              },
                            ),
                            Text('$currentQty', style: TextStyle(fontWeight: FontWeight.bold, color: currentQty > 0 ? Colors.deepOrange : Colors.black)),
                            IconButton(
                              icon: const Icon(Icons.add, size: 18, color: Colors.green),
                              onPressed: () {
                                setState(() => _toppingQuantities[index] = currentQty + 1);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange),
          onPressed: () {
            List<String> selectedToppingDetails = [];
            final List toppings = widget.menuItem['addOns'] ?? [];

            _toppingQuantities.forEach((index, qty) {
              if (qty > 0 && index < toppings.length) {
                final t = toppings[index];
                selectedToppingDetails.add('${t['name']} (x$qty)');
              }
            });

            String variantText = _selectedVariant != null ? ' [${_selectedVariant!['name']}]' : '';

            widget.onConfirm({
              'name': '${widget.menuItem['name']}$variantText',
              'quantityDisplay': '$_itemQuantity $unit',
              'addOns': selectedToppingDetails,
              'totalPrice': _calculateTotal(),
            });

            Navigator.pop(context);
          },
          child: Text(
            'THÊM (${formatMoney(_calculateTotal())} VNĐ)',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
