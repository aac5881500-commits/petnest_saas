// 功能：首頁展示設定的分組卡；進階外觀有獨立儲存識別。
import 'package:flutter/material.dart';

class HomeSectionSettingsGroup extends StatelessWidget {
  const HomeSectionSettingsGroup({
    super.key,
    required this.title,
    required this.children,
    this.storageId,
  });
  final String title;
  final List<Widget> children;
  final String? storageId;
  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: Theme.of(context).dividerColor.withValues(alpha: .25),
        ),
      ),
      child: storageId != null
          ? ExpansionTile(
              key: PageStorageKey<String>(storageId!),
              title: Text(title),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [content],
            )
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  content,
                ],
              ),
            ),
    );
  }
}
