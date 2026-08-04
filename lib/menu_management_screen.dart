import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class MenuManagementScreen extends StatefulWidget {
  const MenuManagementScreen({Key? key}) : super(key: key);

  @override
  State<MenuManagementScreen> createState() => _MenuManagementScreenState();
}

class _MenuManagementScreenState extends State<MenuManagementScreen> {
  // Ghi nhật ký thao tác
  Future<void> _logAction(String action) async {
    await FirebaseFirestore.instance.collection('logs').add({
      'action': action,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Form Thêm / Sửa món ăn đầy đủ Danh mục & Topping
  void _openItemForm({DocumentSnapshot? doc}) {
    final isEdit = doc != null;
    final data = isEdit ? (doc.data() as Map<String, dynamic>) : {};

    final nameController = TextEditingController(text: data['name'] ?? '');
    final priceController = TextEditingController(text: data['price']?.toString() ?? '');
    final categoryController = TextEditingController(text: data['category'] ?? 'Món chính');
    String selectedUnit = data['unit'] ?? 'Phần';
    String imageUrl = data['imageUrl'] ?? '';
    File? imageFile;

    // Danh sách Topping & Biến thể
    List<Map<String, dynamic>> variants = List<Map<String, dynamic>>.from(data['variants'] ?? []);
    List<Map<String, dynamic>> addOns = List<Map<String, dynamic>>.from(data['addOns'] ?? []);
    bool isLoading = false;

    final categories = ['Món chính', 'Đồ uống', 'Ăn vặt', 'Topping', 'Tráng miệng', 'Khác'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> pickImage() async {
              final picker = ImagePicker();
              final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
              if (picked != null) {
                setModalState(() => imageFile = File(picked.path));
              }
            }

            // Dialog thêm Topping
            void _showAddToppingDialog() {
              final topNameController = TextEditingController();
              final topPriceController = TextEditingController();

              showDialog(
                context: context,
                builder: (dCtx) => AlertDialog(
                  title: const Text('Thêm Topping / Đồ ăn thêm'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(controller: topNameController, decoration: const InputDecoration(labelText: 'Tên Topping (VD: Trứng tráng, Chả)')),
                      TextField(controller: topPriceController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Giá cộng thêm (VNĐ)')),
                    ],
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Hủy')),
                    ElevatedButton(
                      onPressed: () {
                        if (topNameController.text.isNotEmpty) {
                          setModalState(() {
                            addOns.add({
                              'name': topNameController.text.trim(),
                              'price': double.tryParse(topPriceController.text.trim()) ?? 0,
                            });
                          });
                          Navigator.pop(dCtx);
                        }
                      },
                      child: const Text('Thêm'),
                    ),
                  ],
                ),
              );
            }

            // Dialog thêm Biến thể
            void _showAddVariantDialog() {
              final varNameController = TextEditingController();
              final varPriceController = TextEditingController();

              showDialog(
                context: context,
                builder: (dCtx) => AlertDialog(
                  title: const Text('Thêm Biến thể / Size'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(controller: varNameController, decoration: const InputDecoration(labelText: 'Tên biến thể (VD: Size L, Cay vừa)')),
                      TextField(controller: varPriceController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Giá chênh lệch (VNĐ)')),
                    ],
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Hủy')),
                    ElevatedButton(
                      onPressed: () {
                        if (varNameController.text.isNotEmpty) {
                          setModalState(() {
                            variants.add({
                              'name': varNameController.text.trim(),
                              'price': double.tryParse(varPriceController.text.trim()) ?? 0,
                            });
                          });
                          Navigator.pop(dCtx);
                        }
                      },
                      child: const Text('Thêm'),
                    ),
                  ],
                ),
              );
            }

            Future<void> saveItem() async {
              final name = nameController.text.trim();
              final priceText = priceController.text.trim();

              if (name.isEmpty || priceText.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Vui lòng nhập tên và giá món!')),
                );
                return;
              }

              setModalState(() => isLoading = true);

              try {
                if (imageFile != null) {
                  String fileName = DateTime.now().millisecondsSinceEpoch.toString();
                  Reference ref = FirebaseStorage.instance.ref().child('menu_images/$fileName.jpg');
                  await ref.putFile(imageFile!);
                  imageUrl = await ref.getDownloadURL();
                }

                final itemData = {
                  'name': name,
                  'price': double.parse(priceText),
                  'category': categoryController.text,
                  'unit': selectedUnit,
                  'imageUrl': imageUrl,
                  'variants': variants,
                  'addOns': addOns,
                  'updatedAt': FieldValue.serverTimestamp(),
                };

                if (isEdit) {
                  await FirebaseFirestore.instance.collection('menu_items').doc(doc.id).update(itemData);
                  await _logAction('Cập nhật món ăn: $name');
                } else {
                  itemData['createdAt'] = FieldValue.serverTimestamp();
                  await FirebaseFirestore.instance.collection('menu_items').add(itemData);
                  await _logAction('Thêm món ăn mới: $name');
                }

                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(isEdit ? 'Đã cập nhật món!' : 'Đã thêm món mới!')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
                }
              } finally {
                setModalState(() => isLoading = false);
              }
            }

            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Text(
                        isEdit ? 'Sửa Món Ăn' : 'Thêm Món Ăn Mới',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Chọn ảnh
                    GestureDetector(
                      onTap: pickImage,
                      child: Container(
                        height: 100, width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: imageFile != null
                            ? Image.file(imageFile!, fit: BoxFit.cover)
                            : (imageUrl.isNotEmpty
                                ? Image.network(imageUrl, fit: BoxFit.cover)
                                : const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [Icon(Icons.add_a_photo), Text('Chọn ảnh món ăn')],
                                  )),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Tên món ăn')),
                    
                    // Danh mục món ăn
                    const SizedBox(height: 12),
                    const Text('Danh Mục Món:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Wrap(
                      spacing: 8,
                      children: categories.map((cat) {
                        final isSelected = categoryController.text == cat;
                        return ChoiceChip(
                          label: Text(cat),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) setModalState(() => categoryController.text = cat);
                          },
                        );
                      }).toList(),
                    ),

                    Row(
                      children: [
                        Expanded(child: TextField(controller: priceController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Giá chuẩn (VNĐ)'))),
                        const SizedBox(width: 12),
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance.collection('units').snapshots(),
                          builder: (context, snapshot) {
                            List<String> units = ['Phần', 'Tô', 'Chai', 'Ly', 'Kg', 'Đĩa'];
                            if (snapshot.hasData) {
                              for (var d in snapshot.data!.docs) {
                                units.add(d['name']);
                              }
                            }
                            units = units.toSet().toList();
                            return DropdownButton<String>(
                              value: units.contains(selectedUnit) ? selectedUnit : units.first,
                              items: units.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                              onChanged: (val) => setModalState(() => selectedUnit = val!),
                            );
                          },
                        ),
                      ],
                    ),

                    const Divider(height: 24),
                    // Phần Topping
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Danh sách Topping / Đồ ăn thêm:', style: TextStyle(fontWeight: FontWeight.bold)),
                        TextButton.icon(
                          onPressed: _showAddToppingDialog,
                          icon: const Icon(Icons.add_circle, color: Colors.green),
                          label: const Text('Thêm Topping'),
                        ),
                      ],
                    ),
                    ...addOns.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final top = entry.value;
                      return ListTile(
                        dense: true,
                        title: Text(top['name']),
                        subtitle: Text('+${top['price']} VNĐ'),
                        trailing: IconButton(
                          icon: const Icon(Icons.remove_circle, color: Colors.red, size: 20),
                          onPressed: () => setModalState(() => addOns.removeAt(idx)),
                        ),
                      );
                    }).toList(),

