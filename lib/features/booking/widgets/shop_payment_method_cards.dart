// 檔案名稱：lib/features/booking/widgets/shop_payment_method_cards.dart
// 功能說明：住宿／安親共用的五種付款方式選項卡

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/shop_payment_methods.dart';

class ShopPaymentMethodCards extends StatelessWidget {
  const ShopPaymentMethodCards({
    super.key,
    required this.catalog,
    required this.selectedMethod,
    required this.onSelected,
    this.emptyMessage = ShopPaymentMethods.noMethodsMessage,
  });

  final ShopPaymentCatalog catalog;
  final String? selectedMethod;
  final ValueChanged<String> onSelected;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (catalog.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(emptyMessage),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: catalog.methods.map((ShopPaymentMethodOption option) {
        final bool selected = selectedMethod == option.id;
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onSelected(option.id),
              borderRadius: BorderRadius.circular(14),
              child: Ink(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).dividerColor,
                    width: selected ? 1.6 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      option.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w600,
                      ),
                    ),
                    if (option.subtitle.trim().isNotEmpty) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        option.subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).textTheme.bodyMedium?.color
                              ?.withValues(alpha: 0.72),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
