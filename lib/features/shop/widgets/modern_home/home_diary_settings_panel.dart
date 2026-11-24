import 'package:flutter/material.dart';
import '../../../../core/models/home_diary_setting.dart';
import '../store/store_banner_color_field.dart';

class HomeDiarySettingsPanel extends StatefulWidget {
  const HomeDiarySettingsPanel({
    super.key,
    required this.setting,
    required this.onChanged,
    required this.onOpenPhotos,
    required this.onOpenEnvironment,
  });
  final HomeDiarySetting setting;
  final ValueChanged<HomeDiarySetting> onChanged;
  final VoidCallback onOpenPhotos, onOpenEnvironment;
  @override
  State<HomeDiarySettingsPanel> createState() => _HomeDiarySettingsPanelState();
}

class _HomeDiarySettingsPanelState extends State<HomeDiarySettingsPanel> {
  HomeDiarySetting get s => widget.setting;
  late final Map<String, TextEditingController> _controllers = {
    for (final entry in _texts.entries)
      entry.key: TextEditingController(text: entry.value),
  };
  Map<String, String> get _texts => {
    'coverTitle': s.coverTitle,
    'coverSubtitle': s.coverSubtitle,
    'coverTag': s.coverTag,
    for (final key in ['service1', 'service2', 'service3']) key: s.refText(key),
    for (final id in HomeDiarySetting.sectionLabels.keys)
      id: s.titles[id] ?? HomeDiarySetting.sectionLabels[id]!,
  };

