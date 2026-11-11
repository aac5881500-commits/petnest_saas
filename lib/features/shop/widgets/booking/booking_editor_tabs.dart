import 'package:flutter/material.dart';

/// Workspace navigation and preview steps deliberately use different treatments.
class BookingEditorTabs extends StatelessWidget {
  const BookingEditorTabs({
    super.key,
    required this.selected,
    required this.labels,
    required this.onSelected,
    this.numbered = false,
  });
  final int selected;
  final Map<int, String> labels;
  final ValueChanged<int> onSelected;
  final bool numbered;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: numbered ? colors.surface : colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: numbered ? Border.all(color: colors.outlineVariant) : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final entry in labels.entries)
            Expanded(
              child: Semantics(
                selected: selected == entry.key,
                button: true,
                child: Material(
                  color: selected == entry.key
                      ? (numbered ? colors.primaryContainer : colors.surface)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    key: ValueKey(
                      'booking-${numbered ? 'step' : 'workspace'}-${entry.key}',
                    ),
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => onSelected(entry.key),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 10,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (numbered) ...[
                              Text(
                                '0${entry.key}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: colors.primary,
                                ),
                              ),
                              const SizedBox(height: 3),
                            ],
                            Text(
                              entry.value,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: selected == entry.key
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: selected == entry.key
                                    ? colors.primary
                                    : colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
