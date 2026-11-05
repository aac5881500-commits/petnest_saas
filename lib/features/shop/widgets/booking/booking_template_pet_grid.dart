import 'booking_editorial_design.dart';
import 'booking_appearance_scope.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';

class BookingTemplatePetGrid extends StatelessWidget {
  const BookingTemplatePetGrid({
    super.key,
    required this.style,
    required this.pets,
    required this.selectedIds,
    required this.theme,
    required this.onToggle,
  });
  final String style;
  final List<Map<String, dynamic>> pets;
  final List<String> selectedIds;
  final HomeThemeModel theme;
  final void Function(String, bool) onToggle;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 250 ? 2 : 1;
      final width = columns == 1
          ? constraints.maxWidth
          : ((constraints.maxWidth - 14) / 2).clamp(0.0, 240.0);
      return Wrap(
        spacing: 14,
        runSpacing: 18,
        alignment: WrapAlignment.center,
        children: pets.asMap().entries.map((entry) {
          final pet = entry.value,
              id = (entry.value['petId'] ?? entry.value['name'] ?? '')
                  .toString();
          final selected = selectedIds.contains(id), cream = style == 'cream';
          final custom =
              BookingAppearanceScope.of(context).suiteColorMode != 'template';
          final frame = cream && custom
              ? Color.alphaBlend(
                  theme.primaryColor.withValues(
                    alpha: entry.key.isEven ? .12 : .2,
                  ),
                  theme.backgroundColor,
                )
              : cream
              ? (entry.key.isEven
                    ? const Color(0xFFFFE6A0)
                    : const Color(0xFFD4EEFF))
              : const Color(0xFFF8F0E5);
          final url = pet['photoUrl']?.toString() ?? '',
              previewAsset = pet['_previewAsset']?.toString();
          Widget fallback() => ColoredBox(
            color: frame,
            child: Center(
              child: Icon(Icons.pets, size: 46, color: theme.primaryColor),
            ),
          );
          final photo = previewAsset != null
              ? Image.asset(
                  previewAsset,
                  fit: BoxFit.cover,
                  errorBuilder: (_, error, stack) => fallback(),
                )
              : url.isNotEmpty
              ? Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, error, stack) => fallback(),
                )
              : fallback();
          final shape = BorderRadius.only(
            topLeft: Radius.circular(cream ? 30 : width / 2),
            topRight: Radius.circular(cream ? 30 : width / 2),
            bottomLeft: Radius.circular(cream ? 30 : 20),
            bottomRight: Radius.circular(cream ? 30 : 20),
          );
          final card = Container(
            decoration: BoxDecoration(
              color: frame,
              borderRadius: shape,
              border: selected
                  ? Border.all(color: theme.primaryColor, width: 2)
                  : null,
            ),
            padding: EdgeInsets.all(cream ? 7 : 6),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: shape,
                  child: AspectRatio(
                    aspectRatio: cream ? .92 : .90,
                    child: photo,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 6,
                  ),
                  child: Text(
                    pet['name']?.toString() ?? '未命名',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontFamily: cream
                          ? BookingEditorial.body(20, context).fontFamily
                          : null,
                      color: theme.textColor,
                      fontWeight: cream
                          ? BookingEditorial.title(20, context).fontWeight
                          : FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          );
          return SizedBox(
            width: width,
            child: Semantics(
              button: true,
              selected: selected,
              label: pet['name']?.toString(),
              child: InkWell(
                key: ValueKey('template-pet-$id'),
                onTap: () => onToggle(id, !selected),
                borderRadius: shape,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    if (cream)
                      Transform.rotate(
                        angle: entry.key.isEven ? -.025 : .025,
                        child: card,
                      )
                    else
                      card,
                    Positioned(
                      right: 1,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          selected
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          size: 27,
                          color: selected
                              ? theme.primaryColor
                              : const Color(0xFFC0CED6),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      );
    },
  );
}
