import 'package:intl/intl.dart';

/// Model cho một mã chứng khoán (1 dòng trong bảng giá)
class StockQuote {
  final String symbol;       // Mã CK: VCB, HPG, ...
  final String exchange;     // HOSE / HNX / UPCOM
  final double reference;    // Giá tham chiếu
  final double ceiling;      // Giá trần
  final double floor;        // Giá sàn
  final double open;         // Giá mở cửa
  final double high;         // Giá cao nhất
  final double low;          // Giá thấp nhất
  final double price;        // Giá khớp gần nhất
  final double change;       // Thay đổi so với tham chiếu (VD: +1.5)
  final double changePercent;// % thay đổi (VD: +1.2%)
  final int volume;          // Khối lượng khớp
  final int totalValue;      // Giá trị khớp (nghìn đồng)
  final double buy1;         // Giá mua 1
  final int buyVol1;
  final double buy2;
  final int buyVol2;
  final double buy3;
  final int buyVol3;
  final double sell1;        // Giá bán 1
  final int sellVol1;
  final double sell2;
  final int sellVol2;
  final double sell3;
  final int sellVol3;
  final String? companyName;
  final DateTime updatedAt;

  const StockQuote({
    required this.symbol,
    required this.exchange,
    required this.reference,
    required this.ceiling,
    required this.floor,
    required this.open,
    required this.high,
    required this.low,
    required this.price,
    required this.change,
    required this.changePercent,
    required this.volume,
    required this.totalValue,
    this.buy1 = 0,
    this.buyVol1 = 0,
    this.buy2 = 0,
    this.buyVol2 = 0,
    this.buy3 = 0,
    this.buyVol3 = 0,
    this.sell1 = 0,
    this.sellVol1 = 0,
    this.sell2 = 0,
    this.sellVol2 = 0,
    this.sell3 = 0,
    this.sellVol3 = 0,
    this.companyName,
    required this.updatedAt,
  });

  bool get isUp => change > 0;
  bool get isDown => change < 0;
  bool get isCeiling => price == ceiling;
  bool get isFloor => price == floor;
  bool get isReference => change == 0;

  /// Format giá theo chuẩn Việt Nam (bỏ ,00 nếu là số chẵn)
  static final _priceFormat = NumberFormat('#,##0.####', 'vi_VN');
  static final _pctFormat = NumberFormat('+#,##0.##;-#,##0.##', 'en_US');
  static final _volFormat = NumberFormat('#,###', 'vi_VN');

  String get referenceStr => _priceFormat.format(reference);
  String get ceilingStr => _priceFormat.format(ceiling);
  String get floorStr => _priceFormat.format(floor);
  String get openStr => _priceFormat.format(open);
  String get highStr => _priceFormat.format(high);
  String get lowStr => _priceFormat.format(low);
  String get priceStr => _priceFormat.format(price);
  String get changeStr => _pctFormat.format(change);
  String get changePctStr => '${_pctFormat.format(changePercent)}%';
  String get volumeStr => _volFormat.format(volume);
  String get totalValueStr {
    if (totalValue >= 1000000) {
      return '${NumberFormat('#,##0.0').format(totalValue / 1000000)} tỷ';
    }
    return '${NumberFormat('#,###').format(totalValue / 1000)} tr';
  }

  StockQuote copyWith({
    double? price,
    double? change,
    double? changePercent,
    int? volume,
    int? totalValue,
    double? high,
    double? low,
    double? buy1,
    int? buyVol1,
    double? sell1,
    int? sellVol1,
    DateTime? updatedAt,
  }) {
    return StockQuote(
      symbol: symbol,
      exchange: exchange,
      reference: reference,
      ceiling: ceiling,
      floor: floor,
      open: open,
      high: high ?? this.high,
      low: low ?? this.low,
      price: price ?? this.price,
      change: change ?? this.change,
      changePercent: changePercent ?? this.changePercent,
      volume: volume ?? this.volume,
      totalValue: totalValue ?? this.totalValue,
      buy1: buy1 ?? this.buy1,
      buyVol1: buyVol1 ?? this.buyVol1,
      sell1: sell1 ?? this.sell1,
      sellVol1: sellVol1 ?? this.sellVol1,
      companyName: companyName,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Chỉ số thị trường (VN-Index, HNX-Index, UPCOM)
class MarketIndex {
  final String name;           // VN-Index / HNX-Index / UPCOM
  final double value;          // Giá trị điểm
  final double change;         // Thay đổi điểm
  final double changePercent;  // % thay đổi
  final int advances;          // Số mã tăng
  final int declines;          // Số mã giảm
  final int noChange;          // Số mã đứng
  final double totalVolume;    // Tổng KL giao dịch (triệu)
  final double totalValue;     // Tổng GT giao dịch (tỷ)
  final List<double> chartData;// Dữ liệu mini chart trong ngày

  const MarketIndex({
    required this.name,
    required this.value,
    required this.change,
    required this.changePercent,
    required this.advances,
    required this.declines,
    required this.noChange,
    required this.totalVolume,
    required this.totalValue,
    required this.chartData,
  });

  bool get isUp => change >= 0;

  static final _fmt = NumberFormat('#,##0.##', 'vi_VN');
  String get valueStr => _fmt.format(value);
  String get changeStr {
    final sign = change >= 0 ? '+' : '';
    return '$sign${_fmt.format(change)} ($sign${NumberFormat('+#,##0.##;-#,##0.##').format(changePercent)}%)';
  }
}
