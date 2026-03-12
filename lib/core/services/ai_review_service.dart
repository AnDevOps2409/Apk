import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/trade_log.dart';

class AiReviewService {
  static const _apiKeyPref = 'gemini_api_key';
  static const _apiUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';

  // ── API Key management ────────────────────────────────────────────────────

  Future<String?> loadApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_apiKeyPref);
  }

  Future<void> saveApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiKeyPref, key.trim());
  }

  // ── Review a trade ────────────────────────────────────────────────────────

  Future<String> reviewTrade(TradeLog log) async {
    final apiKey = await loadApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('Chưa nhập Gemini API Key. Vào Cài đặt → AI Coach để nhập.');
    }

    final prompt = _buildPrompt(log);
    final response = await http.post(
      Uri.parse('$_apiUrl?key=$apiKey'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'system_instruction': {
          'parts': [{'text': _systemPrompt}],
        },
        'contents': [
          {
            'parts': [{'text': prompt}],
          }
        ],
        'generationConfig': {
          'temperature': 0.4,
          'maxOutputTokens': 1024,
        },
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Gemini API lỗi ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'] as String?;
    if (text == null) throw Exception('Gemini không trả về kết quả.');
    return text;
  }

  // ── Prompt builder ────────────────────────────────────────────────────────

  String _buildPrompt(TradeLog log) {
    final sb = StringBuffer();
    sb.writeln('## Giao dịch cần review:');
    sb.writeln('- **Mã CK:** ${log.symbol}');
    sb.writeln('- **Ngày vào:** ${log.tradeDate.toLocal().toString().substring(0, 10)}');
    sb.writeln('- **Giá vào:** ${log.entryPrice}');
    sb.writeln('- **Khối lượng:** ${log.entryQuantity}');
    sb.writeln('- **Mẫu hình:** ${log.pattern.label}');
    sb.writeln('- **Lý do vào:** ${log.entryReason}');
    sb.writeln('- **SL -4%:** ${log.sl50Price.toStringAsFixed(2)} (cắt 1/2)');
    sb.writeln('- **SL -8%:** ${log.sl100Price.toStringAsFixed(2)} (cắt hết)');

    if (log.isClosed) {
      sb.writeln('');
      sb.writeln('### Kết quả:');
      sb.writeln('- **Giá ra:** ${log.exitPrice}');
      sb.writeln('- **PnL:** ${log.pnlPercent?.toStringAsFixed(2)}%  (${log.pnlVnd?.toStringAsFixed(0)} VNĐ)');
      sb.writeln('- **Loại thoát:** ${log.exitType?.label}');
      sb.writeln('- **Lý do bán:** ${log.exitReason}');
      sb.writeln('- **Cảm xúc khi bán:** ${log.exitEmotion?.label}');
    } else {
      sb.writeln('\n*(Lệnh đang mở — chưa có thông tin thoát)*');
    }

    sb.writeln('\nHãy review giao dịch này theo chiến lược của tôi.');
    return sb.toString();
  }

  // ── System Prompt ─────────────────────────────────────────────────────────

  static const _systemPrompt = '''
Bạn là AI Coach chứng khoán, chuyên gia về phương pháp Wyckoff/VSA và Ichimoku.
Dựa trên chiến lược giao dịch của user, hãy review giao dịch và trả lời bằng tiếng Việt theo format sau:

## ✅ Điểm tốt
(Liệt kê các điểm user làm đúng so với chiến lược)

## ❌ Điểm cần cải thiện
(Liệt kê các điểm sai hoặc chưa đúng chiến lược)

## 💡 Bài học rút ra
(1-2 bài học cụ thể cho giao dịch này)

## 📊 Đánh giá chung
(Điểm 1-10 + 1 câu tóm tắt)

---
CHIẾN LƯỢC CỦA USER:
- Phương pháp: Wyckoff/VSA kết hợp Ichimoku và mẫu hình nến
- Quy tắc vào lệnh: Chỉ mua ở Giai đoạn 2, mẫu hình rõ ràng (Test for Supply, No Supply, Spring, SOS), KL xác nhận
- Quy tắc cắt lỗ: -4% cắt 1/2, -8% cắt hết — NGAY LẬP TỨC, không chần chừ
- Quản lý vốn: Mỗi lệnh 10-20% vốn, không all-in, không trung bình giá xuống
- Mẫu hình: VCP 3-4 tuần trở lên, nền chặt, test đáy không thủng, Vol thấp dần
- Ichimoku: Giá trên Kijun-Sen, Tenkan ≥ Kijun, không kẹt trong Kumo
- Cảm xúc: KHÔNG mua vì FOMO, không giữ khi đã phải cắt lỗ
''';
}
