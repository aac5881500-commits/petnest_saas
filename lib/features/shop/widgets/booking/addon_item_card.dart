import 'booking_appearance_scope.dart';
import 'package:flutter/material.dart';

/// Service description and price stay on separate rows on narrow screens.
class AddonItemCard extends StatelessWidget {
  const AddonItemCard({
    super.key,
    required this.item,
    required this.isSelected,
    this.priceUnit = '',
    this.singleChoice = false,
    this.accentColor,
  });
  final Map item;
  final bool isSelected, singleChoice;
  final String priceUnit;
  final Color? accentColor;
  @override
  Widget build(BuildContext context) {
    final style = BookingAppearanceScope.of(context).serviceStyle;
    final accent = accentColor ?? Theme.of(context).colorScheme.primary;
    final description = (item['desc'] ?? '').toString().trim();
    if (style == 'editorial' &&
        MediaQuery.textScalerOf(context).scale(14) <= 21) {
      return Semantics(
        selected: isSelected,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? accent : const Color(0xFFDFE3E8),
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isSelected
                    ? Icons.check_circle
                    : singleChoice
                    ? Icons.radio_button_unchecked
                    : Icons.check_box_outline_blank,
                color: isSelected ? accent : Colors.grey,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['name']?.toString() ?? '',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        description,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.5,
                          color: Color(0xFF596574),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 90,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'NT\$ ${item['price'] ?? 0}',
                      style: TextStyle(
                        color: accent,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (priceUnit.isNotEmpty)
                      Text(
                        priceUnit,
                        textAlign: TextAlign.end,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF596574),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Semantics(
      selected: isSelected,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? accent.withValues(alpha: .06) : Colors.white,
          borderRadius: BorderRadius.circular(
            style == 'premium'
                ? 4
                : style == 'journal'
                ? 18
                : 14,
          ),
          border: style == 'editorial'
              ? Border(
                  bottom: BorderSide(
                    color: isSelected ? accent : const Color(0xFFDFE3E8),
                  ),
                )
              : Border.all(
                  color: isSelected ? accent : const Color(0xFFDFE3E8),
                  width: isSelected ? 1.5 : 1,
                ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  isSelected
                      ? (singleChoice
                            ? Icons.radio_button_checked
                            : Icons.check_box_rounded)
                      : (singleChoice
                            ? Icons.radio_button_unchecked
                            : Icons.check_box_outline_blank_rounded),
                  color: isSelected ? accent : Colors.grey,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item['name']?.toString() ?? '',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF283341),
                    ),
                  ),
                ),
                if (isSelected)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      '已選',
                      style: TextStyle(
                        color: accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF596574),
                  height: 1.5,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'NT\$ ${item['price'] ?? 0}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: accent,
                  ),
                ),
                if (priceUnit.isNotEmpty)
                  Text(
                    priceUnit,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF596574),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
