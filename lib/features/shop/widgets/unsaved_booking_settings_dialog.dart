// 檔案名稱：lib/features/shop/widgets/unsaved_booking_settings_dialog.dart
// 功能說明：預約管理離開前提醒儲存

import 'package:flutter/material.dart';

enum UnsavedBookingSettingsAction { stay, discard, saveAndLeave }

Future<UnsavedBookingSettingsAction?> showUnsavedBookingSettingsDialog(
  BuildContext context,
) {
  return showDialog<UnsavedBookingSettingsAction>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('尚有未儲存的變更'),
        content: const Text('你修改的預約設定尚未儲存。'),
        actions: <Widget>[
          TextButton(
            onPressed: () =>
                Navigator.pop(context, UnsavedBookingSettingsAction.stay),
            child: const Text('繼續編輯'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(context, UnsavedBookingSettingsAction.discard),
            child: const Text('放棄變更'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              UnsavedBookingSettingsAction.saveAndLeave,
            ),
            child: const Text('儲存並離開'),
          ),
        ],
      );
    },
  );
}
