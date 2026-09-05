// 檔案名稱：lib/core/services/shop_report_format.dart
// 功能說明：報表數字格式：金額 NT$ + 千分位、百分比。

import 'package:intl/intl.dart';

class ShopReportFormat {
  ShopReportFormat._();

  static final NumberFormat _money = NumberFormat('#,###', 'en_US');
  static final NumberFormat _percent = NumberFormat('0.0%', 'en_US');
  static final DateFormat date = DateFormat('yyyy/MM/dd');
  static final DateFormat dateTime = DateFormat('yyyy/MM/dd HH:mm');

  static String money(int amount) => 'NT\$ ${_money.format(amount)}';

  static String number(int value) => _money.format(value);

  static String percent(double value) => _percent.format(value);

  static int compare(dynamic a, dynamic b) {
    return (a as Comparable).compareTo(b);
  }
}
