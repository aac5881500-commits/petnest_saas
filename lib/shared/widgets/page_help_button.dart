// lib/shared/widgets/page_help_button.dart
// 💡 共用頁面使用說明按鈕
// 功能：在頁面顯示小型問號按鈕，點擊後開啟底部說明視窗，
// 顯示頁面用途、使用方式、模擬案例與注意事項。

import 'package:flutter/material.dart';

class PageHelpButton extends StatelessWidget {
  const PageHelpButton({
    super.key,
    required this.title,
    required this.purpose,
    this.steps = const <String>[],
    this.examples = const <PageHelpExample>[],
    this.notes = const <String>[],
    this.tooltip = '查看使用說明',
  });

  /// 說明視窗標題，例如「優惠活動使用說明」
  final String title;

  /// 這個頁面的主要用途
  final String purpose;

  /// 使用步驟
  final List<String> steps;

  /// 模擬案例
  final List<PageHelpExample> examples;

  /// 注意事項
  final List<String> notes;

  /// 長按問號按鈕時顯示的文字
  final String tooltip;

  Future<void> _showHelpSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return _PageHelpSheet(
          title: title,
          purpose: purpose,
          steps: steps,
          examples: examples,
          notes: notes,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: () => _showHelpSheet(context),
        icon: const Icon(Icons.help_outline_rounded),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class PageHelpExample {
  const PageHelpExample({
    required this.title,
    required this.description,
    this.lines = const <String>[],
  });

  /// 案例名稱，例如「新會員優惠」
  final String title;

  /// 案例簡短說明
  final String description;

  /// 案例計算內容或操作流程
  final List<String> lines;
}

class _PageHelpSheet extends StatelessWidget {
  const _PageHelpSheet({
    required this.title,
    required this.purpose,
    required this.steps,
    required this.examples,
    required this.notes,
  });

  final String title;
  final String purpose;
  final List<String> steps;
  final List<PageHelpExample> examples;
  final List<String> notes;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double screenHeight = MediaQuery.sizeOf(context).height;

    return Container(
      constraints: BoxConstraints(maxHeight: screenHeight * 0.88),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox(height: 10),
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 8, 10),
            child: Row(
              children: <Widget>[
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.lightbulb_outline_rounded,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '關閉',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _HelpSection(
                    icon: Icons.menu_book_outlined,
                    title: '這頁用途',
                    child: Text(
                      purpose,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.55),
                    ),
                  ),
                  if (steps.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 14),
                    _HelpSection(
                      icon: Icons.check_circle_outline_rounded,
                      title: '怎麼使用',
                      child: Column(
                        children: List<Widget>.generate(steps.length, (
                          int index,
                        ) {
                          return _NumberedHelpRow(
                            number: index + 1,
                            text: steps[index],
                          );
                        }),
                      ),
                    ),
                  ],
                  if (examples.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 14),
                    _HelpSection(
                      icon: Icons.science_outlined,
                      title: '模擬案例',
                      child: Column(
                        children: List<Widget>.generate(examples.length, (
                          int index,
                        ) {
                          return Padding(
                            padding: EdgeInsets.only(
                              bottom: index == examples.length - 1 ? 0 : 12,
                            ),
                            child: _ExampleCard(example: examples[index]),
                          );
                        }),
                      ),
                    ),
                  ],
                  if (notes.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 14),
                    _HelpSection(
                      icon: Icons.warning_amber_rounded,
                      title: '注意事項',
                      child: Column(
                        children: notes.map((String note) {
                          return _BulletHelpRow(text: note);
                        }).toList(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpSection extends StatelessWidget {
  const _HelpSection({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 21, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _NumberedHelpRow extends StatelessWidget {
  const _NumberedHelpRow({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 25,
            height: 25,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                text,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BulletHelpRow extends StatelessWidget {
  const _BulletHelpRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExampleCard extends StatelessWidget {
  const _ExampleCard({required this.example});

  final PageHelpExample example;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            example.title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            example.description,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
          ),
          if (example.lines.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            ...example.lines.map((String line) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(
                      Icons.arrow_right_rounded,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        line,
                        style: theme.textTheme.bodySmall?.copyWith(
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
