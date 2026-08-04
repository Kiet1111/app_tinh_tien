import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddMenuItemScreen extends StatefulWidget {
  const AddMenuItemScreen({Key? key}) : super(key: key);

  @override
  State<AddMenuItemScreen> createState() => _AddMenuItemScreenState();
}

class _AddMenuItemScreenState extends State<AddMenuItemScreen> {
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  String? _selectedUnit;
  File? _selectedImage;
  bool _isLoading = false;

  // Danh sách biến thể & đồ thêm
  List<Map<String, dynamic>> _variants = []; // vd: [{name: 'Size L', price: 10000}]
  List<Map<String, dynamic>> _addOns = [];    // vd: [{name: 'Thêm trứng', price: 5000}]

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (pickedFile != null) {
      setState(() => _selectedImage = File(pickedFile.path));
    }
  }

  void _addVariantDialog() {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thêm Biến Thể (vd: Size L, Cay ít)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Tên biến thể')),
            TextField(controller: priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Giá cộng thêm (VNĐ)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.isNotEmpty) {
                setState(() {
                  _variants.add({
                    'name': nameCtrl.text.trim(),
                    'price': double.tryParse(priceCtrl.text.trim()) ?? 0,
                  });
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text('Thêm'),
          )
        ],
      ),
    );
  }

  void _addAddOnDialog() {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thêm Đồ Ăn Kèm (vd: Thêm Trứng, Thêm Bún)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Tên món thêm')),
            TextField(controller: priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Giá tiền (VNĐ)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.isNotEmpty) {
                setState(() {
                  _addOns.add({
                    'name': nameCtrl.text.trim(),
                    'price': double.tryParse(priceCtrl.text.trim()) ?? 0,
                  });
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text('Thêm'),
          )
        ],
      ),
    );
  }

  Future<void> _saveMenuItem() async {
    final name = _nameController.text.trim();
    final priceText = _priceController.text.trim();

    if (name.isEmpty || priceText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng nhập tên và giá món!')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      String imageUrl = '';
      if (_selectedImage != null) {
        String fileName = DateTime.now().millisecondsSinceEpoch.toString();
        Reference ref = FirebaseStorage.instance.ref().child('menu_images/$fileName.jpg');
        await ref.putFile(_selectedImage!);
        imageUrl = await ref.getDownloadURL();
      }

      await FirebaseFirestore.instance.collection('menu_items').add({
        'name': name,
        'price': double.parse(priceText),
        'unit': _selectedUnit ?? 'Phần',
        'imageUrl': imageUrl,
        'variants': _variants,
        'addOns': _addOns,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã thêm món mới vào menu!')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Thêm Món Ăn Mới')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 150,
                width: double.infinity,
                decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(12)),
                child: _selectedImage != null
                    ? Image.file(_selectedImage!, fit: BoxFit.cover)
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [Icon(Icons.add_a_photo, size: 40), Text('Chọn ảnh minh họa')],
                      ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Tên món', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: TextField(controller: _priceController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Giá chuẩn (VNĐ)', border: OutlineInputBorder()))),
                const SizedBox(width: 12),
                // Chọn Đơn vị tính từ Firebase
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('units').snapshots(),
                    builder: (context, snapshot) {
                      List<String> units = ['Phần', 'Tô', 'Chai', 'Ly', 'Kg', 'g', 'Đĩa'];
                      if (snapshot.hasData) {
                        for (var doc in snapshot.data!.docs) {
                          units.add(doc['name']);
                        }
                      }
                      units = units.toSet().toList(); // Xóa trùng

                      return DropdownButtonFormField<String>(
                        value: _selectedUnit ?? units.first,
                        decoration: const InputDecoration(labelText: 'Đơn vị tính', border: OutlineInputBorder()),
                        items: units.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                        onChanged: (val) => setState(() => _selectedUnit = val),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Khối Biến thể
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Biến Thể (Size / Độ Cay...)', style: TextStyle(fontWeight: FontWeight.bold)),
                TextButton.icon(onPressed: _addVariantDialog, icon: const Icon(Icons.add), label: const Text('Thêm')),
              ],
            ),
            Wrap(
              spacing: 8,
              children: _variants.map((v) => Chip(label: Text('${v['name']} (+${v['price']}k)'), onDeleted: () => setState(() => _variants.remove(v)))).toList(),
            ),
            const Divider(),
            // Khối Đồ Ăn Kèm
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Món Ăn Kèm (Topping / Thêm)', style: TextStyle(fontWeight: FontWeight.bold)),
                TextButton.icon(onPressed: _addAddOnDialog, icon: const Icon(Icons.add), label: const Text('Thêm')),
              ],
            ),
            Wrap(
              spacing: 8,
              children: _addOns.map((a) => Chip(label: Text('${a['name']} (+${a['price']}k)'), onDeleted: () => setState(() => _addOns.remove(a)))).toList(),
            ),
            const SizedBox(height: 24),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _saveMenuItem,
                    style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    child: const Text('LƯU MÓN ĂN'),
                  ),
          ],
        ),
      ),
    );
  }
}
