import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'topping_variant_dialog.dart';

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
                await _logAction('Thêm danh mục: $name');
              }
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
                          decoration: const InputDecoration(labelText: 'Tên danh mục mới', isDense: true),
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
                        return ListView.builder(
                          itemCount: docs.length,
                          itemBuilder: (context, index) {
                            final doc = docs[index];
                            return ListTile(
                              title: Text(doc['name'] ?? ''),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () async {
                                  await FirebaseFirestore.instance.collection('categories').doc(doc.id).delete();
                                },
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

  void _openItemForm({DocumentSnapshot? doc}) {
    final isEdit = doc != null;
    final data = isEdit ? (doc.data() as Map<String, dynamic>) : {};

    final nameController = TextEditingController(text: data['name'] ?? '');
    final priceController = TextEditingController(text: data['price']?.toString() ?? '');
    final costPriceController = TextEditingController(text: data['costPrice']?.toString() ?? '0');
    String selectedCategory = data['category'] ?? 'Món chính';
    String selectedUnit = data['unit'] ?? 'Phần';
    bool isAvailable = data['isAvailable'] ?? true;
    String imageUrl = data['imageUrl'] ?? '';
    File? imageFile;

    List<Map<String, dynamic>> addOns = List<Map<String, dynamic>>.from(
      (data['addOns'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map))
    );
    List<Map<String, dynamic>> variants = List<Map<String, dynamic>>.from(
      (data['variants'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map))
    );

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

            Future<void> saveItem() async {
              final name = nameController.text.trim();
              final priceText = priceController.text.trim();
              final costText = costPriceController.text.trim();

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
                  'costPrice': double.tryParse(costText) ?? 0.0,
                  'category': selectedCategory,
                  'unit': selectedUnit,
                  'isAvailable': isAvailable,
                  'imageUrl': imageUrl,
                  'addOns': addOns,
                  'variants': variants,
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
              height: MediaQuery.of(context).size.height * 0.9,
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(child: Text(isEdit ? 'Sửa Món Ăn' : 'Thêm Món Ăn Mới', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                    const SizedBox(height: 12),
                    
                    Container(
                      decoration: BoxDecoration(
                        color: isAvailable ? Colors.green.shade50 : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SwitchListTile(
                        title: Text(
                          isAvailable ? 'Món đang MỞ BÁN' : 'Món đang BỊ ẨN', 
                          style: TextStyle(fontWeight: FontWeight.bold, color: isAvailable ? Colors.green.shade900 : Colors.red.shade900),
                        ),
                        subtitle: const Text('Bật/Tắt để ẩn món khỏi thực đơn bán hàng'),
                        value: isAvailable,
                        activeColor: Colors.green,
                        onChanged: (val) => setModalState(() => isAvailable = val),
                      ),
                    ),
                    const SizedBox(height: 12),

                    GestureDetector(
                      onTap: pickImage,
                      child: Container(
                        height: 80, width: double.infinity,
                        decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
                        child: imageFile != null
                            ? Image.file(imageFile!, fit: BoxFit.cover)
                            : (imageUrl.isNotEmpty
                                ? Image.network(imageUrl, fit: BoxFit.cover)
                                : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_a_photo), Text('Chọn ảnh món')])),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Tên món ăn')),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(child: TextField(controller: priceController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Giá Bán (VNĐ)'))),
                        const SizedBox(width: 8),
                        Expanded(child: TextField(controller: costPriceController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Giá Vốn (VNĐ)'))),
                        const SizedBox(width: 8),
                        DropdownButton<String>(
                          value: ['Phần', 'Tô', 'Chai', 'Ly', 'kg', 'g', 'Đĩa'].contains(selectedUnit) ? selectedUnit : 'Phần',
                          items: ['Phần', 'Tô', 'Chai', 'Ly', 'kg', 'g', 'Đĩa'].map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                          onChanged: (val) => setModalState(() => selectedUnit = val!),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    OutlinedButton.icon(
                      icon: const Icon(Icons.tune, color: Colors.deepOrange),
                      label: Text('Cấu hình Topping (${addOns.length}) & Biến thể (${variants.length})', style: const TextStyle(color: Colors.deepOrange)),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(42),
                        side: const BorderSide(color: Colors.deepOrange),
                      ),
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          builder: (modalCtx) => ManageToppingVariantModal(
                            initialToppings: addOns,
                            initialVariants: variants,
                            onSave: (newToppings, newVariants) {
                              setModalState(() {
                                addOns = newToppings;
                                variants = newVariants;
                              });
                            },
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Danh mục:', style: TextStyle(fontWeight: FontWeight.bold)),
                        TextButton.icon(onPressed: _showManageCategoriesDialog, icon: const Icon(Icons.settings, size: 16), label: const Text('Quản lý danh mục')),
                      ],
                    ),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('categories').snapshots(),
                      builder: (context, snapshot) {
                        List<String> categoryList = ['Món chính', 'Đồ uống', 'Ăn vặt', 'Topping', 'Tráng miệng', 'Khác'];
                        if (snapshot.hasData) {
                          for (var d in snapshot.data!.docs) { categoryList.add(d['name']); }
                        }
                        categoryList = categoryList.toSet().toList();
                        if (!categoryList.contains(selectedCategory)) selectedCategory = categoryList.first;

                        return Wrap(
                          spacing: 6,
                          children: categoryList.map((cat) {
                            return ChoiceChip(
                              label: Text(cat),
                              selected: selectedCategory == cat,
                              onSelected: (sel) { if (sel) setModalState(() => selectedCategory = cat); },
                            );
                          }).toList(),
                        );
                      },
                    ),

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
        title: const Text('Quản Lý Món Ăn & Giá Vốn'),
        actions: [
          IconButton(icon: const Icon(Icons.category), tooltip: 'Danh mục', onPressed: _showManageCategoriesDialog),
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
              final bool isAvailable = data['isAvailable'] ?? true;
              final double price = (data['price'] ?? 0).toDouble();
              final double costPrice = (data['costPrice'] ?? 0).toDouble();

              return Card(
                color: isAvailable ? Colors.white : Colors.grey.shade200,
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                child: ListTile(
                  leading: data['imageUrl'] != null && data['imageUrl'].toString().isNotEmpty
                      ? Image.network(data['imageUrl'], width: 45, height: 45, fit: BoxFit.cover)
                      : const Icon(Icons.fastfood, color: Colors.orange),
                  title: Row(
                    children: [
                      Expanded(child: Text(data['name'] ?? '', style: TextStyle(fontWeight: FontWeight.bold, decoration: isAvailable ? null : TextDecoration.lineThrough))),
                      if (!isAvailable)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
                          child: const Text('ĐÃ ẨN', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  subtitle: Text('Bán: ${formatMoney(price)}đ | Vốn: ${formatMoney(costPrice)}đ / ${data['unit'] ?? 'Phần'}'),
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
