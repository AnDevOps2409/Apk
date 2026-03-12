import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  try {
    // Sổ lệnh (Orderbook)
    final rs1 = await http.get(Uri.parse('https://restv2.fireant.vn/symbols/SSI/quotes'));
    print('FIREANT_OB: ${rs1.statusCode} ${rs1.body.substring(0, 100)}...');
  } catch(e) { print('FIREANT_OB ERR: $e'); }

  try {
    // Khối ngoại (Foreign)
    final rs2 = await http.get(Uri.parse('https://restv2.fireant.vn/symbols/SSI/historical-quotes?startDate=2026-02-01&endDate=2026-03-01'));
    print('FIREANT_FR: ${rs2.statusCode} ${rs2.body.substring(0, 100)}...');
  } catch(e) { print('FIREANT_FR ERR: $e'); }
}
