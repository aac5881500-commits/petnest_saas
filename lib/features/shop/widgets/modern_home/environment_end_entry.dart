import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_environment_section_setting.dart';

/// 設備列表末端入口；設定示意、即時預覽與正式前台共用。
class EnvironmentEndEntry extends StatelessWidget {
  const EnvironmentEndEntry({
    super.key,
    required this.style,
    required this.color,
    required this.onPressed,
    this.label = '查看環境',
    this.semanticLabel = '查看完整環境介紹',
  });

  final String style;
  final String label, semanticLabel;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final resolved = HomeEnvironmentEndEntryStyles.migrate(style);
    final minimal = resolved == HomeEnvironmentEndEntryStyles.minimal;
    final text = resolved == HomeEnvironmentEndEntryStyles.text;
    final shape = resolved == HomeEnvironmentEndEntryStyles.circle
        ? const CircleBorder()
        : RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(text ? 24 : 12),
            side: resolved == HomeEnvironmentEndEntryStyles.square
                ? BorderSide(color: color.withValues(alpha: .3))
                : BorderSide.none,
          );
    return Tooltip(
      message: semanticLabel,
      child: Semantics(
        label: semanticLabel,
        button: true,
        excludeSemantics: true,
        child: Material(
          color: minimal ? Colors.transparent : color.withValues(alpha: .1),
          shape: shape,
          child: InkWell(
            onTap: onPressed,
            customBorder: shape,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: text ? 16 : 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (text) ...[
                      Text(label, style: TextStyle(color: color)),
                      const SizedBox(width: 6),
                    ],
                    Icon(
                      minimal
                          ? Icons.keyboard_double_arrow_right_rounded
                          : Icons.arrow_forward_rounded,
                      color: color,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
