// 檔案名稱：lib/core/services/booking_action_log_display.dart
// 功能說明：操作紀錄標題與前後值文字；相容舊欄位與 payload，不改歷史文件

import 'package:petnest_saas/core/services/booking_payment_labels.dart';
import 'package:petnest_saas/core/services/daycare_status_labels.dart';
import 'package:petnest_saas/core/services/settlement_adjust_display.dart';
import 'package:petnest_saas/core/services/shop_room_name_lookup.dart';

class BookingActionLogDisplay {
  BookingActionLogDisplay._();

  static Map<String, dynamic> flattened(Map<String, dynamic> log) {
    final Map<String, dynamic> out = Map<String, dynamic>.from(log);
    final dynamic payload = log['payload'];
    if (payload is Map) {
      payload.forEach((dynamic key, dynamic value) {
        final String name = key.toString();
        if (!out.containsKey(name) ||
            out[name] == null ||
            '${out[name]}'.isEmpty) {
          out[name] = value;
        }
      });
    }
    return out;
  }

  static String actionKey(Map<String, dynamic> log) {
    return (log['type'] ?? log['action'] ?? '').toString();
  }

  static Set<String> roomIdsNeedingLookup(Map<String, dynamic> log) {
    final Map<String, dynamic> f = flattened(log);
    final Set<String> ids = <String>{};
    void consider(dynamic name, dynamic id) {
      final String? lookup = ShopRoomNameLookup.idIfLookupNeeded(name, id);
      if (lookup != null) {
        ids.add(lookup);
      }
    }

    consider(f['fromRoomName'] ?? f['oldRoomName'], f['fromRoomId'] ?? f['oldRoomId']);
    consider(
      f['toRoomName'] ?? f['newRoomName'] ?? f['roomName'],
      f['toRoomId'] ?? f['newRoomId'] ?? f['roomId'],
    );
    return ids;
  }

  static String title(Map<String, dynamic> log) {
    final String type = actionKey(log);
    final Map<String, dynamic> fields = flattened(log);
    if (type == 'daycare_assign_room' && _isRoomChange(fields)) {
      return '更換房間';
    }
    if (type == 'settlement_applyAdjust' || type == 'daycare_adjustPrice') {
      return _adjustTitle(fields);
    }
    if (type == 'settlement_confirmCollect') {
      final String amount = _money(
        fields['amount'] ?? fields['paidAmount'] ?? fields['collectedAmount'],
      );
      return amount.isEmpty ? '確認現場補款' : '確認現場補款 $amount';
    }
    if (type == 'settlement_confirmRefund') {
      final String amount = _money(
        fields['refundDueAmount'] ?? fields['refundAmount'] ?? fields['amount'],
      );
      return amount.isEmpty ? '辦理退款' : '辦理退款 $amount';
    }
    if (type == 'settlement_checkOutStay') {
      return '確認住宿結算';
    }
    if (type == 'daycare_settle') {
      return '確認安親結算';
    }
    if (type == 'settlement_confirmStaffVerifiedTransfer') {
      return '店員現場已核對入帳';
    }
    if (type == 'settlement_confirmTransferTopUp') {
      return '核對轉帳補款';
    }
    if (type == 'settlement_confirmNoTopUpAndLock') {
      return '確認無需補款並鎖定訂單';
    }
    if (type == 'settlement_switchTopUpMethod' ||
        type == 'settlement_requestAppTopUp' ||
        type == 'payment_choice_changed') {
      return '變更付款方式';
    }
    final String daycare = DaycareStatusLabels.actionName(type);
    if (daycare.isNotEmpty &&
        type != 'daycare_settle' &&
        !type.startsWith('settlement_')) {
      return daycare;
    }
    switch (type) {
      case 'room_assigned':
      case 'stay_assign_room':
        return '分配房間';
      case 'room_changed':
      case 'stay_change_room':
      case 'daycare_change_room':
        return '更換房間';
      case 'booking_status_update':
        return '狀態變更';
      case 'deposit_confirmed':
        return '確認訂金';
      case 'booking_cancelled':
        return '取消訂單';
      case 'checkout_completed':
        return '退房完成';
      default:
        if (type.startsWith('settlement_')) {
          return _settlementFallbackTitle(type);
        }
        return type.isEmpty ? '操作紀錄' : type;
    }
  }

