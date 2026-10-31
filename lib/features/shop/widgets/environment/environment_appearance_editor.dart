// 檔案：lib/features/shop/widgets/environment/environment_appearance_editor.dart
// 功能：整頁外觀草稿設定，重用 HSV 選色器與平台圖庫確認選圖。
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/environment_page_appearance.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/platform_media_asset.dart';
import 'package:petnest_saas/core/services/platform_media_library_service.dart';
import '../platform_media_asset_picker.dart';
import '../store/store_banner_color_field.dart';

class EnvironmentAppearanceEditor extends StatefulWidget {
  const EnvironmentAppearanceEditor({
    super.key,
    required this.appearance,
    required this.theme,
    required this.onChanged,
    required this.fontSizeControl,
    required this.busy,
  });
  final EnvironmentPageAppearance appearance;
  final HomeThemeModel theme;
  final ValueChanged<EnvironmentPageAppearance> onChanged;
  final Widget fontSizeControl;
  final bool busy;
  @override
  State<EnvironmentAppearanceEditor> createState() =>
      _EnvironmentAppearanceEditorState();
}

class _EnvironmentAppearanceEditorState
    extends State<EnvironmentAppearanceEditor> {
  String _category = PlatformMediaCategories.appBackground;
  String _id = '';
  Future<PlatformMediaAsset?>? _thumbnail;
  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  @override
  void didUpdateWidget(covariant EnvironmentAppearanceEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadThumbnail();
  }

  void _loadThumbnail() {
    final id = widget.appearance.backgroundAssetId;
    if (id == _id) return;
    _id = id;
    _thumbnail = id.isEmpty
        ? null
        : PlatformMediaLibraryService.instance.getEnabledAssetById(id);
  }

  void _change(Map<String, dynamic> changes) =>
      widget.onChanged(widget.appearance.copyWith(changes));
  Future<void> _pick() async {
    final result = await showModalBottomSheet<PlatformMediaPick>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => PlatformMediaAssetPickerSheet(
        category: _category,
        selectedId: widget.appearance.backgroundAssetId,
        confirmSelection: true,
        title: '選擇環境介紹背景',
      ),
    );
    if (!mounted || result?.asset == null) return;
    final asset = result!.asset!;
    if (!asset.enabled ||
        !const [
          PlatformMediaCategories.appBackground,
          PlatformMediaCategories.dailyCarePage,
        ].contains(asset.category)) {
      return;
    }
    _change({'backgroundMode': 'image', 'backgroundAssetId': asset.id});
  }

  Widget _heading(String title) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 10),
    child: Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final a = widget.appearance;
    final colors = {
      'textColor': ('主要文字色', widget.theme.textColor),
      'secondaryTextColor': ('次要說明文字色', widget.theme.secondaryTextColor),
      'accentColor': ('重點色', widget.theme.primaryColor),
      'backgroundColor': ('頁面背景色', widget.theme.backgroundColor),
      'cardColor': ('卡片底色', widget.theme.cardColor),
    };
    return AbsorbPointer(
      absorbing: widget.busy,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _heading('整頁字體與文字大小'),
          RadioGroup<String>(
            groupValue: a.fontFamily ?? '',
            onChanged: (value) => _change({'fontFamily': value}),
            child: Column(
              children: [
                for (final font in EnvironmentPageAppearance.fonts.entries)
                  RadioListTile<String>(
                    value: font.key,
                    title: Text(font.value),
                    subtitle: Text(
                      '安心住宿，讓貓咪自在探索。',
                      style: TextStyle(
                        fontFamily: font.key.isEmpty ? null : font.key,
                        fontSize: 16,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text('整頁文字大小'),
          ),
          widget.fontSizeControl,
          _heading('整頁配色'),
          const Text(
            '僅影響本頁。對比不足時，文字會自動調整以維持可讀性。',
            style: TextStyle(fontSize: 12),
          ),
          for (final entry in colors.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  SizedBox(width: 130, child: Text(entry.value.$1)),
                  OutlinedButton.icon(
                    icon: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: a.color(entry.key) ?? entry.value.$2,
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    label: Text(
                      a.color(entry.key) == null
                          ? '跟隨店家主題'
                          : '#${a.color(entry.key)!.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
                    ),
                    onPressed: () async {
                      final color = await showHomeColorPicker(
                        context,
                        initial: a.color(entry.key) ?? entry.value.$2,
                      );
                      if (color == null || !mounted) return;
                      _change({
                        entry.key: color,
                        if (entry.key == 'backgroundColor' &&
                            a.backgroundMode != 'image')
                          'backgroundMode': 'solid',
                      });
                    },
                  ),
                  if (a.color(entry.key) != null)
                    TextButton(
                      onPressed: () => _change({entry.key: null}),
                      child: const Text('跟隨店家主題'),
                    ),
                ],
              ),
            ),
          _heading('整頁背景'),
          Wrap(
            spacing: 8,
            children: [
              for (final mode in const {
                'theme': '跟隨店家主題',
                'solid': '純色背景',
                'image': '圖片背景',
              }.entries)
                ChoiceChip(
                  label: Text(mode.value),
                  selected: a.backgroundMode == mode.key,
                  onSelected: (_) => _change({
                    'backgroundMode': mode.key,
                    if (mode.key == 'theme') ...{
                      'backgroundAssetId': null,
                      'backgroundColor': null,
                    },
                  }),
                ),
            ],
          ),
          if (a.backgroundMode == 'image') ...[
            DropdownButton<String>(
              value: _category,
              isExpanded: true,
              items:
                  const [
                        PlatformMediaCategories.appBackground,
                        PlatformMediaCategories.dailyCarePage,
                      ]
                      .map(
                        (category) => DropdownMenuItem(
                          value: category,
                          child: Text(PlatformMediaCategories.label(category)),
                        ),
                      )
                      .toList(),
              onChanged: (value) => setState(() => _category = value!),
            ),
            OutlinedButton.icon(
              onPressed: _pick,
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('從圖庫選擇'),
            ),
            const Text('若圖庫顯示暫無圖片，請由平台管理者在對應分類新增並啟用素材；尚未選圖時會使用背景底色。'),
            if (a.backgroundAssetId.isNotEmpty) ...[
              FutureBuilder<PlatformMediaAsset?>(
                future: _thumbnail,
                builder: (context, snapshot) {
                  final asset = snapshot.data;
                  if (asset == null) {
                    return const Padding(
                      padding: EdgeInsets.all(8),
                      child: Text('背景圖片載入中或暫時無法使用，將回退到底色。'),
                    );
                  }
                  return Column(
                    children: [
                      SizedBox(
                        height: 110,
                        child: Image.network(
                          asset.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, error, stack) =>
                              const Text('圖片無法顯示，將回退到底色'),
                        ),
                      ),
                      Text(asset.name),
                    ],
                  );
                },
              ),
              TextButton(
                onPressed: () => _change({
                  'backgroundAssetId': null,
                  'backgroundMode': 'solid',
                }),
                child: const Text('移除圖片'),
              ),
            ],
            Text('圖片淡化：${((1 - a.imageOpacity) * 100).round()}%'),
            Slider(
              value: 1 - a.imageOpacity,
              onChanged: (v) => _change({'imageOpacity': 1 - v}),
            ),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('淺色遮罩'),
                  selected: !a.darkMask,
                  onSelected: (_) => _change({'maskTone': 'light'}),
                ),
                ChoiceChip(
                  label: const Text('深色遮罩'),
                  selected: a.darkMask,
                  onSelected: (_) => _change({'maskTone': 'dark'}),
                ),
              ],
            ),
            Text('遮罩濃度：${(a.maskOpacity * 100).round()}%'),
            Slider(
              value: a.maskOpacity,
              onChanged: (v) => _change({'maskOpacity': v}),
            ),
          ],
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () => widget.onChanged(a.reset()),
            icon: const Icon(Icons.restart_alt),
            label: const Text('重設本頁外觀'),
          ),
          const Text(
            '只重設本頁字體、配色與背景；不影響範本、文字大小、文案、照片、設備或服務。',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
