// 檔案名稱：lib/core/services/special_date_surcharge_calculator.dart
// 功能說明：依實際住宿夜逐晚計算特殊日期固定加價
// 📅 特殊日期加價計算器
// 並提供每晚加價明細與整筆訂單的特殊日期加價總額。

import '../models/special_date_surcharge_model.dart';

/// 單一住宿夜的特殊日期加價明細
class SpecialDateSurchargeNightDetail {
  const SpecialDateSurchargeNightDetail({
    required this.stayDate,
    required this.surcharges,
    required this.amount,
  });

  /// 實際住宿夜日期
  ///
  /// 例如入住 2/5、退房 2/7，
  /// 住宿夜會有 2/5、2/6。
  final DateTime stayDate;

  /// 此住宿夜實際套用到的特殊日期加價設定
  final List<SpecialDateSurchargeModel> surcharges;

  /// 此住宿夜的加價總額
  final int amount;

  bool get hasSurcharge => amount > 0 && surcharges.isNotEmpty;
}

/// 整筆住宿的特殊日期加價計算結果
class SpecialDateSurchargeCalculationResult {
  const SpecialDateSurchargeCalculationResult({
    required this.nightDetails,
    required this.totalAmount,
    required this.totalStayNights,
  });

  /// 每一個實際住宿夜的加價明細
  final List<SpecialDateSurchargeNightDetail> nightDetails;

  /// 整筆住宿的特殊日期加價總額
  final int totalAmount;

  /// 實際住宿總晚數
  final int totalStayNights;

  /// 有套用特殊日期加價的住宿晚數
  int get surchargedNightCount {
    return nightDetails
        .where((SpecialDateSurchargeNightDetail detail) => detail.hasSurcharge)
        .length;
  }

  bool get hasSurcharge => totalAmount > 0;
}

/// 特殊日期加價共用計算器
class SpecialDateSurchargeCalculator {
  const SpecialDateSurchargeCalculator._();

  /// 計算指定住宿期間的特殊日期加價
  ///
  /// 規則：
  /// - checkInDate 當天算第一個住宿夜
  /// - checkOutDate 當天不算住宿夜
  /// - 只套用 enabled == true 的設定
  /// - 每個住宿夜獨立判斷
  static SpecialDateSurchargeCalculationResult calculate({
    required DateTime checkInDate,
    required DateTime checkOutDate,
    required String roomTypeId,
    required List<SpecialDateSurchargeModel> surcharges,
  }) {
    final DateTime normalizedCheckIn = _dateOnly(checkInDate);
    final DateTime normalizedCheckOut = _dateOnly(checkOutDate);

    if (!normalizedCheckOut.isAfter(normalizedCheckIn)) {
      return const SpecialDateSurchargeCalculationResult(
        nightDetails: <SpecialDateSurchargeNightDetail>[],
        totalAmount: 0,
        totalStayNights: 0,
      );
    }

    final List<SpecialDateSurchargeNightDetail> nightDetails =
        <SpecialDateSurchargeNightDetail>[];

    int totalAmount = 0;

    DateTime stayDate = normalizedCheckIn;

    while (stayDate.isBefore(normalizedCheckOut)) {
      final List<SpecialDateSurchargeModel> matchedSurcharges = surcharges
          .where((SpecialDateSurchargeModel surcharge) {
            final bool roomTypeMatched =
                surcharge.roomTypeIds.isEmpty ||
                surcharge.roomTypeIds.contains(roomTypeId);

            return surcharge.enabled &&
                surcharge.appliesToDate(stayDate) &&
                roomTypeMatched;
          })
          .toList();

      final int nightAmount = matchedSurcharges.fold<int>(0, (
        int total,
        SpecialDateSurchargeModel surcharge,
      ) {
        return total + surcharge.amountPerNight;
      });

      nightDetails.add(
        SpecialDateSurchargeNightDetail(
          stayDate: stayDate,
          surcharges: List<SpecialDateSurchargeModel>.unmodifiable(
            matchedSurcharges,
          ),
          amount: nightAmount,
        ),
      );

      totalAmount += nightAmount;
      stayDate = stayDate.add(const Duration(days: 1));
    }

    return SpecialDateSurchargeCalculationResult(
      nightDetails: List<SpecialDateSurchargeNightDetail>.unmodifiable(
        nightDetails,
      ),
      totalAmount: totalAmount,
      totalStayNights: nightDetails.length,
    );
  }

  static DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }
}
