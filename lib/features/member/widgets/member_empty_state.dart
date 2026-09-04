// lib/features/member/widgets/member_empty_state.dart
// 會員頁共用空狀態：柔和 icon、標題、說明、選擇性按鈕。

import 'package:flutter/material.dart';
import 'package:petnest_saas/features/member/widgets/member_ui_tokens.dart';

class MemberEmptyState extends StatelessWidget {
  const MemberEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = MemberUi.of(context);
    return Align(
      alignment: const Alignment(0, -0.28),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: theme.primarySoft,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, color: theme.primaryColor, size: 30),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: MemberUi.sectionSize,
                fontWeight: FontWeight.w700,
                color: theme.titleColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: MemberUi.bodySize,
                color: theme.subtitleColor,
                height: 1.45,
              ),
            ),
            if (actionLabel != null && onAction != null) ...<Widget>[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.buttonColor,
                  foregroundColor: theme.onPrimaryColor,
                ),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class MemberErrorState extends StatelessWidget {
  const MemberErrorState({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return MemberEmptyState(
      icon: Icons.wifi_off_outlined,
      title: '無法載入',
      message: message,
      actionLabel: onRetry == null ? null : '重新載入',
      onAction: onRetry,
    );
  }
}
