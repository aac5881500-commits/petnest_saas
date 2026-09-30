// 檔案路徑：lib/core/widgets/app_state_panel.dart
// 功能說明：共用空資料與讀取失敗提示，提供清楚的說明與重試入口。
import 'package:flutter/material.dart';

class AppStatePanel extends StatelessWidget {
  const AppStatePanel({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.cloud_off_outlined,
    this.onRetry,
  });

  final String title;
  final String message;
  final IconData icon;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: Icon(icon, size: 40, color: theme.colorScheme.primary),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('重新載入'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