                    const Divider(height: 24),
                    // Phần Biến thể
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Danh sách Biến thể / Size:', style: TextStyle(fontWeight: FontWeight.bold)),
                        TextButton.icon(
                          onPressed: _showAddVariantDialog,
                          icon: const Icon(Icons.add_circle, color: Colors.blue),
                          label: const Text('Thêm Biến thể'),
                        ),
                      ],
                    ),
                    ...variants.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final v = entry.value;
                      return ListTile(
                        dense: true,
                        title: Text(v['name']),
                        subtitle: Text('+${v['price']} VNĐ'),
                        trailing: IconButton(
                          icon: const Icon(Icons.remove_circle, color: Colors.red, size: 20),
                          onPressed: () => setModalState(() => variants.removeAt(idx)),
                        ),
                      );
                    }).toList(),

                    const SizedBox(height: 16),
                    isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton(
                            onPressed: saveItem,
                            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(44), backgroundColor: Colors.deepOrange),
                            child: Text(isEdit ? 'CẬP NHẬT MÓN' : 'LƯU MÓN MỚI', style: const TextStyle(color: Colors.white)),
                          ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Xóa món ăn
  void _deleteItem(String id, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Bạn có chắc muốn xóa món "$name"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await FirebaseFirestore.instance.collection('menu_items').doc(id).delete();
              await _logAction('Đã xóa món: $name');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xóa', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quản Lý Món Ăn & Topping'), centerTitle: true),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openItemForm(),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('menu_items').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(child: Text('Chưa có món ăn nào. Hãy bấm + để thêm món & topping!'));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final name = data['name'] ?? '';
              final price = (data['price'] ?? 0).toDouble();
              final category = data['category'] ?? 'Món chính';
              final unit = data['unit'] ?? 'Phần';
              final imageUrl = data['imageUrl'] ?? '';
              final addOnsList = List.from(data['addOns'] ?? []);

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: imageUrl.isNotEmpty
                      ? Image.network(imageUrl, width: 50, height: 50, fit: BoxFit.cover)
                      : const Icon(Icons.fastfood, size: 40, color: Colors.orange),
                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('[$category] ${price.toStringAsFixed(0)} VNĐ / $unit\nTopping: ${addOnsList.length} món'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _openItemForm(doc: doc),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteItem(doc.id, name),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
