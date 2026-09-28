// 檔案名稱：lib/features/shop/pages/shop_media_page.dart
// 功能說明：首頁活動海報管理。手機先看清單，桌機左側預覽完整新版首頁。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_banner_display.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/store_banner_model.dart';
import 'package:petnest_saas/core/services/home_banner_service.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/features/shop/pages/store/shop_store_banner_editor_page.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/modern_home_editor_preview.dart';
import 'package:petnest_saas/features/shop/widgets/store/store_banner_view.dart';

class ShopMediaPage extends StatefulWidget {
  const ShopMediaPage({super.key, required this.shopId});

  final String shopId;

  @override
  State<ShopMediaPage> createState() => _ShopMediaPageState();
}

enum _HomePreviewWidth { phone, tablet, desktop }

class _ShopMediaPageState extends State<ShopMediaPage> {
  bool _loaded = false;
  bool _busy = false;
  List<StoreBannerModel> _banners = <StoreBannerModel>[];
  HomeThemeModel _theme = HomeThemeModel.modernDefault;
  String? _editingId;
  _HomePreviewWidth _previewWidth = _HomePreviewWidth.phone;
  final StoreBannerEditorController _editor = StoreBannerEditorController();
  final HomeBannerImageCleanup _removedImages = HomeBannerImageCleanup();

  StoreBannerModel? get _editing {
    final String? id = _editingId;
    if (id == null) {
      return null;
    }
    for (final StoreBannerModel banner in _banners) {
      if (banner.id == id) {
        return banner;
      }
    }
    return null;
  }

