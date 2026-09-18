// 檔案名稱：lib/features/shop/pages/daily_care_journal_editor_page.dart
// 功能說明：未掛路由的舊外觀編輯頁。保留檔案與建構參數相容，已停用全部店家背景上傳 UI。

import 'package:flutter/material.dart';

import '../../../core/models/daily_care_setting_model.dart';

class DailyCareJournalEditorPage extends StatelessWidget {
  const DailyCareJournalEditorPage({
    super.key,
    required this.shopId,
    required this.initial,
  });

  final String shopId;
  final DailyCareSettingModel initial;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: ValueKey<String>(
        'daily-care-editor-retired-$shopId-${initial.revision}',
      ),
      appBar: AppBar(title: const Text('日誌外觀')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Text(
                  '此舊外觀編輯頁已停用。請回到每日照護設定，從平台圖庫選擇背景。',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, height: 1.45),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => Navigator.maybePop(context),
                  child: const Text('返回'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
