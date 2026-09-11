// 檔案名稱：lib/features/admin/widgets/admin_order_source_note_fields.dart
// 功能說明：手動建單「下單方式＋訂單備註」，住宿／安親共用樣式。

import 'package:flutter/material.dart';

class AdminOrderSourceNoteFields extends StatelessWidget {
  const AdminOrderSourceNoteFields({
    super.key,
    required this.adminOrderSource,
    required this.noteController,
    required this.onOrderSourceChanged,
  });

  final String adminOrderSource;
  final TextEditingController noteController;
  final ValueChanged<String> onOrderSourceChanged;

  static const List<String> sources = <String>['電話預約', 'LINE 預約', '現場預約', '其他'];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        DropdownButtonFormField<String>(
          initialValue: sources.contains(adminOrderSource)
              ? adminOrderSource
              : sources.first,
          decoration: InputDecoration(
            labelText: '下單方式',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
          items: sources
              .map(
                (String value) =>
                    DropdownMenuItem<String>(value: value, child: Text(value)),
              )
              .toList(),
          onChanged: (String? value) {
            onOrderSourceChanged(value ?? sources.first);
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: noteController,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: '訂單備註',
            hintText: '例如：電話預約、LINE 預約、已口頭確認、特殊照顧事項',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ],
    );
  }
}
