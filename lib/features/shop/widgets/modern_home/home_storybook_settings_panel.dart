import 'package:flutter/material.dart';
import '../../../../core/models/home_storybook_setting.dart';
import '../store/store_banner_color_field.dart';
import 'home_section_order.dart';

class HomeStorybookSettingsPanel extends StatefulWidget {
  const HomeStorybookSettingsPanel({
    super.key,
    required this.setting,
    required this.onChanged,
  });
  final HomeStorybookSetting setting;
  final ValueChanged<HomeStorybookSetting> onChanged;

  @override
  State<HomeStorybookSettingsPanel> createState() =>
      _HomeStorybookSettingsPanelState();
}

class _HomeStorybookSettingsPanelState
    extends State<HomeStorybookSettingsPanel> {
  HomeStorybookSetting get setting => widget.setting;
  ValueChanged<HomeStorybookSetting> get onChanged => widget.onChanged;
  late final _controllers = {
    'title': TextEditingController(text: setting.heroTitle),
    'subtitle': TextEditingController(text: setting.heroSubtitle),
    'button': TextEditingController(text: setting.heroButton),
  };

  @override
  void didUpdateWidget(covariant HomeStorybookSettingsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final values = {
      'title': setting.heroTitle,
      'subtitle': setting.heroSubtitle,
      'button': setting.heroButton,
    };
    for (final entry in values.entries) {
      final controller = _controllers[entry.key]!;
      if (controller.text != entry.value) controller.text = entry.value;
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final labels = {
      'quickBooking': '快速預約',
      'announcements': '消息公告',
      'rooms': '房型介紹',
      'featured': '精選商品',
      'storeEntrance': '好物商城',
      'about': '關於我們',
      'services': '照護服務',
      'policy': '入住須知',
      'faq': '常見問題',
      'reviews': '顧客分享',
      'shopInfo': '店家資訊',
      'facilities': '環境介紹',
      'dailyCare': '入住回報',
      'sharedEntries': '共用入口',
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('水彩外觀・共用卡片設定'),
              subtitle: const Text('套用後仍可逐項自訂，儲存外觀設定後生效。'),
              value: setting.enabled,
              onChanged: (value) => onChanged(setting.copyWith(enabled: value)),
            ),
            if (setting.enabled) ...[
              const Text(
                '主圖與裝飾',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'shop', label: Text('店家上傳海報')),
                  ButtonSegment(value: 'builtin', label: Text('可選內建插畫')),
                ],
                selected: {setting.heroSource},
                onSelectionChanged: (value) =>
                    onChanged(setting.copyWith(heroSource: value.single)),
              ),
              const SizedBox(height: 8),
              const Text(
                'APP 繪本主圖與花草裝飾隨程式提供。店家海報請到「首頁海報」上傳；房型、環境、商品、公告及店家照片請到各模組上傳。',
              ),
              if (setting.heroSource == 'builtin') ...[
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('顯示固定貓咪小屋插畫'),
                  value: setting.heroImage == 'cottage',
                  onChanged: (value) => onChanged(
                    setting.copyWith(heroImage: value ? 'cottage' : 'none'),
                  ),
                ),
                for (final field in [
                  (id: 'title', label: '主圖標題', value: setting.heroTitle),
                  (id: 'subtitle', label: '主圖副標題', value: setting.heroSubtitle),
                  (id: 'button', label: '預約按鈕文字', value: setting.heroButton),
                ])
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: TextFormField(
                      controller: _controllers[field.id],
                      maxLength: field.id == 'button' ? 20 : 100,
                      decoration: InputDecoration(labelText: field.label),
                      onChanged: (value) => onChanged(switch (field.id) {
                        'title' => setting.copyWith(heroTitle: value),
                        'subtitle' => setting.copyWith(heroSubtitle: value),
                        _ => setting.copyWith(heroButton: value),
                      }),
                    ),
                  ),
                DropdownButtonFormField<String>(
                  initialValue: setting.fontFamily,
                  decoration: const InputDecoration(labelText: '主圖標題字體'),
                  items: const [
                    DropdownMenuItem(value: 'jfOpenHuninn', child: Text('粉圓體')),
                    DropdownMenuItem(value: 'NotoSansTC', child: Text('思源黑體')),
                    DropdownMenuItem(value: 'KleeOne', child: Text('手寫楷書')),
                  ],
                  onChanged: (value) =>
                      onChanged(setting.copyWith(fontFamily: value)),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: setting.heroAlign,
                  decoration: const InputDecoration(labelText: '主圖文字對齊'),
                  items: const [
                    DropdownMenuItem(value: 'left', child: Text('靠左')),
                    DropdownMenuItem(value: 'center', child: Text('置中')),
                  ],
                  onChanged: (value) =>
                      onChanged(setting.copyWith(heroAlign: value)),
                ),
                _slider(
                  '主圖寬高比',
                  setting.heroAspect,
                  1.2,
                  4,
                  (v) => setting.copyWith(heroAspect: v),
                ),
                _slider(
                  '標題字級',
                  setting.titleSize,
                  18,
                  40,
                  (v) => setting.copyWith(titleSize: v),
                ),
              ],
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('額外快捷入口（預設關閉）'),
                subtitle: const Text('預約、房型、須知、會員會依店家功能開關顯示。'),
                value: setting.showShortcuts,
                onChanged: (v) => onChanged(setting.copyWith(showShortcuts: v)),
              ),
              _slider(
                '卡片圓角',
                setting.radius,
                0,
                40,
                (v) => setting.copyWith(radius: v),
              ),
              _slider(
                '卡片內距',
                setting.padding,
                0,
                24,
                (v) => setting.copyWith(padding: v),
              ),
              _slider(
                '區塊間距',
                setting.gap,
                4,
                32,
                (v) => setting.copyWith(gap: v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('水彩花草裝飾'),
                value: setting.decoration == 'flowers',
                onChanged: (v) => onChanged(
                  setting.copyWith(decoration: v ? 'flowers' : 'none'),
                ),
              ),
              _slider(
                '裝飾透明度',
                setting.decorationOpacity,
                0,
                1,
                (v) => setting.copyWith(decorationOpacity: v),
              ),
              StoreBannerColorField(
                label: '奶油卡片底色',
                argb: setting.paperColor,
                onChanged: (v) => onChanged(setting.copyWith(paperColor: v)),
              ),
              const SizedBox(height: 12),
              StoreBannerColorField(
                label: '藍色卡片底色',
                argb: setting.blueColor,
                onChanged: (v) => onChanged(setting.copyWith(blueColor: v)),
              ),
              const SizedBox(height: 12),
              StoreBannerColorField(
                label: '卡片邊框色',
                argb: setting.borderColor,
                onChanged: (v) => onChanged(setting.copyWith(borderColor: v)),
              ),
              const SizedBox(height: 12),
              const Text('套用繪本外框的區塊'),
              Wrap(
                spacing: 6,
                children: [
                  for (final id in [
                    ...HomeSectionOrder.defaultOrder,
                    'shopInfo',
                  ])
                    if (labels.containsKey(id))
                      FilterChip(
                        label: Text(labels[id]!),
                        selected: setting.decorateSections.contains(id),
                        onSelected: (selected) => onChanged(
                          setting.copyWith(
                            decorateSections: [
                              ...setting.decorateSections.where(
                                (value) => value != id,
                              ),
                              if (selected) id,
                            ],
                          ),
                        ),
                      ),
                ],
              ),
              const SizedBox(height: 12),
              const Text('使用藍色底的區塊（其餘使用奶油底）'),
              Wrap(
                spacing: 6,
                children: [
                  for (final id in setting.decorateSections)
                    if (labels.containsKey(id))
                      FilterChip(
                        label: Text(labels[id]!),
                        selected: setting.blueSections.contains(id),
                        onSelected: (selected) => onChanged(
                          setting.copyWith(
                            blueSections: [
                              ...setting.blueSections.where(
                                (value) => value != id,
                              ),
                              if (selected) id,
                            ],
                          ),
                        ),
                      ),
                ],
              ),
              const Text('區塊順序、開關、內部圖片、標題、文字、房型卡片和商品樣式，繼續由各區塊的設定調整。'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _slider(
    String label,
    double value,
    double min,
    double max,
    HomeStorybookSetting Function(double) update,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('$label ${value.toStringAsFixed(1)}'),
      Slider(
        value: value,
        min: min,
        max: max,
        onChanged: (v) => onChanged(update(v)),
      ),
    ],
  );
}
