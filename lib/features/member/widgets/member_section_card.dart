// lib/features/member/widgets/member_section_card.dart
// 會員頁白底卡片。

import 'package:flutter/material.dart';
import 'package:petnest_saas/features/member/widgets/member_ui_tokens.dart';

class MemberSectionCard extends StatelessWidget {
  const MemberSectionCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.margin,
    this.muted = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final theme = MemberUi.of(context);
    final Color mutedCard =
        Color.lerp(theme.cardColor, theme.subtitleColor, 0.08) ??
        theme.cardColor;
    final Widget content = Container(
      width: double.infinity,
      margin: margin ?? const EdgeInsets.only(bottom: MemberUi.cardGap),
      padding: padding ?? const EdgeInsets.all(MemberUi.cardPadding),
      decoration: MemberUi.cardDecoration(
        context,
        color: muted ? mutedCard : theme.cardColor,
      ),
      child: child,
    );
    if (onTap == null) {
      return content;
    }
    return Padding(
      padding: margin ?? const EdgeInsets.only(bottom: MemberUi.cardGap),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(MemberUi.radius),
          child: Ink(
            padding: padding ?? const EdgeInsets.all(MemberUi.cardPadding),
            decoration: MemberUi.cardDecoration(
              context,
              color: muted ? mutedCard : theme.cardColor,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
