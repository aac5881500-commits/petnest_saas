// 檔案名稱：lib/features/shop/pages/shop_media_page.dart
// 功能說明：店家活動海報管理：清單 + 共用 ShopStoreBannerEditorPage。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/store_banner_model.dart';
import 'package:petnest_saas/core/services/home_banner_service.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/features/shop/pages/store/shop_store_banner_editor_page.dart';
import 'package:petnest_saas/features/shop/widgets/media/shop_banner_device_preview.dart';
import 'package:petnest_saas/features/shop/widgets/store/store_banner_view.dart';

class ShopMediaPage extends StatefulWidget {
  const ShopMediaPage({super.key, required this.shopId});

  final String shopId;

  @override
  State<ShopMediaPage> createState() => _ShopMediaPageState();
}

class _ShopMediaPageState extends State<ShopMediaPage> {
  bool _loaded = false;
  bool _busy = false;
  List<StoreBannerModel> _banners = <StoreBannerModel>[];
  HomeThemeModel _theme = HomeThemeModel.modernDefault;
  BannerPreviewSize _previewSize = BannerPreviewSize.phone;
  int _selectedIndex = 0;
  StoreBannerModel? _draft;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _loadBanners();
  }

  Future<void> _loadBanners() async {
    final Map<String, dynamic>? shop = await ShopService.instance.getShop(
      widget.shopId,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _banners = HomeBannerService.instance.parseBanners(shop?['banners']);
      _theme = HomeBannerService.instance.themeFromShop(shop);
      _loaded = true;
      _selectedIndex = 0;
      _draft = _banners.isEmpty ? null : _banners.first;
      _dirty = false;
    });
  }

  Future<void> _persist(List<StoreBannerModel> banners) async {
    await HomeBannerService.instance.saveBanners(
      shopId: widget.shopId,
      banners: banners,
    );
  }

  Future<void> _openEditor(
    StoreBannerModel banner, {
    required bool isNew,
  }) async {
    final List<StoreBannerModel>? saved =
        await Navigator.push<List<StoreBannerModel>>(
          context,
          MaterialPageRoute<List<StoreBannerModel>>(
            builder: (_) => PetNestBannerEditorPage(
              shopId: widget.shopId,
              banner: banner,
              existingBanners: List<StoreBannerModel>.from(_banners),
              isNew: isNew,
              shopTheme: _theme,
              scope: PetNestBannerScope.home,
              persistBanners: _persist,
              imageFolder: HomeBannerService.imageFolder,
              imageType: 'home_banner',
              pageTitle: '編輯首頁海報',
            ),
          ),
        );
    if (saved == null || !mounted) {
      return;
    }
    setState(() => _banners = saved);
    if (_banners.isNotEmpty) {
      _selectedIndex = _selectedIndex.clamp(0, _banners.length - 1);
      _draft = _banners[_selectedIndex];
      _dirty = false;
    }
  }

  Future<void> _addBanner() async {
    if (_banners.length >= HomeBannerService.maxCount) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('最多只能5張海報')));
      return;
    }
    final StoreBannerModel created = StoreBannerModel(
      id: 'home_${DateTime.now().millisecondsSinceEpoch}',
      enabled: true,
      sortOrder: _banners.length,
      sizePreset: StoreBannerSizePresets.standard,
      contentMode: StoreBannerContentModes.imageOnly,
      createdAt: DateTime.now(),
    );
    await _openEditor(created, isNew: true);
  }

  Future<void> _toggleEnabled(int index) async {
    if (_busy) {
      return;
    }
    final StoreBannerModel banner = _banners[index];
    final List<StoreBannerModel> next = List<StoreBannerModel>.from(_banners);
    next[index] = banner.copyWith(enabled: !banner.enabled);
    setState(() {
      _busy = true;
      _banners = next;
    });
    try {
      await _persist(next);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _banners[index] = banner);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('更新失敗：$error')));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _deleteBanner(int index) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('刪除海報'),
          content: const Text('確定刪除此活動海報？'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('刪除'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }
    final StoreBannerModel banner = _banners[index];
    final List<StoreBannerModel> next = List<StoreBannerModel>.from(_banners)
      ..removeAt(index);
    setState(() => _busy = true);
    try {
      await _persist(next);
      await HomeBannerService.instance.deleteBannerImage(
        shopId: widget.shopId,
        imageUrl: banner.imageUrl,
        imageStoragePath: banner.imageStoragePath,
      );
      if (!mounted) {
        return;
      }
      setState(() => _banners = next);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('刪除失敗，海報與圖片都未更動：$error')));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (_busy) {
      return;
    }
    setState(() {
      if (newIndex > oldIndex) {
        newIndex--;
      }
      final StoreBannerModel item = _banners.removeAt(oldIndex);
      _banners.insert(newIndex, item);
      for (int i = 0; i < _banners.length; i++) {
        _banners[i] = _banners[i].copyWith(sortOrder: i);
      }
    });
    try {
      await _persist(_banners);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('排序儲存失敗：$error')));
    }
  }

  Widget _buildHintCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '海報說明',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 8),
          Text('建議圖片比例：16:9'),
          Text('建議尺寸：1600 × 900 px'),
          Text('最低建議：1280 × 720 px'),
          SizedBox(height: 8),
          Text('首頁所有海報的顯示大小請到「前台外觀設定」統一調整。', style: TextStyle(height: 1.4)),
          SizedBox(height: 8),
          Text(
            '點「編輯」可調整圖片焦點、漸層、文字與按鈕。效果只在前台即時繪製，不會改動原始圖片。',
            style: TextStyle(height: 1.4),
          ),
          SizedBox(height: 4),
          Text('單張圖片最大 5 MB，支援 JPG / PNG / WEBP'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F4F0),
      appBar: AppBar(title: const Text('活動海報管理')),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                if (constraints.maxWidth >= 1100) {
                  return _desktopStudio();
                }
                if (constraints.maxWidth >= 760) {
                  return _tabletStudio();
                }
                return _phoneList();
              },
            ),
    );
  }

  Widget _phoneList() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        _buildHintCard(),
        const SizedBox(height: 16),
        ReorderableListView(
          buildDefaultDragHandles: false,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          onReorder: _onReorder,
          children: _bannerCards(),
        ),
        ElevatedButton(
          onPressed: _busy ? null : _addBanner,
          child: const Text('新增海報'),
        ),
      ],
    );
  }

  List<Widget> _bannerCards() {
    return List<Widget>.generate(_banners.length, (int index) {
      final StoreBannerModel banner = _banners[index];
      return Card(
        key: ValueKey<String>(banner.id),
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: <Widget>[
              Align(
                alignment: Alignment.centerRight,
                child: ReorderableDragStartListener(
                  index: index,
                  child: const Icon(Icons.drag_handle, color: Colors.grey),
                ),
              ),
              AspectRatio(
                aspectRatio: StoreBannerSafeLayout.aspectRatio,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: banner.hasImage
                      ? StoreBannerView(
                          banner: banner,
                          theme: _theme,
                          scope: PetNestBannerScope.home,
                          borderRadius: 16,
                        )
                      : const ColoredBox(
                          color: Colors.black12,
                          child: Center(
                            child: Text(
                              '尚未上傳圖片',
                              style: TextStyle(color: Colors.black54),
                            ),
                          ),
                        ),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('啟用'),
                value: banner.enabled,
                onChanged: _busy ? null : (_) => _toggleEnabled(index),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  TextButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _openEditor(banner, isNew: false),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('編輯'),
                  ),
                  TextButton(
                    onPressed: _busy ? null : () => _deleteBanner(index),
                    child: const Text('刪除'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _previewSizeChips() {
    return Wrap(
      spacing: 8,
      children: BannerPreviewSize.values.map((BannerPreviewSize size) {
        final bool selected = _previewSize == size;
        final String label = switch (size) {
          BannerPreviewSize.phone => '手機',
          BannerPreviewSize.tablet => '平板',
          BannerPreviewSize.desktop => '電腦',
        };
        return ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => setState(() => _previewSize = size),
        );
      }).toList(),
    );
  }

  Widget _livePreview() {
    final StoreBannerModel? banner =
        _draft ??
        (_banners.isEmpty
            ? null
            : _banners[_selectedIndex.clamp(0, _banners.length - 1)]);
    if (banner == null) {
      return const Center(child: Text('尚未新增海報'));
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: ShopBannerDevicePreview(
        banner: banner,
        theme: _theme,
        size: _previewSize,
      ),
    );
  }

  Widget _selectBanner(int index) {
    return ListTile(
      selected: index == _selectedIndex,
      title: Text(
        _banners[index].listTitle.isEmpty
            ? '海報 ${index + 1}'
            : _banners[index].listTitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        StoreBannerContentModes.label(_banners[index].resolvedContentMode),
      ),
      onTap: () {
        setState(() {
          _selectedIndex = index;
          _draft = _banners[index];
          _dirty = false;
        });
      },
    );
  }

  Widget _desktopStudio() {
    return Row(
      children: <Widget>[
        Expanded(flex: 42, child: _livePreview()),
        const VerticalDivider(width: 1),
        Expanded(
          flex: 58,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  '活動海報管理',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _previewSizeChips(),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                  children: <Widget>[
                    ...List<Widget>.generate(_banners.length, _selectBanner),
                    const SizedBox(height: 8),
                    _studioSettings(),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _busy ? null : _addBanner,
                        child: const Text('新增海報'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        onPressed: _busy || !_dirty ? null : _saveDraft,
                        child: const Text('儲存變更'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tabletStudio() {
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: _previewSizeChips(),
        ),
        SizedBox(height: 280, child: _livePreview()),
        const Divider(height: 1),
        Expanded(child: _phoneList()),
      ],
    );
  }

  Widget _studioSettings() {
    final StoreBannerModel? draft = _draft;
    if (draft == null) {
      return const SizedBox.shrink();
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text('內容來源模式', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: StoreBannerContentModes.all.map((String mode) {
                return ChoiceChip(
                  label: Text(StoreBannerContentModes.label(mode)),
                  selected: draft.resolvedContentMode == mode,
                  onSelected: (_) {
                    _patchDraft(
                      draft.copyWith(
                        contentMode: mode,
                        overlayMode:
                            mode == StoreBannerContentModes.templateOverlay
                            ? StoreBannerAlignX.overlayModeFor(
                                draft.resolvedTextAlignH,
                              )
                            : StoreBannerOverlayModes.none,
                      ),
                    );
                  },
                );
              }).toList(),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('啟用'),
              value: draft.enabled,
              onChanged: (bool value) =>
                  _patchDraft(draft.copyWith(enabled: value)),
            ),
            if (draft.resolvedContentMode ==
                StoreBannerContentModes.templateOverlay) ...<Widget>[
              TextFormField(
                key: ValueKey<String>('title_${draft.id}'),
                initialValue: draft.title,
                maxLength: StoreBannerSafeLayout.titleMaxChars,
                decoration: const InputDecoration(
                  labelText: '標題',
                  helperText: '最多 2 行',
                ),
                onChanged: (String value) =>
                    _patchDraft(draft.copyWith(title: value)),
              ),
              TextFormField(
                key: ValueKey<String>('sub_${draft.id}'),
                initialValue: draft.subtitle,
                maxLength: StoreBannerSafeLayout.subtitleMaxChars,
                decoration: const InputDecoration(
                  labelText: '副標題',
                  helperText: '最多 2 行',
                ),
                onChanged: (String value) =>
                    _patchDraft(draft.copyWith(subtitle: value)),
              ),
              TextFormField(
                key: ValueKey<String>('cta_${draft.id}'),
                initialValue: draft.ctaText,
                maxLength: StoreBannerSafeLayout.ctaMaxChars,
                decoration: const InputDecoration(labelText: '按鈕文字'),
                onChanged: (String value) => _patchDraft(
                  draft.copyWith(
                    ctaText: value,
                    ctaEnabled: value.trim().isNotEmpty,
                  ),
                ),
              ),
              const Text('文字水平位置'),
              Wrap(
                spacing: 8,
                children: StoreBannerAlignX.all.map((String value) {
                  return ChoiceChip(
                    label: Text(StoreBannerAlignX.label(value)),
                    selected: draft.resolvedTextAlignH == value,
                    onSelected: (_) => _patchDraft(
                      draft.copyWith(
                        textAlignH: value,
                        overlayMode: StoreBannerAlignX.overlayModeFor(value),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              const Text('文字垂直位置'),
              Wrap(
                spacing: 8,
                children: StoreBannerAlignY.all.map((String value) {
                  return ChoiceChip(
                    label: Text(StoreBannerAlignY.label(value)),
                    selected: draft.resolvedTextAlignV == value,
                    onSelected: (_) =>
                        _patchDraft(draft.copyWith(textAlignV: value)),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              const Text('字體大小'),
              Wrap(
                spacing: 8,
                children: StoreBannerFontScale.all.map((String value) {
                  return ChoiceChip(
                    label: Text(StoreBannerFontScale.label(value)),
                    selected: draft.resolvedFontScale == value,
                    onSelected: (_) =>
                        _patchDraft(draft.copyWith(fontScale: value)),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _openEditor(draft, isNew: false),
              icon: const Icon(Icons.image_outlined),
              label: const Text('上傳／更換圖片'),
            ),
            Row(
              children: <Widget>[
                TextButton(
                  onPressed: _busy ? null : () => _deleteBanner(_selectedIndex),
                  child: const Text('刪除'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _patchDraft(StoreBannerModel next) {
    setState(() {
      _draft = next;
      _dirty = true;
    });
  }

  Future<void> _saveDraft() async {
    final StoreBannerModel? draft = _draft;
    if (draft == null ||
        _selectedIndex < 0 ||
        _selectedIndex >= _banners.length) {
      return;
    }
    final List<StoreBannerModel> next = List<StoreBannerModel>.from(_banners);
    next[_selectedIndex] = draft.copyWith(updatedAt: DateTime.now());
    setState(() => _busy = true);
    try {
      await _persist(next);
      if (!mounted) {
        return;
      }
      setState(() {
        _banners = next;
        _dirty = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('儲存失敗：$error')));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }
}