  List<StoreBannerModel> get _previewBanners {
    final StoreBannerModel? selected = _editing;
    return _banners
        .where(
          (StoreBannerModel banner) =>
              banner.enabled || banner.id == selected?.id,
        )
        .toList();
  }

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
    });
  }

  Future<void> _persist(List<StoreBannerModel> banners) {
    return HomeBannerService.instance.saveBanners(
      shopId: widget.shopId,
      banners: banners,
    );
  }

  void _toast(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _addBanner() async {
    if (_banners.length >= HomeBannerService.maxCount) {
      _toast('最多只能 5 張海報');
      return;
    }
    final StoreBannerModel created = StoreBannerModel(
      id: 'home_${DateTime.now().millisecondsSinceEpoch}',
      enabled: true,
      sortOrder: _banners.length,
      actionType: HomeBannerActionTypes.none,
      createdAt: DateTime.now(),
    );
    setState(() {
      _banners = <StoreBannerModel>[..._banners, created];
      _editingId = created.id;
    });
  }

  void _onDraft(StoreBannerModel draft) {
    final int index = _banners.indexWhere(
      (StoreBannerModel banner) => banner.id == draft.id,
    );
    if (index < 0 || !mounted) {
      return;
    }
    setState(() => _banners[index] = draft);
  }

  Future<void> _publish() async {
    setState(() => _busy = true);
    try {
      await _editor.publish();
      if (!mounted) {
        return;
      }
      _toast('海報已發布');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _previewDraft() async {
    final StoreBannerModel? banner = _editor.draft ?? _editing;
    if (banner == null) {
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const Text(
                  '預覽海報',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                const Text(
                  '這是目前草稿。顧客前台要等發布後才會看到這張成品。',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 12),
                AspectRatio(
                  aspectRatio: HomeBannerDisplay.aspectRatio,
                  child: StoreBannerView(
                    banner: banner,
                    theme: _theme,
                    scope: PetNestBannerScope.home,
                    composeLive: true,
                    borderRadius: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _deleteEditing() async {
    final StoreBannerModel? banner = _editing;
    if (banner == null) {
      return;
    }
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
    final List<HomeBannerStoredImage> images = _editor.detachStoredImages();
    for (final HomeBannerStoredImage image in images) {
      _removedImages.retireSaved(image);
    }
    final List<StoreBannerModel> next = _banners
        .where((StoreBannerModel item) => item.id != banner.id)
        .toList();
    setState(() {
      _banners = next;
      _editingId = null;
    });
    try {
      await _persist(next);
      final List<HomeBannerStoredImage> doomed = _removedImages.commitSave();
      for (final HomeBannerStoredImage image in doomed) {
        await HomeBannerService.instance.deleteBannerImage(
          shopId: widget.shopId,
          imageUrl: image.url,
          imageStoragePath: image.path,
        );
      }
    } catch (error) {
      _removedImages.retireAfterSave.clear();
      _toast('刪除失敗，已發布圖片未刪除：$error');
      await _loadBanners();
    }
  }

  void _onReorder(int oldIndex, int newIndex) {
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
    _persist(_banners);
  }

  Future<void> _toggle(StoreBannerModel banner, bool enabled) async {
    final int index = _banners.indexWhere(
      (StoreBannerModel item) => item.id == banner.id,
    );
    if (index < 0) {
      return;
    }
    setState(() {
      _banners[index] = banner.copyWith(enabled: enabled);
    });
    if (banner.hasImage || banner.hasPublishedPoster) {
      await _persist(_banners);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F4F0),
      appBar: AppBar(
        title: const Text('活動海報管理'),
        leading: _editingId != null && MediaQuery.sizeOf(context).width < 1100
            ? BackButton(onPressed: () => setState(() => _editingId = null))
            : null,
        actions: <Widget>[
          if (_editingId != null)
            TextButton(
              onPressed: _busy ? null : _deleteEditing,
              child: const Text('刪除'),
            ),
        ],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                if (constraints.maxWidth >= 1100) {
                  return _desktop();
                }
                return _phone();
              },
            ),
    );
  }

  Widget _desktop() {
    return Row(
      children: <Widget>[
        Expanded(flex: 42, child: _homepagePreview()),
        const VerticalDivider(width: 1),
        Expanded(
          flex: 58,
          child: Column(
            children: <Widget>[
              SizedBox(height: 220, child: _bannerList(dense: true)),
              const Divider(height: 1),
              Expanded(child: _editorOrHint()),
              _publishBar(includePreview: false),
            ],
          ),
        ),
      ],
    );
  }

  Widget _phone() {
    if (_editingId == null) {
      return _bannerList(dense: false);
    }
    return Column(
      children: <Widget>[
        Expanded(child: _editorOrHint()),
        _publishBar(includePreview: true),
      ],
    );
  }

  Widget _homepagePreview() {
    final double frameWidth = switch (_previewWidth) {
      _HomePreviewWidth.phone => 390,
      _HomePreviewWidth.tablet => 768,
      _HomePreviewWidth.desktop => 1200,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Wrap(
            spacing: 8,
            children: <Widget>[
              ChoiceChip(
                label: const Text('手機'),
                selected: _previewWidth == _HomePreviewWidth.phone,
                onSelected: (_) =>
                    setState(() => _previewWidth = _HomePreviewWidth.phone),
              ),
              ChoiceChip(
                label: const Text('平板'),
                selected: _previewWidth == _HomePreviewWidth.tablet,
                onSelected: (_) =>
                    setState(() => _previewWidth = _HomePreviewWidth.tablet),
              ),
              ChoiceChip(
                label: const Text('電腦'),
                selected: _previewWidth == _HomePreviewWidth.desktop,
                onSelected: (_) =>
                    setState(() => _previewWidth = _HomePreviewWidth.desktop),
              ),
            ],
          ),
        ),
        Expanded(
          child: ModernHomeEditorPreview(
            shopId: widget.shopId,
            showPhoneChrome: false,
            frameWidth: frameWidth,
            draftHomeBanners: _previewBanners,
            initialPreviewBannerId: _editingId,
          ),
        ),
      ],
    );
  }

  Widget _bannerList({required bool dense}) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      children: <Widget>[
        if (_banners.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('尚未新增海報'),
          )
        else
          ReorderableListView(
            buildDefaultDragHandles: false,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            onReorder: _onReorder,
            children: List<Widget>.generate(_banners.length, (int index) {
              final StoreBannerModel banner = _banners[index];
              final String title = banner.listTitle.trim().isEmpty
                  ? '海報 ${index + 1}'
                  : banner.listTitle.trim();
              return ListTile(
                key: ValueKey<String>(banner.id),
                dense: dense,
                selected: banner.id == _editingId,
                leading: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    ReorderableDragStartListener(
                      index: index,
                      child: const Icon(Icons.drag_handle),
                    ),
                    const SizedBox(width: 8),
                    _thumb(banner),
                  ],
                ),
                title: Text(title),
                subtitle: Text(banner.enabled ? '啟用' : '停用'),
                trailing: Switch(
                  value: banner.enabled,
                  onChanged: (bool value) => _toggle(banner, value),
                ),
                onTap: () => setState(() => _editingId = banner.id),
              );
            }),
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _busy ? null : _addBanner,
          icon: const Icon(Icons.add),
          label: const Text('新增海報'),
        ),
        if (_editingId != null) ...<Widget>[
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _busy ? null : _deleteEditing,
              child: const Text('刪除海報'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _thumb(StoreBannerModel banner) {
    final String url = banner.frontImageUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: 56,
        height: 32,
        child: ColoredBox(
          color: const Color(0xFFE7E1DA),
          child: url.isEmpty
              ? const Icon(Icons.image_outlined, size: 16)
              : Image.network(url, fit: BoxFit.cover),
        ),
      ),
    );
  }

  Widget _editorOrHint() {
    final StoreBannerModel? banner = _editing;
    if (banner == null) {
      return const Center(child: Text('請選擇一張海報'));
    }
    return ShopStoreBannerEditorPage(
      key: ValueKey<String>('home-editor-${banner.id}'),
      shopId: widget.shopId,
      banner: banner,
      existingBanners: _banners,
      isNew: !banner.hasPublishedPoster && !banner.hasImage,
      shopTheme: _theme,
      scope: PetNestBannerScope.home,
      embedded: true,
      showInlinePreview: false,
      controller: _editor,
      persistBanners: _persist,
      onDraftChanged: _onDraft,
      onPublished: (List<StoreBannerModel> banners) {
        if (!mounted) {
          return;
        }
        setState(() => _banners = banners);
      },
    );
  }

  Widget _publishBar({required bool includePreview}) {
    if (_editingId == null) {
      return const SizedBox.shrink();
    }
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: <Widget>[
            if (includePreview) ...<Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : _previewDraft,
                  child: const Text('預覽海報'),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: FilledButton(
                onPressed: _busy ? null : _publish,
                child: Text(_busy ? '發布中…' : '發布海報'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
