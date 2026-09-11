// 檔案名稱：lib/features/admin/widgets/admin_create_flow_scaffold.dart
// 功能說明：手動新增住宿／安親訂單共用階段版型：步驟列、主題卡片、底部操作與費用摘要

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_step_widgets.dart';

class AdminCreateFlowScaffold extends StatelessWidget {
  const AdminCreateFlowScaffold({
    super.key,
    required this.title,
    required this.stepIndex,
    required this.stepTitles,
    required this.body,
    required this.primaryLabel,
    required this.onPrimary,
    required this.theme,
    this.summary,
    this.hint = '',
    this.actionHint = '',
    this.actionHintLabel = '前往填寫',
    this.onActionHint,
    this.primaryEnabled = true,
    this.busy = false,
    this.onBackStep,
  });

  final String title;
  final int stepIndex;
  final List<String> stepTitles;
  final Widget body;
  final Widget? summary;
  final String hint;
  final String actionHint;
  final String actionHintLabel;
  final VoidCallback? onActionHint;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final bool primaryEnabled;
  final bool busy;
  final VoidCallback? onBackStep;
  final HomeThemeModel theme;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        title: Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: theme.textColor,
          ),
        ),
        backgroundColor: theme.backgroundColor,
        foregroundColor: theme.textColor,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool wide = constraints.maxWidth >= 980;
          final Widget flow = Column(
            children: <Widget>[
              _AdminCreateStepBar(
                theme: theme,
                stepIndex: stepIndex,
                titles: stepTitles,
              ),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: body,
                  ),
                ),
              ),
            ],
          );
          final Widget actions = SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (!wide && summary != null) ...<Widget>[
                    summary!,
                    const SizedBox(height: 10),
                  ],
                  if (actionHint.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              actionHint,
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: onActionHint,
                            child: Text(actionHintLabel),
                          ),
                        ],
                      ),
                    ),
                  if (hint.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          hint,
                          style: TextStyle(
                            color: theme.primaryColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  Row(
                    children: <Widget>[
                      if (onBackStep != null) ...<Widget>[
                        Expanded(
                          child: BookingStepBackButton(
                            theme: theme,
                            onPressed: () {
                              if (!busy) {
                                onBackStep!();
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: BookingPrimaryButton(
                          theme: theme,
                          label: busy ? '處理中...' : primaryLabel,
                          onPressed: primaryEnabled && !busy ? onPrimary : null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
          if (!wide) {
            return Column(
              children: <Widget>[
                Expanded(child: flow),
                actions,
              ],
            );
          }
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(
                    flex: 3,
                    child: Column(
                      children: <Widget>[
                        Expanded(child: flow),
                        actions,
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 320,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 16, 16, 16),
                      child:
                          summary ??
                          BookingThemedCard(
                            theme: theme,
                            child: Text(
                              '選擇內容後，費用摘要會顯示在這裡',
                              style: TextStyle(
                                color: theme.textColor.withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class AdminCreateFeeSummaryCard extends StatelessWidget {
  const AdminCreateFeeSummaryCard({
    super.key,
    required this.theme,
    required this.lines,
    required this.totalLabel,
    required this.totalAmount,
  });

  final HomeThemeModel theme;
  final List<String> lines;
  final String totalLabel;
  final String totalAmount;

  @override
  Widget build(BuildContext context) {
    return BookingThemedCard(
      theme: theme,
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '費用摘要',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: theme.textColor,
            ),
          ),
          const SizedBox(height: 8),
          if (lines.isEmpty)
            Text(
              '完成選擇後即可預估費用',
              style: TextStyle(
                fontSize: 13,
                color: theme.textColor.withValues(alpha: 0.65),
              ),
            )
          else
            ...lines.map(
              (String line) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  line,
                  style: TextStyle(fontSize: 13, color: theme.textColor),
                ),
              ),
            ),
          if (totalAmount.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '$totalLabel $totalAmount',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: theme.primaryColor,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AdminCreateStepBar extends StatelessWidget {
  const _AdminCreateStepBar({
    required this.theme,
    required this.stepIndex,
    required this.titles,
  });

  final HomeThemeModel theme;
  final int stepIndex;
  final List<String> titles;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: List<Widget>.generate(titles.length, (int index) {
          final bool completed = index < stepIndex;
          final bool active = index == stepIndex;
          final Color circleColor = completed || active
              ? theme.primaryColor
              : theme.cardBorderColor;
          return Expanded(
            child: Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    if (index > 0)
                      Expanded(
                        child: Container(
                          height: 1,
                          color: index <= stepIndex
                              ? theme.primaryColor.withValues(alpha: 0.45)
                              : theme.cardBorderColor,
                        ),
                      )
                    else
                      const Expanded(child: SizedBox()),
                    Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: completed || active
                            ? circleColor
                            : theme.cardColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: circleColor),
                      ),
                      child: completed
                          ? const Icon(
                              Icons.check,
                              size: 12,
                              color: Colors.white,
                            )
                          : Text(
                              '${index + 1}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: active ? Colors.white : theme.textColor,
                              ),
                            ),
                    ),
                    if (index < titles.length - 1)
                      Expanded(
                        child: Container(
                          height: 1,
                          color: index < stepIndex
                              ? theme.primaryColor.withValues(alpha: 0.45)
                              : theme.cardBorderColor,
                        ),
                      )
                    else
                      const Expanded(child: SizedBox()),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  titles[index],
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: completed || active
                        ? theme.textColor
                        : theme.textColor.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