  static List<String> detailLines(
    Map<String, dynamic> log, {
    Map<String, String> roomNames = const <String, String>{},
    bool awaitingRoomNames = false,
  }) {
    final String type = actionKey(log);
    final Map<String, dynamic> f = flattened(log);
    final List<String> lines = <String>[];

    if (type == 'room_assigned' ||
        type == 'stay_assign_room' ||
        (type == 'daycare_assign_room' && !_isRoomChange(f))) {
      final String roomType = _first(f, <String>[
        'roomTypeName',
        'toRoomTypeName',
        'newRoomTypeName',
      ]);
      if (roomType.isNotEmpty) {
        lines.add('房型：$roomType');
      }
      lines.add(
        '實際房間：${_unassignedLabel(f['fromRoomName'] ?? f['fromRoomId'], roomNames, awaitingRoomNames)} → ${_roomLabel(f, to: true, roomNames: roomNames, awaiting: awaitingRoomNames)}',
      );
    } else if (type == 'room_changed' ||
        type == 'stay_change_room' ||
        type == 'daycare_change_room' ||
        (type == 'daycare_assign_room' && _isRoomChange(f))) {
      final String fromType = _first(f, <String>[
        'fromRoomTypeName',
        'oldRoomTypeName',
      ]);
      final String toType = _first(f, <String>[
        'toRoomTypeName',
        'newRoomTypeName',
        'roomTypeName',
      ]);
      if (fromType.isNotEmpty || toType.isNotEmpty) {
        if (fromType.isNotEmpty && toType.isNotEmpty && fromType != toType) {
          lines.add('房型：$fromType → $toType');
        } else {
          lines.add('房型：${toType.isNotEmpty ? toType : fromType}');
        }
      }
      lines.add(
        '實際房間：${_roomLabel(f, to: false, roomNames: roomNames, awaiting: awaitingRoomNames)} → ${_roomLabel(f, to: true, roomNames: roomNames, awaiting: awaitingRoomNames)}',
      );
    } else if (type == 'settlement_applyAdjust' ||
        type == 'daycare_adjustPrice') {
      lines.addAll(_adjustLines(f));
    } else if (type == 'settlement_checkOutStay' || type == 'daycare_settle') {
      lines.addAll(_settleLines(f, stay: type == 'settlement_checkOutStay'));
    } else if (type == 'booking_cancelled' || type == 'daycare_cancel') {
      final String reason = _first(f, <String>['cancelReason', 'reason']);
      if (reason.isNotEmpty) {
        lines.add('原因：$reason');
      }
    } else if (type == 'booking_status_update') {
      lines.add('${f['fromStatus'] ?? '-'} → ${f['toStatus'] ?? '-'}');
    } else if (type == 'checkout_completed') {
      lines.add('額外費用 NT\$ ${f['extraFee'] ?? 0}');
    } else if (type == 'payment_choice_changed' ||
        type == 'settlement_switchTopUpMethod' ||
        type == 'settlement_requestAppTopUp') {
      lines.addAll(_paymentChangeLines(f));
    } else if (type == 'deposit_confirmed') {
      final String amount = _money(f['depositAmount'] ?? f['paidAmount']);
      if (amount.isNotEmpty) {
        lines.add('訂金 $amount');
      }
    } else if (type == 'settlement_confirmRefund') {
      lines.addAll(_refundLines(f));
    } else if (type == 'settlement_confirmCollect' ||
        type == 'settlement_confirmStaffVerifiedTransfer' ||
        type == 'settlement_confirmTransferTopUp') {
      final String amount = _money(f['amount'] ?? f['paidAmount']);
      if (amount.isNotEmpty) {
        lines.add('金額 $amount');
      }
      final String method = _first(f, <String>['method', 'paymentMethod']);
      if (method.isNotEmpty) {
        lines.add('方式：${BookingPaymentLabels.method(method)}');
      }
    }

    final String reason = _first(f, <String>[
      'reason',
      'manualAdjustmentReason',
      'manualAdjustReason',
      'changeReason',
      'note',
      'remark',
    ]);
    if (reason.isNotEmpty &&
        !lines.any((String line) => line.contains('原因：$reason'))) {
      lines.add('原因：$reason');
    }
    return lines.where((String line) => !_containsDocumentId(line)).toList();
  }

