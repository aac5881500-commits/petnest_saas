import 'package:flutter/material.dart';
import '../../../core/models/home_appearance_preset.dart';
import '../../../core/models/home_desktop_layout_setting.dart';
import '../../../core/models/home_room_section_setting.dart';
import '../../../core/models/home_environment_section_setting.dart';
import '../../../core/models/home_about_section_setting.dart';
import '../../../core/models/home_news_section_setting.dart';
import '../../../core/models/home_information_sections_setting.dart';
import '../../../core/models/modern_store_home_setting.dart';
import '../navigation/frontend_navigation_models.dart';
import '../widgets/modern_home/frontend_navigation_panel.dart';
import '../widgets/modern_home/home_color_settings_panel.dart';
import '../widgets/modern_home/home_diary_settings_panel.dart';
import '../widgets/store/store_banner_color_field.dart';

class HomePresetSettingsResult {
  const HomePresetSettingsResult(this.draft, {this.openSection});
  final HomeAppearanceDraft draft;
  final String? openSection;
}

/// One isolated working draft per opened style. Nothing writes to the shop here.
class HomePresetSettingsPage extends StatefulWidget {
  const HomePresetSettingsPage({
    super.key,
    required this.preset,
    required this.initialDraft,
    required this.navigationState,
    required this.previewBuilder,
  });
  final HomeAppearancePreset preset;
  final HomeAppearanceDraft initialDraft;
  final FrontendNavShopState navigationState;
  final Widget Function(HomeAppearanceDraft draft) previewBuilder;
  @override
  State<HomePresetSettingsPage> createState() => _HomePresetSettingsPageState();
}

