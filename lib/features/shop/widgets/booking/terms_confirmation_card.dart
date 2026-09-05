// 檔案名稱：lib/features/shop/widgets/booking/terms_confirmation_card.dart
// 功能說明：填寫資料頁：條款確認卡片

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/policy_applicable_service.dart';
import 'package:petnest_saas/core/services/shop_policy_service.dart';

class TermsConfirmationCard extends StatelessWidget {
  const TermsConfirmationCard({
    super.key,
    required this.theme,
    required this.serviceType,
    required this.status,
    required this.onTap,
  });

  final HomeThemeModel theme;
  final String serviceType;
  final TermsStatus status;
  final VoidCallback onTap;

  String get _serviceLabel =>
      serviceType == PolicyApplicableService.daycare ? '安親' : '住宿';

  @override
  Widget build(BuildContext context) {
    if (!status.required) {
      return const SizedBox.shrink();
    }

    final bool accepted = status.accepted;
    final bool needsUpdate = status.versionUpdated;
    final Color accent = accepted
        ? const Color(0xFF2E8B47)
        : const Color(0xFFC45C26);
    final Color bg = accepted
        ? const Color(0xFFEAF6EE)
        : const Color(0xFFFFF4EC);
    final String timeText = status.acceptedAt == null
        ? ''
        : DateFormat('yyyy/MM/dd HH:mm').format(status.acceptedAt!);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: accent.withValues(alpha: 0.35)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  accepted ? Icons.check_circle : Icons.info_outline,
                  color: accent,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        accepted
                            ? '已確認$_serviceLabel服務條款'
                            : needsUpdate
                            ? '條款已更新，請重新確認'
                            : '$_serviceLabel服務條款　待確認',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: theme.textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '條款版本 v${status.version}',
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.textColor.withValues(alpha: 0.72),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        accepted ? '確認時間 $timeText' : '請閱讀完整內容並完成確認',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.textColor.withValues(alpha: 0.62),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: theme.textColor.withValues(alpha: 0.45),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
