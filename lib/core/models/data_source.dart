/// Nguồn dữ liệu cho app
enum DataSourceMode {
  fdata,    // Đọc file .dat từ FData/AmiBroker qua Python API
  realtime, // MQTT realtime (Phase 2) hoặc mock (Phase 1)
}

extension DataSourceModeExt on DataSourceMode {
  String get label {
    switch (this) {
      case DataSourceMode.fdata:    return 'FData (File .dat)';
      case DataSourceMode.realtime: return 'Realtime';
    }
  }

  String get description {
    switch (this) {
      case DataSourceMode.fdata:
        return 'Đọc từ D:\\Ami\\AmiBroker qua Python server';
      case DataSourceMode.realtime:
        return 'Dữ liệu thời gian thực (Mock / MQTT)';
    }
  }
}
