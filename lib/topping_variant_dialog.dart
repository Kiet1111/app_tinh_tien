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
// 1. DIALOG QUẢN LÝ TOPPING & BIẾN THỂ (Màn hình Quản Lý Món)
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

  @override
  void dispose() {
    _tabController.dispose();
    _toppingNameCtrl.dispose();
    _toppingPriceCtrl.dispose();
    _variantNameCtrl.dispose();
    _variantPriceCtrl.dispose();
    super.dispose();
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
                        Expanded(
                          child: TextField(
                            controller: _toppingNameCtrl,
                            decoration: const InputDecoration(labelText: 'Tên Topping (VD: Trân châu)', isDense: true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _toppingPriceCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Giá (VNĐ)', isDense: true),
                          ),
                        ),
                        IconButton(
                          onPressed: _addTopping,
                          icon: const Icon(Icons.add_box, color: Colors.green, size: 32),
                        ),
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
                        Expanded(
                          child: TextField(
                            controller: _variantNameCtrl,
                            decoration: const InputDecoration(labelText: 'Tên biến thể (VD: Size L)', isDense: true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _variantPriceCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Giá phụ thu (VNĐ)', isDense: true),
                          ),
                        ),
                        IconButton(
                          onPressed: _addVariant,
                          icon: const Icon(Icons.add_box, color: Colors.green, size: 32),
                        ),
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
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(45),
              backgroundColor: Colors.deepOrange,
            ),
            child: const Text('LƯU THAY ĐỔI', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 2. DIALOG CHỌN TOPPING (ĐA SỐ LƯỢNG) & BIẾN THỂ (CHỌN 1) KHI TẠO ĐƠN HÀNG
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
      _selectedVariant = Map<String, dynamic>.from(variants.first as Map);
    }

    final List toppings = widget.menuItem['addOns'] ?? [];
    for (int i = 0; i < toppings.length; i++) {
      _toppingQuantities[i] = 0;
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

            // SỐ LƯỢNG MÓN CHÍNH
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

            // 1. BIẾN THỂ (CHỈ ĐƯỢC CHỌN 1)
            if (variants.isNotEmpty) ...[
              const Divider(height: 20),
              const Text('Biến thể / Size (Chọn 1):', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange)),
              const SizedBox(height: 6),
              Column(
                children: variants.map((v) {
                  final vMap = Map<String, dynamic>.from(v as Map);
                  return RadioListTile<Map<String, dynamic>>(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text('${vMap['name']} (+${formatMoney(vMap['price'] ?? 0)} VNĐ)'),
                    value: vMap,
                    groupValue: _selectedVariant,
                    onChanged: (val) => setState(() => _selectedVariant = val),
                  );
                }).toList(),
              ),
            ],

            // 2. TOPPING (CHỌN NHIỀU LOẠI & TÙY CHỈNH SỐ LƯỢNG)
            if (toppings.isNotEmpty) ...[
              const Divider(height: 20),
              const Text('Topping kèm theo (Tùy chọn số lượng):', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange)),
              const SizedBox(height: 6),
              Column(
                children: List.generate(toppings.length, (index) {
                  final t = toppings[index];
                  final int currentQty = _toppingQuantities[index] ?? 0;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
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
