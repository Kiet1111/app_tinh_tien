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
  Future<void> _logAction(String action) async {
    await FirebaseFirestore.instance.collection('logs').add({
      'action': action,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // DIALOG QUẢN LÝ DANH MỤC (THÊM / SỬA / XÓA)
  void _showManageCategoriesDialog() {
    final newCatController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            void addCategory() async {
              final name = newCatController.text.trim();
              if (name.isNotEmpty) {
                await FirebaseFirestore.instance.collection('categories').add({
                  'name': name,
                  'createdAt': FieldValue.serverTimestamp(),
                });
                newCatController.clear();
                await _logAction('Thêm danh mục mới: $name');
              }
            }

            void editCategory(String id, String oldName) {
              final editController = TextEditingController(text: oldName);
              showDialog(
                context: context,
                builder: (dCtx) => AlertDialog(
                  title: const Text('Sửa tên danh mục'),
                  content: TextField(controller: editController, decoration: const InputDecoration(labelText: 'Tên danh mục')),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Hủy')),
                    ElevatedButton(
                      onPressed: () async {
                        final newName = editController.text.trim();
                        if (newName.isNotEmpty) {
                          await FirebaseFirestore.instance.collection('categories').doc(id).update({'name': newName});
                          await _logAction('Sửa danh mục: $oldName -> $newName');
                          if (mounted) Navigator.pop(dCtx);
                        }
                      },
                      child: const Text('Lưu'),
                    ),
                  ],
                ),
              );
            }

            void deleteCategory(String id, String name) {
              showDialog(
                context: context,
                builder: (dCtx) => AlertDialog(
                  title: const Text('Xác nhận xóa danh mục'),
                  content: Text('Xóa danh mục "$name" sẽ không xóa các món thuộc danh mục này.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Hủy')),
                    ElevatedButton(
                      onPressed: () async {
                        await FirebaseFirestore.instance.collection('categories').doc(id).delete();
                        await _logAction('Xóa danh mục: $name');
                        if (mounted) Navigator.pop(dCtx);
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text('Xóa', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              );
            }

            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(child: Text('Quản Lý Danh Mục Món Ăn', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: newCatController,
                          decoration: const InputDecoration(labelText: 'Tên danh mục mới (VD: Lẩu, Đồ nướng...)', isDense: true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(onPressed: addCategory, child: const Text('Thêm')),
                    ],
                  ),
                  const Divider(height: 24),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('categories').orderBy('createdAt', descending: true).snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                        final docs = snapshot.data!.docs;
                        if (docs.isEmpty) return const Center(child: Text('Chưa có danh mục tùy chỉnh nào.'));

                        return ListView.builder(
                          itemCount: docs.length,
                          itemBuilder: (context, index) {
                            final doc = docs[index];
                            final catName = doc['name'] ?? '';
                            return ListTile(
                              title: Text(catName),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => editCategory(doc.id, catName)),
                                  IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => deleteCategory(doc.id, catName)),
                                ],
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
          },
        );
      },
    );
  }

  // FORM THÊM / SỬA MÓN ĂN
  void _openItemForm({DocumentSnapshot? doc}) {
    final isEdit = doc != null;
    final data = isEdit ? (doc.data() as Map<String, dynamic>) : {};

    final nameController = TextEditingController(text: data['name'] ?? '');
    final priceController = TextEditingController(text: data['price']?.toString() ?? '');
    String selectedCategory = data['category'] ?? 'Món chính';
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
              if (picked != null) setModalState(() => imageFile = File(picked.path));
            }

            void showAddToppingDialog() {
              final topName = TextEditingController();
              final topPrice = TextEditingController();
              showDialog(
                context: context,
                builder: (dCtx) => AlertDialog(
                  title: const Text('Thêm Topping'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(controller: topName, decoration: const InputDecoration(labelText: 'Tên Topping')),
                      TextField(controller: topPrice, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Giá thêm (VNĐ)')),
                    ],
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Hủy')),
                    ElevatedButton(
                      onPressed: () {
                        if (topName.text.isNotEmpty) {
                          setModalState(() {
                            addOns.add({'name': topName.text.trim(), 'price': double.tryParse(topPrice.text.trim()) ?? 0});
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
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng điền đủ tên và giá!')));
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
                  'category': selectedCategory,
                  'unit': selectedUnit,
                  'imageUrl': imageUrl,
                  'variants': variants,
                  'addOns': addOns,
                  'updatedAt': FieldValue.serverTimestamp(),
                };

                if (isEdit) {
                  await FirebaseFirestore.instance.collection('menu_items').doc(doc.id).update(itemData);
                  await _logAction('Cập nhật món: $name');
                } else {
                  itemData['createdAt'] = FieldValue.serverTimestamp();
                  await FirebaseFirestore.instance.collection('menu_items').add(itemData);
                  await _logAction('Thêm món mới: $name');
                }

                if (mounted) Navigator.pop(ctx);
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
              } finally {
                setModalState(() => isLoading = false);
              }
            }

            return Container(
              height: MediaQuery.of(context).size.height * 0.88,
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(child: Text(isEdit ? 'Sửa Món Ăn' : 'Thêm Món Ăn Mới', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: pickImage,
                      child: Container(
                        height: 90, width: double.infinity,
                        decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
                        child: imageFile != null
                            ? Image.file(imageFile!, fit: BoxFit.cover)
                            : (imageUrl.isNotEmpty ? Image.network(imageUrl, fit: BoxFit.cover) : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_a_photo), Text('Chọn ảnh món')])),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Tên món ăn')),
                    const SizedBox(height: 12),

                    // CHỌN DANH MỤC TỪ FIRESTORE
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Danh mục:', style: TextStyle(fontWeight: FontWeight.bold)),
                        TextButton.icon(
                          onPressed: _showManageCategoriesDialog,
                          icon: const Icon(Icons.settings, size: 18),
                          label: const Text('Quản lý danh mục'),
                        ),
                      ],
                    ),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('categories').snapshots(),
                      builder: (context, snapshot) {
                        List<String> categoryList = ['Món chính', 'Đồ uống', 'Ăn vặt', 'Topping', 'Tráng miệng', 'Khác'];
                        if (snapshot.hasData) {
                          for (var d in snapshot.data!.docs) {
                            categoryList.add(d['name']);
                          }
                        }
                        categoryList = categoryList.toSet().toList();
                        if (!categoryList.contains(selectedCategory)) selectedCategory = categoryList.first;

                        return Wrap(
                          spacing: 6,
                          children: categoryList.map((cat) {
                            return ChoiceChip(
                              label: Text(cat),
                              selected: selectedCategory == cat,
                              onSelected: (sel) {
                                if (sel) setModalState(() => selectedCategory = cat);
                              },
                            );
                          }).toList(),
                        );
                      },
                    ),

                    Row(
                      children: [
                        Expanded(child: TextField(controller: priceController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Giá bán chuẩn (VNĐ)'))),
                        const SizedBox(width: 12),
                        DropdownButton<String>(
                          value: ['Phần', 'Tô', 'Chai', 'Ly', 'kg', 'g', 'Đĩa'].contains(selectedUnit) ? selectedUnit : 'Phần',
                          items: ['Phần', 'Tô', 'Chai', 'Ly', 'kg', 'g', 'Đĩa'].map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                          onChanged: (val) => setModalState(() => selectedUnit = val!),
                        ),
                      ],
                    ),

                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Topping / Món thêm:', style: TextStyle(fontWeight: FontWeight.bold)),
                        TextButton.icon(onPressed: showAddToppingDialog, icon: const Icon(Icons.add), label: const Text('Thêm Topping')),
                      ],
                    ),
                    ...addOns.asMap().entries.map((e) => ListTile(
                          dense: true,
                          title: Text(e.value['name']),
                          subtitle: Text('+${e.value['price']} VNĐ'),
                          trailing: IconButton(icon: const Icon(Icons.remove_circle, color: Colors.red), onPressed: () => setModalState(() => addOns.removeAt(e.key))),
                        )),

                    const SizedBox(height: 16),
                    isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton(
                            onPressed: saveItem,
                            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(44), backgroundColor: Colors.deepOrange),
                            child: Text(isEdit ? 'CẬP NHẬT' : 'LƯU MÓN MỚI', style: const TextStyle(color: Colors.white)),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản Lý Món Ăn & Danh Mục'),
        actions: [
          IconButton(icon: const Icon(Icons.category), tooltip: 'Quản lý danh mục', onPressed: _showManageCategoriesDialog),
        ],
      ),
      floatingActionButton: FloatingActionButton(onPressed: () => _openItemForm(), child: const Icon(Icons.add)),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('menu_items').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('Chưa có món ăn nào. Hãy bấm + để thêm!'));

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                child: ListTile(
                  leading: data['imageUrl'] != null && data['imageUrl'].toString().isNotEmpty
                      ? Image.network(data['imageUrl'], width: 45, height: 45, fit: BoxFit.cover)
                      : const Icon(Icons.fastfood, color: Colors.orange),
                  title: Text(data['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('[${data['category'] ?? 'Món chính'}] ${data['price']} VNĐ / ${data['unit'] ?? 'Phần'}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _openItemForm(doc: doc)),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          await FirebaseFirestore.instance.collection('menu_items').doc(doc.id).delete();
                          await _logAction('Xóa món: ${data['name']}');
                        },
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
