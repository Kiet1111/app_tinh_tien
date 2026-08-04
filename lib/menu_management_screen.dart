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

  // Form Thêm / Sửa món ăn bằng Modal Sheet (không làm đen màn hình)
  void _openItemForm({DocumentSnapshot? doc}) {
    final isEdit = doc != null;
    final data = isEdit ? (doc.data() as Map<String, dynamic>) : {};

    final nameController = TextEditingController(text: data['name'] ?? '');
    final priceController = TextEditingController(text: data['price']?.toString() ?? '');
    String selectedUnit = data['unit'] ?? 'Phần';
    String imageUrl = data['imageUrl'] ?? '';
    File? imageFile;
    List<Map<String, dynamic>> variants = List<Map<String, dynamic>>.from(data['variants'] ?? []);
    List<Map<String, dynamic>> addOns = List<Map<String, dynamic>>.from(data['addOns'] ?? []);
    bool isLoading = false;

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
                  Navigator.pop(ctx); // Đóng BottomSheet an toàn, KHÔNG gây đen màn
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

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                top: 16, left: 16, right: 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isEdit ? 'Sửa Món Ăn' : 'Thêm Món Ăn Mới',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: pickImage,
                      child: Container(
                        height: 120, width: double.infinity,
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
                                    children: [Icon(Icons.add_a_photo), Text('Chọn ảnh')],
                                  )),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Tên món')),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: priceController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Giá chuẩn (VNĐ)'))),
                        const SizedBox(width: 12),
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance.collection('units').snapshots(),
                          builder: (context, snapshot) {
                            List<String> units = ['Phần', 'Tô', 'Chai', 'Ly', 'Kg', 'g', 'Đĩa'];
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
                    const SizedBox(height: 12),
                    isLoading
                        ? const CircularProgressIndicator()
                        : ElevatedButton(
                            onPressed: saveItem,
                            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                            child: Text(isEdit ? 'CẬP NHẬT MÓN' : 'LƯU MÓN MỚI'),
                          ),
                    const SizedBox(height: 16),
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
      appBar: AppBar(title: const Text('Quản Lý Món Ăn'), centerTitle: true),
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
            return const Center(child: Text('Chưa có món ăn nào. Hãy bấm + để thêm!'));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final name = data['name'] ?? '';
              final price = (data['price'] ?? 0).toDouble();
              final unit = data['unit'] ?? 'Phần';
              final imageUrl = data['imageUrl'] ?? '';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: imageUrl.isNotEmpty
                      ? Image.network(imageUrl, width: 50, height: 50, fit: BoxFit.cover)
                      : const Icon(Icons.fastfood, size: 40, color: Colors.orange),
                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${price.toStringAsFixed(0)} VNĐ / $unit'),
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
