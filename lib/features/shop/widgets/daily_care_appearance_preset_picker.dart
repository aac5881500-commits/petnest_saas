import 'package:flutter/material.dart';
import '../../../core/models/daily_care_appearance_preset.dart';
import '../../../core/models/daily_care_setting_model.dart';
import '../../../core/models/daily_care_journal_layout.dart';
import '../../../core/widgets/daily_care_journal_renderer.dart';

class DailyCareAppearancePresetPicker extends StatelessWidget {
  const DailyCareAppearancePresetPicker({
    super.key,
    required this.setting,
    required this.onPreview,
    required this.onApply,
    this.enabled = true,
  });
  final DailyCareSettingModel setting;
  final ValueChanged<DailyCareAppearancePreset> onPreview, onApply;
  final bool enabled;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final columns = c.maxWidth >= 780
          ? 3
          : c.maxWidth >= 460
          ? 2
          : 1;
      final width = (c.maxWidth - (columns - 1) * 12) / columns;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final preset in dailyCareAppearancePresets)
            SizedBox(
              width: width,
              child: Card(
                key: ValueKey('daily-care-preset-${preset.id}'),
                margin: EdgeInsets.zero,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: preset.matches(setting)
                        ? preset.tint
                        : const Color(0xFFE1E6EC),
                    width: preset.matches(setting) ? 2 : 1,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: enabled ? () => onPreview(preset) : null,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ExcludeSemantics(
                          child: DailyCarePresetMiniature(
                            setting: preset.apply(setting),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                preset.name,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (preset.matches(setting))
                              Icon(
                                Icons.check_circle,
                                size: 18,
                                color: preset.tint,
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          preset.description,
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.5,
                            color: Color(0xFF657080),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton(
                              onPressed: enabled
                                  ? () => onPreview(preset)
                                  : null,
                              child: const Text('預覽'),
                            ),
                            FilledButton.tonal(
                              key: ValueKey(
                                'apply-daily-care-preset-${preset.id}',
                              ),
                              onPressed: enabled ? () => onApply(preset) : null,
                              child: const Text('套用'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}

class DailyCarePresetMiniature extends StatelessWidget {
  const DailyCarePresetMiniature({super.key, required this.setting});
  final DailyCareSettingModel setting;
  @override
  Widget build(BuildContext context) => Container(
    height: 128,
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: setting.backgroundColor(),
      borderRadius: BorderRadius.circular(10),
    ),
    child: LayoutBuilder(
      builder: (context, c) {
        final layouts = DailyCareJournalCardLayout.displaySorted(
          setting.resolvedJournalCards,
        ).take(5).toList();
        final gap = setting.cardGap / 4;
        final half = (c.maxWidth - gap) / 2;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: c.maxWidth * .5,
              height: 5,
              color: const Color(0xFF81948D),
            ),
            const SizedBox(height: 7),
            Expanded(
              child: Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final card in layouts)
                    Container(
                      width: card.isHalf ? half : c.maxWidth,
                      height: 19,
                      decoration: BoxDecoration(
                        color: DailyCareJournalThemeTokens.fillOf(
                          card.colorKey,
                        ),
                        borderRadius: BorderRadius.circular(
                          setting.cardRadius / 4,
                        ),
                        border: setting.showCardBorder
                            ? Border.all(color: const Color(0xFFCFD9DA))
                            : null,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 5),
                          child: Container(
                            width: card.isHalf ? 16 : 32,
                            height: 3,
                            color: const Color(0xFF9DAFAA),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );
}
