// 檔案名稱：lib/features/custom_form/widgets/custom_form_answer_view.dart
// 功能說明：唯讀顯示已保存的自訂表單答案快照，依分類呈現；空答案不顯示，舊格式解析失敗不造成白畫面。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/custom_form_answer_model.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';

class CustomFormAnswerView extends StatelessWidget {
  const CustomFormAnswerView({
    super.key,
    required this.raw,
    required this.title,
    required this.theme,
    this.collapsible = false,
    this.initiallyExpanded = false,
  });

  final dynamic raw;
  final String title;
  final HomeThemeModel theme;
  final bool collapsible;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    try {
      final CustomFormAnswerSnapshot? snapshot =
          CustomFormAnswerSnapshot.tryParse(raw);
      if (snapshot == null || snapshot.isEmpty) {
        return const SizedBox.shrink();
      }
      final List<CustomFormAnswerItem> visible = snapshot.answers
          .where(
            (CustomFormAnswerItem item) => item.displayValue.trim().isNotEmpty,
          )
          .toList();
      if (visible.isEmpty) {
        return const SizedBox.shrink();
      }
      final int filled = visible.length;
      final String heading = title.contains('已填')
          ? title
          : '$title・已填 $filled 題';
      final Map<String, List<CustomFormAnswerItem>> grouped =
          <String, List<CustomFormAnswerItem>>{};
      for (final CustomFormAnswerItem item in visible) {
        final String key = item.sectionTitle.trim().isEmpty
            ? '其他'
            : item.sectionTitle;
        grouped.putIfAbsent(key, () => <CustomFormAnswerItem>[]).add(item);
      }
      final Widget body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (!collapsible)
            Text(
              heading,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: theme.textColor,
              ),
            ),
          if (snapshot.formTitle.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 8),
              child: Text(
                snapshot.formTitle,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.textColor.withValues(alpha: 0.55),
                ),
              ),
            )
          else
            const SizedBox(height: 8),
          for (final MapEntry<String, List<CustomFormAnswerItem>> entry
              in grouped.entries) ...<Widget>[
            Text(
              entry.key,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: theme.textColor.withValues(alpha: 0.78),
              ),
            ),
            const SizedBox(height: 6),
            for (final CustomFormAnswerItem item in entry.value)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      item.questionLabel,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.textColor.withValues(alpha: 0.55),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.displayValue,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.35,
                        color: theme.textColor,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      );
      if (collapsible) {
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            initiallyExpanded: initiallyExpanded,
            title: Text(heading),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            children: <Widget>[body],
          ),
        );
      }
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.cardBorderColor),
        ),
        child: body,
      );
    } catch (_) {
      return const SizedBox.shrink();
    }
  }
}
