# DNSE Stock App - Phase 1

Ứng dụng theo dõi chứng khoán chuyên nghiệp chuẩn DNSE, hỗ trợ dữ liệu real-time và biểu đồ TradingView chính quy.

## Các tính năng chính (Phase 1)
- **Bảng giá Professional**: Giao diện cuộn ngang giống Fireant, hỗ trợ đầy đủ các cột (TC, Trần, Sàn, Cao, Thấp...).
- **Biểu đồ TradingView**: Nhúng bộ lõi **Official TradingView Lightweight Charts** qua WebView, hỗ trợ Drawing Tools và indicators mượt mà.
- **Dual Data Source**: 
  - **Real-time**: Mock data (sẽ nâng cấp lên MQTT ở Phase 2).
  - **FData**: Đọc dữ liệu lịch sử từ files `.dat` (AmiBroker) qua server Python local.
- **Watchlist**: Theo dõi mã chứng khoán yêu thích.
- **Market Overview**: Tổng quan chỉ số VN-Index, HNX-Index và top biến động.

## Setup & Chạy App
1. Đảm bảo đã cài đặt Flutter 3.x.
2. Chạy server Python (nếu dùng FData): `python fdata_server.py`.
3. Chạy app: `flutter run`.

---
*Ghi chú: Project đang sử dụng kỹ thuật Base64 Injection để tối ưu việc load chart TradingView trên Mobile.*

