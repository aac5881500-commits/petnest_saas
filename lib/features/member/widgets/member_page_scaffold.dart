// lib/features/member/widgets/member_page_scaffold.dart
// 會員子頁共用 Scaffold：暖色背景、置中寬度、返回箭頭。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/shop_frontend_theme.dart';
import 'package:petnest_saas/features/member/widgets/member_ui_tokens.dart';

class MemberPageScaffold extends StatelessWidget {
  const MemberPageScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.bottom,
  });

  final String title;
  final Widget body;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;

  @override
  Widget build(BuildContext context) {
    final ShopFrontendTheme theme = MemberUi.of(context);
    return Scaffold(
      backgroundColor: theme.pageBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.pageBackgroundColor,
        foregroundColor: theme.titleColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          title,
          style: TextStyle(
            fontSize: MemberUi.titleSize,
            fontWeight: FontWeight.w700,
            color: theme.titleColor,
          ),
        ),
        actions: actions,
        bottom: bottom,
      ),
      body: body,
    );
  }
}
