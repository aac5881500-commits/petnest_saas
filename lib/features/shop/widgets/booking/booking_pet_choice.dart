import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';

class BookingPetChoice extends StatelessWidget {
  const BookingPetChoice({
    super.key,
    required this.pet,
    required this.selected,
    required this.theme,
    required this.onSelected,
    this.portrait = false,
  });
  final Map<String, dynamic> pet;
  final bool selected, portrait;
  final HomeThemeModel theme;
  final ValueChanged<bool> onSelected;
  @override
  Widget build(BuildContext context) {
    final url = pet['photoUrl']?.toString() ?? '';
    final avatar = ClipOval(
      child: SizedBox(
        width: portrait ? 64 : 24,
        height: portrait ? 64 : 24,
        child: ColoredBox(
          color: theme.primaryColor.withValues(alpha: 0.1),
          child: pet['_previewAsset'] is String
              ? Image.asset(
                  pet['_previewAsset'],
                  fit: BoxFit.cover,
                  errorBuilder: (_, error, stack) =>
                      Icon(Icons.pets, color: theme.primaryColor),
                )
              : url.isNotEmpty
              ? Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, error, stack) =>
                      Icon(Icons.pets, color: theme.primaryColor),
                )
              : Icon(
                  Icons.pets,
                  color: theme.primaryColor,
                  size: portrait ? 32 : 16,
                ),
        ),
      ),
    );
    final name = pet['name']?.toString() ?? '未命名';
    if (!portrait) {
      return FilterChip(
        avatar: avatar,
        label: Text(name),
        selected: selected,
        selectedColor: theme.primaryColor.withValues(alpha: 0.12),
        side: BorderSide(
          color: selected ? theme.primaryColor : theme.cardBorderColor,
        ),
        onSelected: onSelected,
      );
    }
    return Semantics(
      button: true,
      selected: selected,
      label: name,
      child: InkWell(
        onTap: () => onSelected(!selected),
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: 116,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected
                ? theme.primaryColor.withValues(alpha: 0.1)
                : theme.cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: selected ? theme.primaryColor : theme.cardBorderColor,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              avatar,
              const SizedBox(height: 10),
              Text(
                name,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: theme.textColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Icon(
                selected ? Icons.check_circle : Icons.add_circle_outline,
                size: 20,
                color: theme.primaryColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