class _HomePresetSettingsPageState extends State<HomePresetSettingsPage> {
  late HomeAppearanceDraft _draft = widget.initialDraft;
  bool _changed = false;
  int _pane = 1;
  void update(HomeAppearanceDraft value) => setState(() {
    _draft = value;
    _changed = true;
  });
  Future<void> back() async {
    if (_changed) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('放棄這個風格的調整？'),
          content: const Text('尚未套用的調整會取消，目前首頁草稿維持原樣。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('繼續編輯'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('放棄調整'),
            ),
          ],
        ),
      );
      if (discard != true || !mounted) return;
    }
    if (mounted) Navigator.pop(context);
  }

  void apply({String? section}) => Navigator.pop(
    context,
    HomePresetSettingsResult(_draft, openSection: section),
  );

  Widget choice(
    String id,
    String title,
    String value,
    Map<String, String> choices,
    ValueChanged<String> onChanged,
  ) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: DropdownButtonFormField<String>(
      key: ValueKey('$id-$value'),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: title),
      items: [
        for (final e in choices.entries)
          DropdownMenuItem(value: e.key, child: Text(e.value)),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    ),
  );
  Widget group(String title, List<Widget> children, {bool open = false}) =>
      Card(
        child: ExpansionTile(
          title: Text(title),
          initiallyExpanded: open,
          maintainState: true,
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: children,
        ),
      );
  Widget sourceLink(String section, String label) => OutlinedButton.icon(
    onPressed: () => apply(section: section),
    icon: const Icon(Icons.edit_outlined),
    label: Text('$label（套用草稿後前往）'),
  );

  Widget settings() => SingleChildScrollView(
    key: const PageStorageKey('preset-settings-scroll'),
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${widget.preset.name}・專屬設定',
          key: ValueKey('style-settings-${widget.preset.id}'),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        const Text('照片與內容沿用店家資料。此頁只編輯這個風格，套用後回首頁草稿，再按「儲存外觀設定」才會發佈。'),
        const SizedBox(height: 12),
        if (widget.preset.id == 'catDiary')
          HomeDiarySettingsPanel(
            setting: _draft.theme.storybook.diary,
            onChanged: (value) => update(
              _draft.copyWith(
                theme: _draft.theme.copyWith(
                  storybook: _draft.theme.storybook.copyWith(
                    enabled: true,
                    diary: value,
                  ),
                ),
              ),
            ),
            onOpenPhotos: () => apply(section: 'banners'),
            onOpenEnvironment: () => apply(section: 'facilities'),
          ),
        if (widget.preset.id == 'catDiary')
          group('日常誌卡片色彩與間距', [
            StoreBannerColorField(
              label: '奶油紙張底色',
              argb: _draft.theme.storybook.paperColor,
              onChanged: (v) => update(
                _draft.copyWith(
                  theme: _draft.theme.copyWith(
                    storybook: _draft.theme.storybook.copyWith(paperColor: v),
                  ),
                ),
              ),
            ),
            StoreBannerColorField(
              label: '天空藍底色',
              argb: _draft.theme.storybook.blueColor,
              onChanged: (v) => update(
                _draft.copyWith(
                  theme: _draft.theme.copyWith(
                    storybook: _draft.theme.storybook.copyWith(blueColor: v),
                  ),
                ),
              ),
            ),
            for (final entry in {
              '卡片圓角': _draft.theme.storybook.radius,
              '卡片內距': _draft.theme.storybook.padding,
              '區塊間距': _draft.theme.storybook.gap,
            }.entries)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${entry.key} ${entry.value.round()}'),
                  Slider(
                    value: entry.value,
                    min: entry.key == '區塊間距' ? 4 : 0,
                    max: entry.key == '卡片圓角'
                        ? 40
                        : entry.key == '卡片內距'
                        ? 24
                        : 32,
                    onChanged: (v) {
                      final old = _draft.theme.storybook;
                      update(
                        _draft.copyWith(
                          theme: _draft.theme.copyWith(
                            storybook: entry.key == '卡片圓角'
                                ? old.copyWith(radius: v)
                                : entry.key == '卡片內距'
                                ? old.copyWith(padding: v)
                                : old.copyWith(gap: v),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
          ]),
        if (widget.preset.id == 'creamOrange')
          group('奶油暖橘・版面重點', [
            const Text(
              '保留暖橘品牌抬頭、店家大圖、環境特色、房型與消息商城配置。可在下方分別微調配色及每個區塊，不混入日常誌設定。',
            ),
            sourceLink('banners', '管理店家封面與海報'),
            sourceLink('brand', '調整品牌抬頭'),
          ], open: true),
        group('這個風格的配色', [
          HomeColorSettingsPanel(
            theme: _draft.theme,
            entryTheme: widget.initialDraft.theme,
            onChanged: (theme) => update(_draft.copyWith(theme: theme)),
          ),
        ]),
        group('這個風格的區塊排版', [
          choice(
            'rooms',
            '房型排列',
            _draft.rooms.layout,
            {
              for (final v in HomeRoomSectionLayouts.all)
                v: HomeRoomSectionLayouts.label(v),
            },
            (v) => update(
              _draft.copyWith(rooms: _draft.rooms.copyWith(layout: v)),
            ),
          ),
          choice(
            'facilities',
            '環境排列',
            _draft.environment.layout,
            {
              for (final v in HomeEnvironmentLayouts.all)
                v: HomeEnvironmentLayouts.label(v),
            },
            (v) => update(
              _draft.copyWith(
                environment: _draft.environment.copyWith(layout: v),
              ),
            ),
          ),
          choice(
            'about',
            '關於我們排列',
            _draft.about.layout,
            {
              for (final v in HomeAboutLayouts.all)
                v: HomeAboutLayouts.label(v),
            },
            (v) => update(
              _draft.copyWith(about: _draft.about.copyWith(layout: v)),
            ),
          ),
          choice(
            'announcements',
            '消息排列',
            _draft.news.layout,
            {for (final v in HomeNewsLayouts.all) v: HomeNewsLayouts.label(v)},
            (v) =>
                update(_draft.copyWith(news: _draft.news.copyWith(layout: v))),
          ),
          choice(
            'policy',
            '入住須知排列',
            _draft.information.policy.layout,
            {
              for (final v in HomePolicyLayouts.all)
                v: HomePolicyLayouts.label(v),
            },
            (v) => update(
              _draft.copyWith(
                information: _draft.information.copyWith(
                  policy: _draft.information.policy.copyWith(layout: v),
                ),
              ),
            ),
          ),
          choice(
            'faq',
            '常見問題排列',
            _draft.information.faq.layout,
            {for (final v in HomeFaqLayouts.all) v: HomeFaqLayouts.label(v)},
            (v) => update(
              _draft.copyWith(
                information: _draft.information.copyWith(
                  faq: _draft.information.faq.copyWith(layout: v),
                ),
              ),
            ),
          ),
          choice(
            'reviews',
            '評價排列',
            _draft.information.reviews.layout,
            {
              for (final v in HomeReviewLayouts.all)
                v: HomeReviewLayouts.label(v),
            },
            (v) => update(
              _draft.copyWith(
                information: _draft.information.copyWith(
                  reviews: _draft.information.reviews.copyWith(layout: v),
                ),
              ),
            ),
          ),
          choice(
            'featured',
            '商品排列',
            _draft.featuredProductLayout,
            {
              for (final v in ModernFeaturedProductLayouts.all)
                v: ModernFeaturedProductLayouts.label(v),
            },
            (v) => update(_draft.copyWith(featuredProductLayout: v)),
          ),
        ]),
        group('這個風格的區塊順序', [
          const Text('拖動右側把手調整順序；登入、入住與已發布內容仍決定客戶實際看見的區塊。'),
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: _draft.sectionOrder.length,
            onReorder: (oldIndex, newIndex) {
              final order = [..._draft.sectionOrder];
              if (newIndex > oldIndex) newIndex--;
              final item = order.removeAt(oldIndex);
              order.insert(newIndex, item);
              update(_draft.copyWith(sectionOrder: order));
            },
            itemBuilder: (context, i) {
              final id = _draft.sectionOrder[i];
              return ListTile(
                key: ValueKey('order-$id'),
                title: Text(
                  (const {
                        'banners': '店家海報',
                        'dailyCare': '入住回報',
                        'sharedEntries': '首頁小卡',
                        'quickBooking': '快速預約',
                        'facilities': '環境介紹',
                        'announcements': '消息展示',
                        'rooms': '房型介紹',
                        'featured': '精選商品',
                        'storeEntrance': '商城入口',
                        'about': '關於我們',
                        'services': '照護服務',
                        'policy': '入住須知',
                        'faq': '常見問題',
                        'reviews': '顧客評價',
                      }[id] ??
                      '首頁區塊'),
                ),
                trailing: ReorderableDragStartListener(
                  index: i,
                  child: const Icon(Icons.drag_handle),
                ),
              );
            },
          ),
        ]),
        group('這個風格的導覽', [
          FrontendNavigationPanel(
            config: _draft.navigation,
            shopState: widget.navigationState,
            onChanged: (value) => update(_draft.copyWith(navigation: value)),
          ),
        ]),
        group('這個風格的電腦版配置', [
          choice(
            'desktop',
            '電腦版排版',
            _draft.desktopLayout.preset,
            HomeDesktopLayoutSetting.labels,
            (v) => update(
              _draft.copyWith(
                desktopLayout: HomeDesktopLayoutSetting(preset: v),
              ),
            ),
          ),
        ]),
        group('店家內容與進階設定', [
          const Text('進入原區塊管理前，先將這頁調整帶回首頁草稿。圖片與文案不會因切換風格被替換。'),
          for (final e in const {
            'banners': '店家海報',
            'facilities': '環境照片',
            'rooms': '房型照片與價格',
            'announcements': '公告與活動',
            'about': '關於我們',
            'storeEntrance': '商城入口與商品',
            'policy': '入住須知',
            'faq': '常見問題',
            'reviews': '顧客分享',
            'shopInfo': '店家資訊',
          }.entries)
            sourceLink(e.key, e.value),
        ]),
      ],
    ),
  );

  Widget preview() => Padding(
    padding: const EdgeInsets.all(12),
    child: widget.previewBuilder(_draft),
  );
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_changed,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) back();
    },
    child: Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: back),
        title: Text(
          '${widget.preset.name}設定',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: LayoutBuilder(
        builder: (context, c) => c.maxWidth >= 1000
            ? Row(
                children: [
                  SizedBox(width: 420, child: preview()),
                  const VerticalDivider(width: 1),
                  Expanded(child: settings()),
                ],
              )
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(
                          value: 0,
                          label: Text('預覽'),
                          icon: Icon(Icons.smartphone),
                        ),
                        ButtonSegment(
                          value: 1,
                          label: Text('此風格設定'),
                          icon: Icon(Icons.tune),
                        ),
                      ],
                      selected: {_pane},
                      onSelectionChanged: (v) =>
                          setState(() => _pane = v.first),
                    ),
                  ),
                  Expanded(
                    child: IndexedStack(
                      index: _pane,
                      children: [preview(), settings()],
                    ),
                  ),
                ],
              ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton(onPressed: back, child: const Text('返回風格清單')),
              FilledButton.icon(
                key: const Key('apply-style-settings'),
                onPressed: () => apply(),
                icon: const Icon(Icons.check),
                label: const Text('套用到首頁草稿'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