  static List<String> _paymentChangeLines(Map<String, dynamic> f) {
    final String mode = (f['mode'] ?? '').toString();
    final String amountType = (f['payAmountType'] ?? f['amountType'] ?? '')
        .toString();
    final String methodLabel = mode == 'settlement_top_up'
        ? '結算尾款付款方式'
        : (mode == 'deposit' || amountType == 'deposit')
        ? '訂金付款方式'
        : '付款方式';
    final String fromMethod = _first(f, <String>[
      'previousPaymentMethod',
      'fromMethod',
      'oldPaymentMethod',
    ]);
    final String toMethod = _first(f, <String>[
      'paymentMethod',
      'toMethod',
      'newPaymentMethod',
      'settlementTopUpMethod',
    ]);
    final List<String> lines = <String>[];
    if (fromMethod.isNotEmpty || toMethod.isNotEmpty) {
      lines.add(
        '$methodLabel：${BookingPaymentLabels.method(fromMethod)} → ${BookingPaymentLabels.method(toMethod)}',
      );
    }
    final String fromStatus = _first(f, <String>[
      'previousPaymentStatus',
      'previousSettlementTopUpStatus',
      'fromPaymentStatus',
    ]);
    final String toStatus = _first(f, <String>[
      'paymentStatus',
      'settlementTopUpStatus',
      'toPaymentStatus',
    ]);
    if (fromStatus.isNotEmpty || toStatus.isNotEmpty) {
      lines.add(
        '付款狀態：${BookingPaymentLabels.status(fromStatus)} → ${BookingPaymentLabels.status(toStatus)}',
      );
    }
    return lines;
  }

  static bool _isRoomChange(Map<String, dynamic> f) {
    final String from = _first(f, <String>[
      'fromRoomId',
      'oldRoomId',
      'fromRoomName',
      'oldRoomName',
    ]);
    return from.isNotEmpty;
  }

  static String _unassignedLabel(
    dynamic raw,
    Map<String, String> roomNames,
    bool awaiting,
  ) {
    final String text = (raw ?? '').toString().trim();
    if (text.isEmpty) {
      return '未分房';
    }
    return _humanRoom(
      name: text,
      id: text,
      roomNames: roomNames,
      awaiting: awaiting,
      emptyFallback: '未分房',
    );
  }

  static String _roomLabel(
    Map<String, dynamic> f, {
    required bool to,
    required Map<String, String> roomNames,
    required bool awaiting,
  }) {
    if (to) {
      return _humanRoom(
        name: _first(f, <String>['newRoomName', 'toRoomName', 'roomName']),
        id: _first(f, <String>['newRoomId', 'toRoomId', 'roomId']),
        roomNames: roomNames,
        awaiting: awaiting,
        emptyFallback: '-',
      );
    }
    return _humanRoom(
      name: _first(f, <String>['oldRoomName', 'fromRoomName']),
      id: _first(f, <String>['oldRoomId', 'fromRoomId']),
      roomNames: roomNames,
      awaiting: awaiting,
      emptyFallback: '未分房',
    );
  }

  static String _humanRoom({
    required String name,
    required String id,
    required Map<String, String> roomNames,
    required bool awaiting,
    required String emptyFallback,
  }) {
    if (name.isNotEmpty && !ShopRoomNameLookup.looksLikeDocumentId(name)) {
      return name;
    }
    final String lookupId = ShopRoomNameLookup.looksLikeDocumentId(name)
        ? name
        : id;
    if (lookupId.isEmpty) {
      return emptyFallback;
    }
    if (roomNames.containsKey(lookupId)) {
      final String resolved = roomNames[lookupId]!.trim();
      return resolved.isEmpty ? ShopRoomNameLookup.missingLabel : resolved;
    }
    if (ShopRoomNameLookup.looksLikeDocumentId(lookupId) ||
        ShopRoomNameLookup.looksLikeDocumentId(name)) {
      return awaiting ? '讀取房號中' : ShopRoomNameLookup.missingLabel;
    }
    if (name.isNotEmpty) {
      return name;
    }
    return emptyFallback;
  }

  static String _adjustTitle(Map<String, dynamic> f) {
    final int delta = _int(
      f['delta'] ?? f['adjustAmount'] ?? f['manualAdjustmentAmount'] ?? f['manualAdjust'],
    );
    if (delta > 0) {
      return '手動加收 ${_nt(delta)}';
    }
    if (delta < 0) {
      return '手動減免 ${_nt(delta.abs())}';
    }
    return '重新調整結算';
  }

  static String _settlementFallbackTitle(String type) {
    const Map<String, String> known = <String, String>{
      'settlement_preview': '結算預覽',
    };
    return known[type] ?? '結算紀錄';
  }

  static List<String> _adjustLines(Map<String, dynamic> f) {
    final int before = _int(f['before'] ?? f['oldFinalReceivable']);
    final int after = _int(f['after'] ?? f['newFinalReceivable']);
    final int delta = _int(f['delta'] ?? f['adjustAmount'] ?? (after - before));
    return <String>[
      '舊最終應收 ${_nt(before)}',
      '調整金額 ${_signedNt(delta)}',
      '新最終應收 ${_nt(after)}',
    ];
  }

