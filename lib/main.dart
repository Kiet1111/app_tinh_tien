import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

void main() {
  runApp(const PosApp());
}

class PosApp extends StatelessWidget {
  const PosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quản Lý Tính Tiền',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.teal,
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}

class FoodItem {
  String id;
  String name;
  double price;
  String? imagePath;

  FoodItem({
    required this.id,
    required this.name,
    required this.price,
    this.imagePath,
  });
}

class OrderItem {
  FoodItem food;
  int quantity;

  OrderItem({required this.food, this.quantity = 1});
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  List<FoodItem> foodList = [
    FoodItem(id: '1', name: 'Cà phê sữa', price: 25000),
    FoodItem(id: '2', name: 'Phở Bò', price: 50000),
    FoodItem(id: '3', name: 'Bánh Mì', price: 20000),
    FoodItem(id: '4', name: 'Trà Đào', price: 30000),
  ];

  List<OrderItem> currentOrder = [];

  double get totalPrice {
    return currentOrder.fold(0, (sum, item) => sum + (item.food.price * item.quantity));
  }

  void addToOrder(FoodItem food) {
    setState(() {
      int index = currentOrder.indexWhere((item) => item.food.id == food.id);
      if (index >= 0) {
        currentOrder[index].quantity++;
      } else {
        currentOrder.add(OrderItem(food: food));
      }
    });
  }

  void _showFoodFormDialog({FoodItem? foodToEdit}) {
    final nameController = TextEditingController(text: foodToEdit?.name ?? '');
    final priceController = TextEditingController(
        text: foodToEdit != null ? foodToEdit.price.toStringAsFixed(0) : '');
    String? selectedImagePath = foodToEdit?.imagePath;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                foodToEdit == null ? 'Thêm món mới' : 'Chỉnh sửa món',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 15),
              GestureDetector(
                onTap: () async {
                  final picker = ImagePicker();
                  final pickedFile = await picker.pickImage(source: ImageSource.gallery);
                  if (pickedFile != null) {
                    setModalState(() {
                      selectedImagePath = pickedFile.path;
                    });
                  }
                },
                child: Container(
                  height: 100,
                  width: 100,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(10),
                    image: selectedImagePath != null
                        ? DecorationImage(
                            image: FileImage(File(selectedImagePath!)),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: selectedImagePath == null
                      ? const Icon(Icons.add_a_photo, size: 40, color: Colors.grey)
                      : null,
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Tên món ăn'),
              ),
              TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Giá tiền (VNĐ)'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  final name = nameController.text.trim();
                  final price = double.tryParse(priceController.text) ?? 0;

                  if (name.isNotEmpty && price > 0) {
                    setState(() {
                      if (foodToEdit == null) {
                        foodList.add(FoodItem(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          name: name,
                          price: price,
                          imagePath: selectedImagePath,
                        ));
                      } else {
                        foodToEdit.name = name;
                        foodToEdit.price = price;
                        foodToEdit.imagePath = selectedImagePath;
                      }
                    });
                    Navigator.pop(ctx);
                  }
                },
                child: Text(foodToEdit == null ? 'Lưu món mới' : 'Cập nhật'),
              )
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentIndex == 0 ? 'Màn Hình Bán Hàng' : 'Quản Lý Thực Đơn'),
      ),
      body: _currentIndex == 0 ? _buildPosTab() : _buildMenuManagementTab(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.point_of_sale), label: 'Bán hàng'),
          BottomNavigationBarItem(icon: Icon(Icons.restaurant_menu), label: 'Thực đơn'),
        ],
      ),
    );
  }

  Widget _buildPosTab() {
    return Column(
      children: [
        Expanded(
          flex: 3,
          child: GridView.builder(
            padding: const EdgeInsets.all(10),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.1,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: foodList.length,
            itemBuilder: (ctx, index) {
              final food = foodList[index];
              return Card(
                elevation: 3,
                child: InkWell(
                  onTap: () => addToOrder(food),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: food.imagePath != null
                            ? Image.file(File(food.imagePath!), fit: BoxFit.cover)
                            : const Icon(Icons.fastfood, size: 50, color: Colors.orange),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          children: [
                            Text(food.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text('${food.price.toStringAsFixed(0)} đ',
                                style: const TextStyle(color: Colors.green)),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const Divider(height: 1),
        Expanded(
          flex: 2,
          child: Container(
            color: Colors.grey[100],
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: currentOrder.length,
                    itemBuilder: (ctx, index) {
                      final item = currentOrder[index];
                      return ListTile(
                        title: Text(item.food.name),
                        subtitle: Text('${item.food.price.toStringAsFixed(0)} đ'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove),
                              onPressed: () {
                                setState(() {
                                  if (item.quantity > 1) {
                                    item.quantity--;
                                  } else {
                                    currentOrder.removeAt(index);
                                  }
                                });
                              },
                            ),
                            Text('${item.quantity}', style: const TextStyle(fontSize: 16)),
                            IconButton(
                              icon: const Icon(Icons.add),
                              onPressed: () => setState(() => item.quantity++),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(15),
                  color: Colors.white,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Tổng tiền: ${totalPrice.toStringAsFixed(0)} đ',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                        onPressed: currentOrder.isEmpty
                            ? null
                            : () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Thanh toán thành công!')),
                                );
                                setState(() => currentOrder.clear());
                              },
                        child: const Text('Thanh Toán', style: TextStyle(color: Colors.white)),
                      )
                    ],
                  ),
                )
              ],
            ),
          ),
        )
      ],
    );
  }

  Widget _buildMenuManagementTab() {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showFoodFormDialog(),
        child: const Icon(Icons.add),
      ),
      body: ListView.builder(
        itemCount: foodList.length,
        itemBuilder: (ctx, index) {
          final food = foodList[index];
          return ListTile(
            leading: food.imagePath != null
                ? Image.file(File(food.imagePath!), width: 50, height: 50, fit: BoxFit.cover)
                : const Icon(Icons.fastfood, size: 40),
            title: Text(food.name),
            subtitle: Text('${food.price.toStringAsFixed(0)} đ'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () => _showFoodFormDialog(foodToEdit: food),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    setState(() => foodList.removeAt(index));
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

