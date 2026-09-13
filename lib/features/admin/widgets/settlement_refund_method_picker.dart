// 檔案名稱：lib/features/admin/widgets/settlement_refund_method_picker.dart
// 功能說明：結算待退款時選擇現場／銀行／其他退款，不寫入補款欄位。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/settlement_adjust_display.dart';

class SettlementRefundMethodPicker extends StatelessWidget {
  const SettlementRefundMethodPicker({
    super.key,
    required this.value,
    required this.onChanged,
    required this.noteController,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final TextEditingController noteController;

  @override
  Widget build(BuildContext context) {
    final String group = value.isEmpty
        ? SettlementAdjustDisplay.inStoreRefundMethod
        : value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ...SettlementAdjustDisplay.refundMethodOptions.map((
          Map<String, String> item,
        ) {
          return RadioListTile<String>(
            value: item['id'] ?? '',
            groupValue: group,
            title: Text(item['title'] ?? ''),
            subtitle: Text(item['subtitle'] ?? ''),
            onChanged: (String? next) {
              onChanged(next ?? SettlementAdjustDisplay.inStoreRefundMethod);
            },
          );
        }),
        if (group == SettlementAdjustDisplay.otherRefundMethod)
          TextField(
            controller: noteController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: '其他退款註記（必填）',
              border: OutlineInputBorder(),
            ),
          ),
      ],
    );
  }
}
