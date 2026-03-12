# Changelog

## [2026-03-07]
### Added
- **TradingView Chart Integration**: Chuyển từ library native sang nhúng **Official TradingView Lightweight Charts** qua `webview_flutter`.
- Hỗ trợ **Base64 Asset Injection**: Load `chart.html` và `tv.js` trực tiếp vào WebView để tránh lỗi CORS/Local Path.
- **Bảng giá Fireant-style**: Giao diện cuộn ngang (Horizontal Scroll) với Monospace font và Zebra patterning.
- Cột dữ liệu mở rộng: Cao, Thấp, Tham chiếu, Trần, Sàn.
- **FData Server Integration**: Kết nối thành công với Python Flask server để đọc data từ AmiBroker `.dat` files.

### Changed
- Refactor `chart_screen.dart`: Loại bỏ `candlesticks` và `k_chart_plus` để dùng WebView.
- Cập nhật `pubspec.yaml`: Thêm `webview_flutter`, khai báo assets mới.

### Fixed
- **RenderFlex Overflow**: Sửa lỗi tràn viền 1.6px ở màn hình Market Overview cho các ô MoverCard.
- **Compilation Error**: Sửa lỗi thiếu import `material.dart` sau khi gỡ bỏ widget cũ.
