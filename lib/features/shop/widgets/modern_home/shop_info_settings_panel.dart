import 'shop_info_template_preview.dart';
import 'owner_image_upload_button.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_shop_info_setting.dart';
import 'home_card_image.dart';
import 'home_section_settings_group.dart';

class ShopInfoSettingsPanel extends StatefulWidget {
  const ShopInfoSettingsPanel({
    super.key,
    this.shopId = '',
    this.defaultIntro = '',
    this.onBusyChanged,
    required this.setting,
    required this.onChanged,
    this.imageChoices = const [],
    this.onManage,
  });
  final String shopId;
  final String defaultIntro;
  final ValueChanged<bool>? onBusyChanged;
  final HomeShopInfoSetting setting;
  final ValueChanged<HomeShopInfoSetting> onChanged;
  final List<Map<String, String>> imageChoices;
  final VoidCallback? onManage;
  @override
  State<ShopInfoSettingsPanel> createState() => _ShopInfoSettingsPanelState();
}

class _ShopInfoSettingsPanelState extends State<ShopInfoSettingsPanel> {
  late final TextEditingController _title, _phone, _map, _line, _intro;
  final ScrollController _scroll = ScrollController();
  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.setting.sectionTitle);
    _phone = TextEditingController(text: widget.setting.phoneLabel);
    _map = TextEditingController(text: widget.setting.mapLabel);
    _line = TextEditingController(text: widget.setting.lineLabel);
    _intro = TextEditingController(
      text: widget.setting.introText ?? widget.defaultIntro,
    );
  }

  @override
  void didUpdateWidget(ShopInfoSettingsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    void sync(TextEditingController controller, String value) {
      if (controller.text != value) {
        controller.value = TextEditingValue(
          text: value,
          selection: TextSelection.collapsed(offset: value.length),
        );
      }
    }

    sync(_title, widget.setting.sectionTitle);
    sync(_phone, widget.setting.phoneLabel);
    sync(_map, widget.setting.mapLabel);
    sync(_line, widget.setting.lineLabel);
    sync(_intro, widget.setting.introText ?? widget.defaultIntro);
  }

  @override
  void dispose() {
    for (final controller in [_title, _phone, _map, _line, _intro]) {
      controller.dispose();
    }
    _scroll.dispose();
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
      controller: _scroll,
      primary: false,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 28),
      children: [
        const Text(
          '首頁底部店家資訊',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        const Text('此分頁可獨立設定照片、排列版型、顯示內容及聯絡按鈕；不需套用快速模板，也可搭配其他首頁風格。'),
        const SizedBox(height: 12),
        HomeSectionSettingsGroup(
          title: '顯示方式',
          children: [
            const Text('店家資訊固定顯示；可選擇呈現方式與快速模板。'),
            const SizedBox(height: 12),
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
          title: '店家資訊快速模板',
          children: [
            const Text('點選即套好照片位置、資訊與聯絡按鈕；保留你上傳的圖片及店家資料，也保留上方選擇的顯示方式。'),
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
                              onTap: () => update(p.apply(s)),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      height: 96,
                                      width: double.infinity,
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: ShopInfoTemplatePreview(
                                          preset: p,
                                        ),
                                      ),
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
          ],
        ),
        HomeSectionSettingsGroup(
          title: '進階外觀微調（選填）',
          storageId: 'shop-info-advanced-style',
          children: [
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
            choices(
              '按鈕造型',
              const {
                'standard': '一般圖文',
                'circle': '圓形圖示・下方文字',
                'tile': '獨立方卡',
                'pill': '膠囊按鈕',
              },
              s.actionPresentation,
              (v) => update(s.copyWith(actionPresentation: v)),
            ),
            choices(
              '照片形狀',
              const {'rounded': '圓角照片', 'circle': '圓形照片', 'square': '方形照片'},
              s.photoShape,
              (v) => update(s.copyWith(photoShape: v)),
            ),
            choices(
              '角落裝飾',
              const {'none': '無裝飾', 'leaf': '葉片', 'paw': '腳印', 'cat': '小動物線條'},
              s.decoration,
              (v) => update(s.copyWith(decoration: v)),
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
              const {
                'mixed': '電話實色・地圖外框・LINE綠色',
                'outlined': '外框按鈕',
                'light': '白底品牌色按鈕',
                'filled': '實色按鈕',
                'text': '文字按鈕',
              },
              s.buttonStyle,
              (v) => update(s.copyWith(buttonStyle: v)),
            ),
          ],
        ),
        HomeSectionSettingsGroup(
          title: '聯絡按鈕與標題（選填）',
          storageId: 'shop-info-advanced-actions',
          children: [
            TextField(
              key: const ValueKey('footer-section-title'),
              controller: _title,
              decoration: const InputDecoration(labelText: '資訊區塊標題'),
              onChanged: (v) => update(s.copyWith(sectionTitle: v)),
            ),
            choices(
              '按鈕排列',
              const {
                'wrap': '自動換行',
                'threeColumns': '同列等寬',
                'vertical': '直排按鈕',
              },
              s.actionLayout,
              (v) => update(s.copyWith(actionLayout: v)),
            ),
            const Text('電話、地圖與已填寫的社群聯絡方式固定顯示，無法個別關閉。'),
            TextField(
              controller: _phone,
              decoration: const InputDecoration(labelText: '電話按鈕文字'),
              onChanged: (v) => update(s.copyWith(phoneLabel: v)),
            ),
            TextField(
              controller: _map,
              decoration: const InputDecoration(labelText: '地圖按鈕文字'),
              onChanged: (v) => update(s.copyWith(mapLabel: v)),
            ),
            TextField(
              controller: _line,
              decoration: const InputDecoration(labelText: 'LINE按鈕文字'),
              onChanged: (v) => update(s.copyWith(lineLabel: v)),
            ),
            const Text('電話、地址及LINE網址引用店家基本資料；沒有資料的按鈕會停用。'),
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
            if (s.imageSource == 'photo' && widget.shopId.isNotEmpty)
              OwnerImageUploadButton(
                shopId: widget.shopId,
                label: '上傳店面照片',
                onBusyChanged: widget.onBusyChanged,
                onUploaded: (url) =>
                    update(widget.setting.copyWith(imageUrl: url)),
              ),
            if (s.layout == 'photoContact') ...[
              Text('左側照片寬度 ${(s.photoFraction * 100).round()}%'),
              Slider(
                value: s.photoFraction,
                min: .2,
                max: .5,
                onChanged: (v) => update(s.copyWith(photoFraction: v)),
              ),
            ],
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
                      update(s.copyWith(imageUrl: v));
                    }
                  },
                ),
              const SizedBox(height: 8),
              const Text(
                '尚未選圖時沿用關於我們封面或環境照片。可上傳店面照片、選擇現有店家圖片，或切換至平台圖庫。',
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
            const Text(
              '名稱、營業時間、地址、電話與已填寫的字號固定顯示，內容引用店家基本資料；統編仍遵守原公開設定。可拖曳下方欄位調整順序。',
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('shop-info-introduction'),
              controller: _intro,
              minLines: 2,
              maxLines: 4,
              maxLength: 300,
              decoration: const InputDecoration(
                labelText: '店家簡介',
                helperText: '顯示在本頁店家資訊區。未編輯時沿用原簡介；清空後不顯示文字。',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => update(s.copyWith(introText: v)),
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
              itemCount: s.orderedFields.length,
              onReorder: (oldIndex, newIndex) {
                final fields = [...s.orderedFields];
                if (newIndex > oldIndex) newIndex--;
                fields.insert(newIndex, fields.removeAt(oldIndex));
                update(s.copyWith(fields: fields));
              },
              itemBuilder: (context, i) => ListTile(
                key: ValueKey(s.orderedFields[i]),
                title: Text(
                  HomeShopInfoSetting.fieldLabels[s.orderedFields[i]]!,
                ),
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
