import 'package:flutter/material.dart';

// Hàm định dạng tiền dùng dấu chấm
String formatMoney(num amount) {
  String str = amount.toInt().toString();
  return str.replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (Match m) => '${m[1]}.',
  );
}

// ============================================================================
// 1. DIALOG QUẢN LÝ TOPPING & BIẾN THỂ (Dùng trong màn hình Quản Lý Món)
// ============================================================================
class ManageToppingVariantModal extends StatefulWidget {
  final List<Map<String, dynamic>> initialToppings;
  final List<Map<String, dynamic>> initialVariants;
  final Function(List<Map<String, dynamic>> toppings, List<Map<String, dynamic>> variants) onSave;

  const ManageToppingVariantModal({
    Key? key,
    required this.initialToppings,
    required this.initialVariants,
    required this.onSave,
  }) : super(key: key);

  @override
  State<ManageToppingVariantModal> createState() => _ManageToppingVariantModalState();
}

class _ManageToppingVariantModalState extends State<ManageToppingVariantModal> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late List<Map<String, dynamic>> _toppings;
  late List<Map<String, dynamic>> _variants;

  final _toppingNameCtrl = TextEditingController();
  final _toppingPriceCtrl = TextEditingController();
  final _variantNameCtrl = TextEditingController();
  final _variantPriceCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _toppings = List<Map<String, dynamic>>.from(widget.initialToppings);
    _variants = List<Map<String, dynamic>>.from(widget.initialVariants);
  }

  void _addTopping() {
    final name = _toppingNameCtrl.text.trim();
    final price = double.tryParse(_toppingPriceCtrl.text.trim()) ?? 0;
    if (name.isNotEmpty) {
      setState(() {
        _toppings.add({'name': name, 'price': price});
        _toppingNameCtrl.clear();
        _toppingPriceCtrl.clear();
      });
    }
  }

  void _addVariant() {
    final name = _variantNameCtrl.text.trim();
    final price = double.tryParse(_variantPriceCtrl.text.trim()) ?? 0;
    if (name.isNotEmpty) {
      setState(() {
        _variants.add({'name': name, 'price': price});
        _variantNameCtrl.clear();
        _variantPriceCtrl.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TabBar(
            controller: _tabController,
            labelColor: Colors.deepOrange,
            unselectedLabelColor: Colors.grey,
            tabs: const [
              Tab(icon: Icon(Icons.add_circle_outline), text: 'Topping / Đồ thêm'),
              Tab(icon: Icon(Icons.style), text: 'Biến thể / Size'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // TAB 1: TOPPING
                Column(
                  children: [
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: _toppingNameCtrl, decoration: const InputDecoration(labelText: 'Tên Topping (VD: Trân châu)', isDense: true))),
                        const SizedBox(width: 8),
                        Expanded(child: TextField(controller: _toppingPriceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Giá (VNĐ)', isDense: true))),
                        IconButton(onPressed: _addTopping, icon: const Icon(Icons.add_box, color: Colors.green, size: 32)),
                      ],
                    ),
                    const Divider(),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _toppings.length,
                        itemBuilder: (ctx, idx) {
                          final item = _toppings[idx];
                          return ListTile(
                            dense: true,
                            title: Text(item['name'] ?? ''),
                            subtitle: Text('+${formatMoney(item['price'] ?? 0)} VNĐ'),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                              onPressed: () => setState(() => _toppings.removeAt(idx)),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),

                // TAB 2: BIẾN THỂ (SIZE / PHÂN LOẠI)
                Column(
                  children: [
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: _variantNameCtrl, decoration: const InputDecoration(labelText: 'Tên biến thể (VD: Size L)', isDense: true))),
                        const SizedBox(width: 8),
                        Expanded(child: TextField(controller: _variantPriceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Giá phụ thu (VNĐ)', isDense: true))),
                        IconButton(onPressed: _addVariant, icon: const Icon(Icons.add_box, color: Colors.green, size: 32)),
                      ],
                    ),
                    const Divider(),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _variants.length,
                        itemBuilder: (ctx, idx) {
                          final item = _variants[idx];
                          return ListTile(
                            dense: true,
                            title: Text(item['name'] ?? ''),
                            subtitle: Text('+${formatMoney(item['price'] ?? 0)} VNĐ'),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                              onPressed: () => setState(() => _variants.removeAt(idx)),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              widget.onSave(_toppings, _variants);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(45), backgroundColor: Colors.deepOrange),
            child: const Text('LƯU THAY ĐỔI', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 2. DIALOG CHỌN TOPPING & BIẾN THỂ KHI TẠO ĐƠN (Dùng trong Màn hình Tạo Đơn)
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
  final _quantityCtrl = TextEditingController(text: '1');
  Map<String, dynamic>? _selectedVariant;
  final List<Map<String, dynamic>> _selectedToppings = [];

  double _calculateTotal() {
    double basePrice = (widget.menuItem['price'] ?? 0).toDouble();
    double qty = double.tryParse(_quantityCtrl.text.trim()) ?? 1.0;
    
    double variantPrice = _selectedVariant != null ? (_selectedVariant!['price'] ?? 0).toDouble() : 0.0;
    double toppingsPrice = 0.0;
    for (var t in _selectedToppings) {
      toppingsPrice += (t['price'] ?? 0).toDouble();
    }

    return (basePrice + variantPrice + toppingsPrice) * qty;
  }

  @override
  Widget build(BuildContext context) {
    final List toppings = widget.menuItem['addOns'] ?? [];
    final List variants = widget.menuItem['variants'] ?? [];
    final String unit = widget.menuItem['unit'] ?? 'Phần';

    return AlertDialog(
      title: Text(widget.menuItem['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Giá gốc: ${formatMoney(widget.menuItem['price'] ?? 0)} VNĐ / $unit', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),

            // SỐ LƯỢNG
            Row(
              children: [
                const Text('Số lượng:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _quantityCtrl,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),

            // DANH SÁCH BIẾN THỂ (SIZE / PHÂN LOẠI)
            if (variants.isNotEmpty) ...[
              const Divider(height: 20),
              const Text('Lựa chọn Biến thể / Size:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...variants.map((v) {
                final isSelected = _selectedVariant == v;
                return RadioListTile<Map<String, dynamic>>(
                  title: Text('${v['name']} (+${formatMoney(v['price'] ?? 0)} VNĐ)'),
                  value: v,
                  groupValue: _selectedVariant,
                  onChanged: (val) => setState(() => _selectedVariant = val),
                );
              }),
            ],

            // DANH SÁCH TOPPING
            if (toppings.isNotEmpty) ...[
              const Divider(height: 20),
              const Text('Chọn Topping kèm theo:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...toppings.map((t) {
                final isChecked = _selectedToppings.contains(t);
                return CheckboxListTile(
                  title: Text('${t['name']} (+${formatMoney(t['price'] ?? 0)} VNĐ)'),
                  value: isChecked,
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _selectedToppings.add(t);
                      } else {
                        _selectedToppings.remove(t);
                      }
                    });
                  },
                );
              }),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange),
          onPressed: () {
            double qty = double.tryParse(_quantityCtrl.text.trim()) ?? 1.0;
            if (qty <= 0) return;

            String variantText = _selectedVariant != null ? ' (${_selectedVariant!['name']})' : '';
            List<String> toppingNames = _selectedToppings.map((t) => t['name'].toString()).toList();

            widget.onConfirm({
              'name': '${widget.menuItem['name']}$variantText',
              'quantityDisplay': '$qty $unit',
              'addOns': toppingNames,
              'totalPrice': _calculateTotal(),
            });

            Navigator.pop(context);
          },
          child: Text('CỘNG (${formatMoney(_calculateTotal())} VNĐ)', style: const TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
