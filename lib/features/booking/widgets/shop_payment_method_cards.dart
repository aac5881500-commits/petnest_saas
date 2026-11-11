import 'package:petnest_saas/features/shop/widgets/booking/booking_appearance_scope.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_editorial_design.dart';
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
    final a = BookingAppearanceScope.of(context);
    final styled = const ['editorial', 'cream'].contains(a.style);
    final cream = a.style == 'cream';
    final radius = BorderRadius.circular(styled ? (cream ? 20 : 8) : 14);
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
              borderRadius: radius,
              child: Ink(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: styled
                      ? (selected
                            ? BookingEditorial.tint(context)
                            : BookingEditorial.theme(context).cardColor)
                      : null,
                  borderRadius: radius,
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
                    if (styled)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            selected
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            color: BookingEditorial.theme(context).primaryColor,
                            size: 21,
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              option.title,
                              style: BookingEditorial.title(16, context),
                            ),
                          ),
                        ],
                      )
                    else
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
