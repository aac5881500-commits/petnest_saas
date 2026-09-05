// 檔案名稱：lib/core/models/booking_fee_line_item.dart
// 功能說明：填寫資料頁費用明細列

enum BookingFeeLineKind { normal, discount, total, payable }

class BookingFeeLineItem {
  const BookingFeeLineItem({
    required this.label,
    required this.amount,
    this.kind = BookingFeeLineKind.normal,
  });

  final String label;
  final int amount;
  final BookingFeeLineKind kind;
}
