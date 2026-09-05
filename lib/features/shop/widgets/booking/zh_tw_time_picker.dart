// 檔案名稱：lib/features/shop/widgets/booking/zh_tw_time_picker.dart
// 功能說明：24 小時制、繁體中文時間選擇器

import 'package:flutter/material.dart';

Future<TimeOfDay?> showZhTw24HourTimePicker({
  required BuildContext context,
  required TimeOfDay initialTime,
}) {
  return showTimePicker(
    context: context,
    initialTime: initialTime,
    initialEntryMode: TimePickerEntryMode.dial,
    helpText: '選擇時間',
    cancelText: '取消',
    confirmText: '確定',
    hourLabelText: '時',
    minuteLabelText: '分',
    builder: (BuildContext context, Widget? child) {
      return MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: Localizations.override(
          context: context,
          locale: const Locale('zh', 'TW'),
          child: child ?? const SizedBox.shrink(),
        ),
      );
    },
  );
}
