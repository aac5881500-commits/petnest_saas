// 檔案名稱：lib/features/shop/widgets/inventory/inventory_ui_format.dart
// 功能說明：詳情頁各分頁共用日期時間顯示，不影響庫存計算。
// 📦 庫存畫面日期格式

class InventoryUiFormat {
  InventoryUiFormat._();

  static String date(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }

  static String dateTime(DateTime value) {
    return '${date(value)} '
        '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
  }
}