  static List<String> _settleLines(Map<String, dynamic> f, {required bool stay}) {
    final List<String> lines = <String>[];
    if (stay) {
      final String checkIn = _first(f, <String>[
        'actualCheckInAt',
        'checkInAtLabel',
      ]);
      final String checkOut = _first(f, <String>[
        'actualCheckOutAt',
        'checkOutAtLabel',
      ]);
      if (checkIn.isNotEmpty) {
        lines.add('實際入住：$checkIn');
      }
      if (checkOut.isNotEmpty) {
        lines.add('實際退房：$checkOut');
      }
    } else {
      final String start = _first(f, <String>[
        'actualStartAtLabel',
        'actualStartAt',
      ]);
      final String end = _first(f, <String>['actualEndAtLabel', 'actualEndAt']);
      if (start.isNotEmpty) {
        lines.add('實際送達：$start');
      }
      if (end.isNotEmpty) {
        lines.add('實際接回：$end');
      }
    }
    final int receivable = _int(
      f['finalSettlementAmount'] ??
          f['after'] ??
          f['newFinalReceivable'] ??
          f['finalTotal'],
    );
    final int paid = _int(f['finalPaidAmount'] ?? f['paidAmount']);
    final int remain = _int(
      f['finalRemainingAmount'] ?? f['remainingAmount'],
    );
    final int refund = _int(f['refundDueAmount'] ?? f['refundAmount']);
    if (receivable != 0 || paid != 0 || remain != 0 || refund != 0) {
      lines.add('最終應收 ${_nt(receivable)}');
      lines.add('已收 ${_nt(paid)}');
      if (remain > 0) {
        lines.add('待補 ${_nt(remain)}');
      } else if (refund > 0) {
        lines.add('待退 ${_nt(refund)}');
      }
    }
    lines.addAll(_adjustLinesIfPresent(f));
    lines.addAll(_refundLines(f));
    return lines;
  }

  static List<String> _adjustLinesIfPresent(Map<String, dynamic> f) {
    final int delta = _int(f['delta'] ?? f['manualAdjustmentAmount'] ?? f['manualAdjust']);
    if (delta == 0 &&
        _first(f, <String>['before', 'oldFinalReceivable']).isEmpty) {
      return const <String>[];
    }
    if (f['before'] == null && f['oldFinalReceivable'] == null && delta == 0) {
      return const <String>[];
    }
    if (f.containsKey('before') || f.containsKey('oldFinalReceivable')) {
      return _adjustLines(f);
    }
    if (delta != 0) {
      return <String>['調整金額 ${_signedNt(delta)}'];
    }
    return const <String>[];
  }

  static List<String> _refundLines(Map<String, dynamic> f) {
    final int refund = _int(
      f['refundDueAmount'] ?? f['refundAmount'] ?? f['amount'],
    );
    final String method = _first(f, <String>[
      'refundMethod',
      'settlementRefundMethod',
    ]);
    if (refund <= 0 && method.isEmpty) {
      return const <String>[];
    }
    final List<String> lines = <String>[];
    if (method.isNotEmpty) {
      lines.add(
        '退款方式：${SettlementAdjustDisplay.refundMethodLabel(method)}',
      );
    }
    if (refund > 0) {
      lines.add('退款金額 ${_nt(refund)}');
    }
    return lines;
  }

  static String _first(Map<String, dynamic> f, List<String> keys) {
    for (final String key in keys) {
      final String text = (f[key] ?? '').toString().trim();
      if (text.isNotEmpty && text != 'null') {
        return text;
      }
    }
    return '';
  }

  static bool _containsDocumentId(String line) {
    return RegExp(r'[A-Za-z0-9_-]{18,}').hasMatch(line) &&
        !RegExp(r'[\u4e00-\u9fff]').hasMatch(
          RegExp(r'[A-Za-z0-9_-]{18,}').firstMatch(line)?.group(0) ?? '',
        );
  }

  static int _int(dynamic raw) {
    if (raw is int) {
      return raw;
    }
    if (raw is num) {
      return raw.round();
    }
    return int.tryParse((raw ?? '').toString()) ?? 0;
  }

  static String _nt(int value) => 'NT\$ $value';

  static String _signedNt(int value) {
    if (value > 0) {
      return '+${_nt(value)}';
    }
    if (value < 0) {
      return '-${_nt(value.abs())}';
    }
    return _nt(0);
  }

  static String _money(dynamic raw) {
    if (raw == null || '$raw'.trim().isEmpty) {
      return '';
    }
    return _nt(_int(raw));
  }
}
