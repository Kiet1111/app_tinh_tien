// Hàm định dạng tiền VNĐ với dấu chấm phân cách hàng trăm nghìn
String formatMoney(num amount) {
  String str = amount.toInt().toString();
  return str.replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (Match m) => '${m[1]}.',
  );
}
