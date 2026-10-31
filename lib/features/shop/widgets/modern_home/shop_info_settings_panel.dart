import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_shop_info_setting.dart';
import 'home_card_image.dart';
import 'home_section_settings_group.dart';

class ShopInfoSettingsPanel extends StatefulWidget {
  const ShopInfoSettingsPanel({
    super.key,
    required this.setting,
    required this.onChanged,
    this.imageChoices = const [],
    this.onManage,
  });
  final HomeShopInfoSetting setting;
  final ValueChanged<HomeShopInfoSetting> onChanged;
  final List<Map<String, String>> imageChoices;
  final VoidCallback? onManage;
  @override
  State<ShopInfoSettingsPanel> createState() => _ShopInfoSettingsPanelState();
}

class _ShopInfoSettingsPanelState extends State<ShopInfoSettingsPanel> {
  late final TextEditingController _url;
  String? _urlError;
  @override
  void initState() {
    super.initState();
    _url = TextEditingController(text: widget.setting.imageUrl);
  }

  @override
  void didUpdateWidget(ShopInfoSettingsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_urlError == null && _url.text != widget.setting.imageUrl) {
      _url.text = widget.setting.imageUrl;
    }
  }

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  void update(HomeShopInfoSetting s) => widget.onChanged(s);
  Widget choices(
    String title,
    Map<String, String> values,
    String selected,
    ValueChanged<String> change,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          for (final e in values.entries)
            ChoiceChip(
              label: Text(e.value),
              selected: e.key == selected,
              onSelected: (_) => change(e.key),
            ),
        ],
      ),
      const SizedBox(height: 12),
    ],
  );
  @override
  Widget build(BuildContext context) {
    final s = widget.setting;
    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 28),
      children: [
        HomeSectionSettingsGroup(
          title: '顯示方式',
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('顯示店家資訊'),
              subtitle: const Text('只控制此資訊區塊，不會修改導覽選單或店家基本資料。'),
              value: s.enabled,
              onChanged: (v) => update(s.copyWith(enabled: v)),
            ),
            choices(
              '位置與展開方式',
              HomeShopInfoSetting.modes,
              s.mode,
              (v) => update(s.copyWith(mode: v)),
            ),
            const Text(
              '可搭配左側選單或底部選單。固定資訊列會在底部選單上方，保留內容空間；點擊或上拉可看完整資訊。',
              style: TextStyle(fontSize: 12, height: 1.5),
            ),
          ],
        ),
        HomeSectionSettingsGroup(
          title: '10 組風格預設',
          children: [
            const Text('取自十張概念圖的頁尾風格；只套用店家資訊，不加入選房助手等未來功能。'),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 600
                    ? 3
                    : constraints.maxWidth < 280
                    ? 1
                    : 2;
                final width =
                    (constraints.maxWidth - (columns - 1) * 10) / columns;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final p in shopInfoPresets)
                      SizedBox(
                        width: width,
                        child: Semantics(
                          selected: p.id == s.preset && !s.followTheme,
                          child: Material(
                            color: Color(p.surface),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: p.id == s.preset && !s.followTheme
                                    ? Theme.of(context).colorScheme.primary
                                    : Color(p.accent).withValues(alpha: 0.3),
                                width: p.id == s.preset && !s.followTheme
                                    ? 2
                                    : 1,
                              ),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => update(
                                s.copyWith(
                                  preset: p.id,
                                  followTheme: false,
                                  layout: p.layout,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.storefront_outlined,
                                          color: Color(p.accent),
                                          size: 22,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Container(
                                            height: 6,
                                            color: Color(
                                              p.text,
                                            ).withValues(alpha: 0.25),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      p.label,
                                      style: TextStyle(
                                        color: Color(p.text),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      HomeShopInfoSetting.layouts[p.layout]!,
                                      style: TextStyle(
                                        color: Color(
                                          p.text,
                                        ).withValues(alpha: 0.75),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('配色跟隨整體主題'),
              subtitle: const Text('關閉時使用選取風格的配色。'),
              value: s.followTheme,
              onChanged: (v) => update(s.copyWith(followTheme: v)),
            ),
            choices(
              '排列版型',
              HomeShopInfoSetting.layouts,
              s.layout,
              (v) => update(s.copyWith(layout: v)),
            ),
            Text('圓角 ${s.radius.round()}'),
            Slider(
              value: s.radius,
              min: 0,
              max: 32,
              divisions: 16,
              label: '${s.radius.round()}',
              onChanged: (v) => update(s.copyWith(radius: v)),
            ),
            choices(
              '聯絡按鈕',
              const {'outlined': '外框按鈕', 'filled': '實色按鈕', 'text': '文字按鈕'},
              s.buttonStyle,
              (v) => update(s.copyWith(buttonStyle: v)),
            ),
          ],
        ),
        HomeSectionSettingsGroup(
          title: '圖片與照片',
          children: [
            choices(
              '圖片來源',
              const {
                'none': '不放圖片',
                'logo': '店家 Logo',
                'photo': '店家照片／自訂圖片',
                'library': '平台圖庫',
              },
              s.imageSource,
              (v) => update(s.copyWith(imageSource: v)),
            ),
            if (s.layout == 'plain')
              const Text('目前選擇純文字頁尾，照片設定會保留；切換其他版型即可顯示。'),
            if (s.imageSource == 'photo') ...[
              if (widget.imageChoices.isNotEmpty)
                DropdownButtonFormField<String>(
                  key: ValueKey('photo-choice-${s.imageUrl}'),
                  initialValue:
                      widget.imageChoices.any((i) => i['url'] == s.imageUrl)
                      ? s.imageUrl
                      : null,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: '使用現有店家圖片',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final c in widget.imageChoices)
                      DropdownMenuItem(
                        value: c['url'],
                        child: Text(c['label']!),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _urlError = null);
                      update(s.copyWith(imageUrl: v));
                    }
                  },
                ),
              const SizedBox(height: 12),
              TextField(
                controller: _url,
                decoration: InputDecoration(
                  labelText: '自訂圖片 HTTPS 網址',
                  hintText: 'https://…',
                  errorText: _urlError,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (v) {
                  final url = v.trim();
                  final uri = Uri.tryParse(url);
                  final valid =
                      url.isEmpty ||
                      (uri?.scheme == 'https' && uri!.host.isNotEmpty);
                  setState(
                    () =>
                        _urlError = valid ? null : '請使用完整 HTTPS 圖片網址，此輸入尚未套用。',
                  );
                  if (valid) update(s.copyWith(imageUrl: url));
                },
              ),
              const SizedBox(height: 8),
              const Text(
                '留空時優先使用關於我們封面或環境照片。要換新的店家照片，可從內容管理上傳後再選用。',
                style: TextStyle(fontSize: 12, height: 1.5),
              ),
              if (widget.onManage != null)
                TextButton.icon(
                  onPressed: widget.onManage,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('管理店家照片'),
                ),
            ],
            if (s.imageSource == 'library')
              HomeCardImageSettings(
                setting: s.libraryImage,
                onChanged: (v) => update(s.copyWith(libraryImage: v)),
                showSource: false,
              ),
            if (s.imageSource != 'none')
              choices(
                '照片顯示',
                const {'cover': '填滿裁切', 'contain': '完整顯示'},
                s.imageFit,
                (v) => update(s.copyWith(imageFit: v)),
              ),
          ],
        ),
        HomeSectionSettingsGroup(
          title: '顯示內容與順序',
          children: [
            const Text('內容沿用店家基本資料。這裡只控制外觀，不修改電話、地址、營業時間。'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('店家名稱'),
              value: s.showName,
              onChanged: (v) => update(s.copyWith(showName: v)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('店家簡介'),
              value: s.showIntro,
              onChanged: (v) => update(s.copyWith(showIntro: v)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('電話、地圖與已設定的社群按鈕'),
              value: s.showActions,
              onChanged: (v) => update(s.copyWith(showActions: v)),
            ),
            for (final e in HomeShopInfoSetting.fieldLabels.entries)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(e.value),
                value: s.fields.contains(e.key),
                onChanged: (v) => update(
                  s.copyWith(
                    fields: v == true
                        ? [...s.fields, e.key]
                        : s.fields.where((k) => k != e.key).toList(),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            const Text(
              '營業資訊順序（拖曳右側把手）',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: s.fields.length,
              onReorder: (oldIndex, newIndex) {
                final fields = [...s.fields];
                if (newIndex > oldIndex) newIndex--;
                fields.insert(newIndex, fields.removeAt(oldIndex));
                update(s.copyWith(fields: fields));
              },
              itemBuilder: (context, i) => ListTile(
                key: ValueKey(s.fields[i]),
                title: Text(HomeShopInfoSetting.fieldLabels[s.fields[i]]!),
                trailing: ReorderableDragStartListener(
                  index: i,
                  child: const Icon(Icons.drag_handle),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
