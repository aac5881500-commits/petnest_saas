import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/pre_arrival_appearance.dart';
import 'package:petnest_saas/core/models/pre_arrival_guide_model.dart';
import 'package:petnest_saas/core/models/shop_frontend_theme.dart';
import 'package:petnest_saas/features/booking/widgets/pre_arrival_appearance_surface.dart';
import 'package:petnest_saas/features/shop/widgets/store/store_banner_color_field.dart';

class PreArrivalAppearanceEditor extends StatelessWidget {
  const PreArrivalAppearanceEditor({
    super.key,
    required this.guide,
    required this.onChanged,
  });
  final PreArrivalGuideModel guide;
  final ValueChanged<PreArrivalGuideModel> onChanged;
  void update(Map<String, dynamic> change) =>
      onChanged(guide.copyWith(appearance: guide.appearance.copyWith(change)));
  @override
  Widget build(BuildContext context) {
    final a = guide.appearance;
    final palette = PreArrivalPalette.resolve(
      guide,
      ShopFrontendTheme.of(context),
      Theme.of(context).textTheme.bodyMedium?.fontFamily,
    );
    return Card(
      child: ExpansionTile(
        key: const ValueKey('pre-arrival-appearance'),
        initiallyExpanded: false,
        title: const Text(
          '整頁字體與顏色',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${PreArrivalAppearance.fonts[a.fontFamily]} · ${{'style': '版型原色', 'theme': '跟隨店家主題', 'custom': '自訂配色'}[a.colorMode]}',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        children: [
          const Text('只調整客人看到的本頁；右側預覽與全畫面會同步套用。'),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            key: ValueKey('arrival-font-${a.fontFamily}'),
            initialValue: a.fontFamily,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: '整頁字體',
              border: OutlineInputBorder(),
            ),
            items: PreArrivalAppearance.fonts.entries
                .map(
                  (e) => DropdownMenuItem(
                    value: e.key,
                    child: Text(
                      e.value,
                      style: TextStyle(
                        fontFamily: e.key == 'theme' || e.key == 'style'
                            ? null
                            : e.key,
                      ),
                    ),
                  ),
                )
                .toList(),
            onChanged: (v) {
              if (v != null) update({'fontFamily': v});
            },
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Expanded(child: Text('整頁文字大小')),
              Text('${(a.fontScale * 100).round()}%'),
              TextButton(
                onPressed: () => update({'fontScale': 1.0}),
                child: const Text('標準'),
              ),
            ],
          ),
          Slider(
            value: a.fontScale,
            min: .85,
            max: 1.4,
            divisions: 11,
            label: '${(a.fontScale * 100).round()}%',
            onChanged: (v) => update({'fontScale': v}),
          ),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('整頁配色', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                const {'style': '版型原色', 'theme': '跟隨店家主題', 'custom': '自訂顏色'}
                    .entries
                    .map(
                      (e) => ChoiceChip(
                        label: Text(e.value),
                        selected: a.colorMode == e.key,
                        onSelected: (_) => update({'colorMode': e.key}),
                      ),
                    )
                    .toList(),
          ),
          if (a.colorMode == 'theme')
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text('沿用店家首頁的主色、文字、背景與卡片顏色。'),
            ),
          if (a.colorMode == 'custom') ...[
            const SizedBox(height: 12),
            for (final entry in <String, (String, Color)>{
              'accentColor': ('主色／按鈕', palette.accent),
              'textColor': ('文字顏色', palette.ink),
              'backgroundColor': ('頁面背景', palette.paper),
              'cardColor': ('卡片底色', palette.card),
            }.entries)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(entry.value.$1),
                subtitle: Text(
                  '#${(a.color(entry.key) ?? entry.value.$2).toARGB32().toRadixString(16).substring(2).toUpperCase()}',
                ),
                trailing: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: a.color(entry.key) ?? entry.value.$2,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.black26),
                  ),
                ),
                onTap: () async {
                  final color = await showHomeColorPicker(
                    context,
                    initial: a.color(entry.key) ?? entry.value.$2,
                  );
                  if (color != null && context.mounted) {
                    update({entry.key: color});
                  }
                },
              ),
            const Text(
              '對比不足時會調整文字，必要時柔化卡片底色，讓內容保持清楚。',
              style: TextStyle(fontSize: 12),
            ),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => onChanged(
                guide.copyWith(appearance: const PreArrivalAppearance()),
              ),
              child: const Text('還原本頁字體與顏色'),
            ),
          ),
        ],
      ),
    );
  }
}
