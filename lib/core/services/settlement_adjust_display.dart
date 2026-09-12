// 檔案名稱：lib/core/services/settlement_adjust_display.dart
// 功能說明：安親結算手動加收／減免的顯示與正負轉換（不改計價公式）。

class SettlementAdjustDisplay {
  SettlementAdjustDisplay._();

  static const String inStoreRefundMethod = 'cash';

  static int signedAmount({required bool surcharge, required int unsigned}) {
    final int value = unsigned < 0 ? 0 : unsigned;
    if (value == 0) {
      return 0;
    }
    return surcharge ? value : -value;
  }

  static String signedLabel(int amount) {
    if (amount > 0) {
      return '＋NT\$$amount';
    }
    if (amount < 0) {
      return '－NT\$${amount.abs()}';
    }
    return 'NT\$0';
  }

  static String reasonOf(Map<String, dynamic> data) {
    final String top = _reasonFrom(data);
    if (top.isNotEmpty) {
      return top;
    }
    for (final String key in <String>['settlement', 'daycareSettlement']) {
      final Object? nested = data[key];
      if (nested is Map) {
        final String value = _reasonFrom(Map<String, dynamic>.from(nested));
        if (value.isNotEmpty) {
          return value;
        }
      }
    }
    return '';
  }

  static String _reasonFrom(Map<String, dynamic> data) {
    return (data['manualAdjustmentReason'] ??
            data['lastManualAdjustReason'] ??
            data['manualAdjustReason'] ??
            '')
        .toString()
        .trim();
  }

  static bool requiresReason(int amount) => amount != 0;

  static bool isReasonMissing({required int amount, required String reason}) {
    return requiresReason(amount) && reason.trim().isEmpty;
  }

  static String shopAmountLine(int amount) {
    if (amount > 0) {
      return '手動加收：${signedLabel(amount)}';
    }
    if (amount < 0) {
      return '手動減免：${signedLabel(amount)}';
    }
    return '';
  }

  static String customerNoteOf(Map<String, dynamic> data) {
    if (!shouldShow(data)) {
      return '';
    }
    return '店家調整說明：${reasonOf(data)}';
  }

  static int amountOf(Map<String, dynamic> data) {
    final dynamic raw =
        data['manualAdjust'] ?? data['manualAdjustmentAmount'] ?? 0;
    if (raw is int) {
      return raw;
    }
    return int.tryParse(raw.toString()) ?? 0;
  }

  static bool shouldShow(Map<String, dynamic> data) {
    return amountOf(data) != 0 && reasonOf(data).isNotEmpty;
  }
}

enum DaycareManualAdjustKind { none, surcharge, discount }

class DaycareManualAdjustInput {
  const DaycareManualAdjustInput({
    required this.kind,
    required this.unsignedAmount,
  });

  final DaycareManualAdjustKind kind;
  final int unsignedAmount;

  int get signed {
    if (kind == DaycareManualAdjustKind.none || unsignedAmount <= 0) {
      return 0;
    }
    return SettlementAdjustDisplay.signedAmount(
      surcharge: kind == DaycareManualAdjustKind.surcharge,
      unsigned: unsignedAmount,
    );
  }

  static DaycareManualAdjustInput fromSigned(int signed) {
    if (signed > 0) {
      return DaycareManualAdjustInput(
        kind: DaycareManualAdjustKind.surcharge,
        unsignedAmount: signed,
      );
    }
    if (signed < 0) {
      return DaycareManualAdjustInput(
        kind: DaycareManualAdjustKind.discount,
        unsignedAmount: signed.abs(),
      );
    }
    return const DaycareManualAdjustInput(
      kind: DaycareManualAdjustKind.none,
      unsignedAmount: 0,
    );
  }
}
