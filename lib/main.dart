import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'orders_screen.dart';
import 'menu_management_screen.dart';
import 'unit_management_screen.dart';
import 'expense_screen.dart';
import 'history_report_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyDOD0ChXgfnUmFcFWG4IoYA7NL-pVGd5pY",
        appId: "1:762842766866:android:a6f619e711641c61b882cb",
        messagingSenderId: "762842766866",
        projectId: "app-tinh-tien-65657",
        storageBucket: "app-tinh-tien-65657.firebasestorage.app",
      ),
    );
  } catch (e) {
    debugPrint("Lỗi kết nối Firebase: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quản Lý Bán Hàng',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        useMaterial3: true,
      ),
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({Key? key}) : super(key: key);

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const OrdersScreen(),
    const MenuManagementScreen(),
    const UnitManagementScreen(),
    const ExpenseScreen(),
    const HistoryReportScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.deepOrange,
        unselectedItemColor: Colors.grey,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: 'Đơn hàng'),
          BottomNavigationBarItem(icon: Icon(Icons.restaurant_menu), label: 'Món ăn'),
          BottomNavigationBarItem(icon: Icon(Icons.square_foot), label: 'Đơn vị'),
          BottomNavigationBarItem(icon: Icon(Icons.money_off), label: 'Chi phí'),
          BottomNavigationBarItem(icon: Icon(Icons.analytics), label: 'Lịch sử'),
        ],
      ),
    );
  }
}