  @override
  void didUpdateWidget(covariant HomeDiarySettingsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    for (final entry in _texts.entries) {
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

  void change(HomeDiarySetting next) => widget.onChanged(next);
  HomeDiarySetting reference(String key, dynamic value) =>
      s.copyWith(reference: {...s.reference, key: value});

  Widget textField(String id, String label, ValueChanged<String> update) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: TextFormField(
          controller: _controllers[id],
          decoration: InputDecoration(labelText: label),
          maxLength: 100,
          onChanged: update,
        ),
      );

  Widget select(
    String label,
    String value,
    Map<String, String> options,
    ValueChanged<String> update,
  ) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: DropdownButtonFormField<String>(
      key: ValueKey('$label-$value'),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final entry in options.entries)
          DropdownMenuItem(value: entry.key, child: Text(entry.value)),
      ],
      onChanged: (next) {
        if (next != null) update(next);
      },
    ),
  );

  Widget slider(
    String label,
    double value,
    double min,
    double max,
    HomeDiarySetting Function(double) update,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('$label ${value.toStringAsFixed(1)}'),
      Slider(
        value: value,
        min: min,
        max: max,
        onChanged: (v) => change(update(v)),
      ),
    ],
  );

  Widget toggle(
    String title,
    bool value,
    HomeDiarySetting Function(bool) update,
  ) => SwitchListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(title),
    value: value,
    onChanged: (v) => change(update(v)),
  );

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          toggle('C｜貓咪日常誌版型', s.enabled, (v) => s.copyWith(enabled: v)),
          const Text('封面、房型、環境、商品、公告、關於我們的照片由店主上傳。紙張、膠帶、花草與爪印由 APP 提供。'),
          if (s.enabled) ...[
            ExpansionTile(
              initiallyExpanded: true,
              title: const Text('C 原圖構圖・新增版型功能'),
              tilePadding: EdgeInsets.zero,
              children: [
                const Text('套用 C 後，各區塊預設使用日常誌專用卡片。照片與內文仍讀本店資料。'),
                const Text('每個區塊的排版選擇已加入「日常誌」選項；可單獨改回其他版型，不會被模板強制覆蓋。'),
                toggle('花草角落裝飾', s.flowers, (v) => reference('flowers', v)),
                toggle(
                  '封面照片柔邊融合',
                  s.refFlag('coverBlend'),
                  (v) => reference('coverBlend', v),
                ),
                toggle(
                  '環境照片貼膠帶',
                  s.refFlag('photoTape'),
                  (v) => reference('photoTape', v),
                ),
                toggle(
                  '章節標題貼膠帶',
                  s.refFlag('headingTape'),
                  (v) => reference('headingTape', v),
                ),
                toggle(
                  '回報顯示入住寵物照片',
                  s.refFlag('careAvatar'),
                  (v) => reference('careAvatar', v),
                ),
                toggle(
                  '回報名稱與進度同排',
                  s.refFlag('careInline'),
                  (v) => reference('careInline', v),
                ),
                toggle(
                  '回報使用連續進度條',
                  s.refFlag('careContinuous'),
                  (v) => reference('careContinuous', v),
                ),
                StoreBannerColorField(
                  label: '爪印顏色（軸線另設）',
                  argb: s.markerColor,
                  onChanged: (v) => change(reference('markerColor', v)),
                ),
                slider(
                  '封面說明字級',
                  s.refNumber('coverBodySize'),
                  9,
                  18,
                  (v) => reference('coverBodySize', v),
                ),
                slider(
                  '房型照片高度',
                  s.refNumber('roomPhotoHeight'),
                  70,
                  200,
                  (v) => reference('roomPhotoHeight', v),
                ),
                slider(
                  '房型卡片寬度比例',
                  s.refNumber('roomFraction'),
                  .35,
                  .7,
                  (v) => reference('roomFraction', v),
                ),
                slider(
                  '關於我們照片高度',
                  s.refNumber('aboutPhotoHeight'),
                  70,
                  200,
                  (v) => reference('aboutPhotoHeight', v),
                ),
                slider(
                  '關於我們照片比例',
                  s.refNumber('aboutFraction'),
                  .35,
                  .7,
                  (v) => reference('aboutFraction', v),
                ),
                slider(
                  '商品橫式卡照片比例',
                  s.refNumber('productFraction'),
                  .35,
                  .7,
                  (v) => reference('productFraction', v),
                ),
                toggle(
                  '顯示照護服務介紹（三項）',
                  s.refFlag('careServices'),
                  (v) => reference('careServices', v),
                ),
                for (final key in ['service1', 'service2', 'service3'])
                  textField(
                    key,
                    '照護服務 ${key.substring(7)} 名稱',
                    (v) => change(reference(key, v)),
                  ),
              ],
            ),
            ExpansionTile(
              initiallyExpanded: true,
              tilePadding: EdgeInsets.zero,
              title: const Text('封面分欄與店家照片'),
              children: [
                select('封面排法', s.coverLayout, {
                  'split': '文字與照片左右分欄',
                  'banner': '照片上方・文字下方',
                }, (v) => change(s.copyWith(coverLayout: v))),
                select(
                  '照片來源',
                  s.coverPhotoSource,
                  {'cover': '店家封面優先（無圖時使用海報）', 'banner': '已發布海報優先（無圖時使用封面）'},
                  (v) => change(s.copyWith(coverPhotoSource: v)),
                ),
                OutlinedButton.icon(
                  onPressed: widget.onOpenPhotos,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: const Text('管理店家封面與海報'),
                ),
                select(
                  '分欄照片位置',
                  s.coverPhotoSide,
                  {'left': '照片在左', 'right': '照片在右'},
                  (v) => change(s.copyWith(coverPhotoSide: v)),
                ),
                textField(
                  'coverTag',
                  '封面小標籤',
                  (v) => change(s.copyWith(coverTag: v)),
                ),
                textField(
                  'coverTitle',
                  '封面主標題',
                  (v) => change(s.copyWith(coverTitle: v)),
                ),
                textField(
                  'coverSubtitle',
                  '封面說明',
                  (v) => change(s.copyWith(coverSubtitle: v)),
                ),
                select('日記字體', s.fontFamily, {
                  'KleeOne': '手寫楷書',
                  'jfOpenHuninn': '粉圓體',
                  'NotoSansTC': '思源黑體',
                }, (v) => change(s.copyWith(fontFamily: v))),
                slider(
                  '封面照片比例',
                  s.coverPhotoFraction,
                  .35,
                  .7,
                  (v) => s.copyWith(coverPhotoFraction: v),
                ),
                slider(
                  '封面照片寬高比',
                  s.coverPhotoAspect,
                  .6,
                  2.4,
                  (v) => s.copyWith(coverPhotoAspect: v),
                ),
                slider(
                  '封面標題字級',
                  s.coverTitleSize,
                  18,
                  38,
                  (v) => s.copyWith(coverTitleSize: v),
                ),
              ],
            ),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('時間軸、爪印與平台裝飾'),
              children: [
                toggle(
                  '顯示時間軸線',
                  s.showTimeline,
                  (v) => s.copyWith(showTimeline: v),
                ),
                select('時間軸標記', s.marker, {
                  'paw': '爪印',
                  'dot': '圓點',
                }, (v) => change(s.copyWith(marker: v))),
                StoreBannerColorField(
                  label: '時間軸與標記顏色',
                  argb: s.lineColor,
                  onChanged: (v) => change(s.copyWith(lineColor: v)),
                ),
                slider(
                  '時間軸線寬',
                  s.lineWidth,
                  .5,
                  4,
                  (v) => s.copyWith(lineWidth: v),
                ),
                slider(
                  '時間軸側邊寬度',
                  s.gutter,
                  20,
                  48,
                  (v) => s.copyWith(gutter: v),
                ),
                slider(
                  '章節標題字級',
                  s.headingSize,
                  13,
                  26,
                  (v) => s.copyWith(headingSize: v),
                ),
                toggle(
                  '使用 APP 紙張裝飾',
                  s.showPaper,
                  (v) => s.copyWith(showPaper: v),
                ),
                toggle(
                  '使用 APP 膠帶裝飾',
                  s.showTape,
                  (v) => s.copyWith(showTape: v),
                ),
                slider(
                  '紙張與膠帶透明度',
                  s.decorationOpacity,
                  0,
                  1,
                  (v) => s.copyWith(decorationOpacity: v),
                ),
              ],
            ),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('環境照片交錯排版'),
              children: [
                const Text('請在環境介紹選擇「日記交錯圖文」，內容同步店家已上傳的環境特色。'),
                OutlinedButton(
                  onPressed: widget.onOpenEnvironment,
                  child: const Text('管理環境特色與圖片'),
                ),
                toggle(
                  '左右交替照片',
                  s.alternatePhotos,
                  (v) => s.copyWith(alternatePhotos: v),
                ),
                slider(
                  '環境標題字級',
                  s.refNumber('environmentTitleSize'),
                  9,
                  22,
                  (v) => reference('environmentTitleSize', v),
                ),
                slider(
                  '環境說明字級',
                  s.refNumber('environmentBodySize'),
                  9,
                  22,
                  (v) => reference('environmentBodySize', v),
                ),
                slider(
                  '環境照片高度',
                  s.environmentPhotoHeight,
                  90,
                  220,
                  (v) => s.copyWith(environmentPhotoHeight: v),
                ),
                slider(
                  '環境照片寬度比例',
                  s.environmentPhotoFraction,
                  .35,
                  .65,
                  (v) => s.copyWith(environmentPhotoFraction: v),
                ),
              ],
            ),
            toggle(
              '入住回報使用精簡橫條',
              s.compactCare,
              (v) => s.copyWith(compactCare: v),
            ),
            toggle(
              '入住須知與 FAQ 合併一區',
              s.groupPreparation,
              (v) => s.copyWith(groupPreparation: v),
            ),
            toggle(
              '精選商品與商城入口合併一區',
              s.groupStore,
              (v) => s.copyWith(groupStore: v),
            ),
            const Text('章節標題與背景'),
            for (final entry in HomeDiarySetting.sectionLabels.entries)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(entry.value),
                children: [
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('使用日記章節樣式（區塊顯示開關在原模組設定）'),
                    value: s.timelineSections.contains(entry.key),
                    onChanged: (value) => change(
                      s.copyWith(
                        timelineSections: [
                          ...s.timelineSections.where((id) => id != entry.key),
                          if (value == true) entry.key,
                        ],
                      ),
                    ),
                  ),
                  textField(
                    entry.key,
                    '章節標題',
                    (value) => change(
                      s.copyWith(titles: {...s.titles, entry.key: value}),
                    ),
                  ),
                  select(
                    '章節背景',
                    s.surfaces[entry.key] ?? 'plain',
                    {
                      'plain': '透明留白',
                      'paper': 'APP 紙張',
                      'cream': '奶油底',
                      'blue': '天空藍底',
                    },
                    (v) => change(
                      s.copyWith(surfaces: {...s.surfaces, entry.key: v}),
                    ),
                  ),
                ],
              ),
            const Text('章節順序使用首頁原有的區塊排序；圖片、內文、價格及開關仍從各模組設定。修改後請儲存外觀設定。'),
          ],
        ],
      ),
    ),
  );
}
