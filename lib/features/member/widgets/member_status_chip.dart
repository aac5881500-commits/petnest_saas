// 檔案名稱：lib/features/member/widgets/member_status_chip.dart
// 功能說明：會員頁狀態膠囊。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/shop_frontend_theme.dart';
import 'package:petnest_saas/features/member/widgets/member_ui_tokens.dart';

class MemberStatusChip extends StatelessWidget {
  const MemberStatusChip({
    super.key,
    required this.label,
    this.tone = MemberChipTone.neutral,
  });

  final String label;
  final MemberChipTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = MemberUi.of(context);
    final Color bg;
    final Color fg;
    switch (tone) {
      case MemberChipTone.success:
        bg = ShopFrontendTheme.successSoft;
        fg = theme.success;
      case MemberChipTone.warning:
        bg = ShopFrontendTheme.warningSoft;
        fg = theme.warning;
      case MemberChipTone.danger:
        bg = ShopFrontendTheme.errorSoft;
        fg = theme.danger;
      case MemberChipTone.primary:
        bg = theme.primarySoft;
        fg = theme.primaryColor;
      case MemberChipTone.neutral:
        bg =
            Color.lerp(theme.cardColor, theme.subtitleColor, 0.12) ??
            theme.cardColor;
        fg = theme.subtitleColor;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}

enum MemberChipTone { neutral, primary, success, warning, danger }
