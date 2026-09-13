// 檔案名稱：lib/features/admin/widgets/admin_create_payment_section.dart
// 功能說明：手動建單付款：到店／轉帳可選；綠界僅店家會員資訊卡，不可提交。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/services/shop_payment_methods.dart';
import 'package:petnest_saas/features/booking/widgets/shop_payment_method_cards.dart';

class AdminCreatePaymentSection extends StatelessWidget {
  const AdminCreatePaymentSection({
    super.key,
    required this.catalog,
    required this.selectedMethod,
    required this.isManualMember,
    required this.onSelected,
    this.theme,
  });

  final ShopPaymentCatalog catalog;
  final String? selectedMethod;
  final bool isManualMember;
  final ValueChanged<String> onSelected;
  final HomeThemeModel? theme;

  @override
  Widget build(BuildContext context) {
    final ShopPaymentCatalog selectable =
        ShopPaymentMethods.adminCreateSelectableCatalog(catalog);
    final ShopPaymentCatalog online =
        ShopPaymentMethods.adminCreateOnlineInfoCatalog(catalog);
    final Color textColor =
        theme?.textColor ?? Theme.of(context).colorScheme.onSurface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Text('付款方式', style: TextStyle(fontWeight: FontWeight.w800)),
        ShopPaymentMethodCards(
          catalog: selectable,
          selectedMethod: selectedMethod,
          onSelected: onSelected,
          emptyMessage: selectable.isEmpty && (isManualMember || online.isEmpty)
              ? ShopPaymentMethods.noMethodsMessage
              : '目前沒有可在後台直接建立的付款方式（到店付款或銀行轉帳）。',
        ),
        if (isManualMember) ...<Widget>[
          const SizedBox(height: 14),
          Text(
            '綠界線上付款需由 App 會員在自己的訂單中操作。',
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: textColor.withValues(alpha: 0.72),
            ),
          ),
        ] else if (online.methods.isNotEmpty) ...<Widget>[
          const SizedBox(height: 14),
          Text(
            '綠界線上付款需由 App 會員在自己的訂單中操作。',
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: textColor.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: 8),
          ...online.methods.map((ShopPaymentMethodOption option) {
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: (theme?.backgroundColor ?? Colors.grey.shade50)
                      .withValues(alpha: 0.7),
                  border: Border.all(
                    color:
                        theme?.cardBorderColor ??
                        Theme.of(context).dividerColor,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      option.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '需由客戶至 App 訂單內付款',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color:
                            theme?.primaryColor ??
                            Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    if (option.subtitle.trim().isNotEmpty) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        option.subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: textColor.withValues(alpha: 0.65),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
        ],
      ],
    );
  }
}
