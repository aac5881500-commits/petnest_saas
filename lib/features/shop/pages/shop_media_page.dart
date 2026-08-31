// lib/features/shop/pages/shop_media_page.dart
// 店家活動海報管理：清單 + 共用 ShopStoreBannerEditorPage。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/modern_banner_frame_setting.dart';
import 'package:petnest_saas/core/models/store_banner_model.dart';
import 'package:petnest_saas/core/models/store_banner_templates.dart';
import 'package:petnest_saas/core/services/home_banner_service.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/features/shop/pages/store/shop_store_banner_editor_page.dart';
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
  ModernBannerFrameSetting _frame = const ModernBannerFrameSetting();

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
      _frame = ModernBannerFrameSetting.fromShop(shop);
      _loaded = true;
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
  }

  Future<void> _addBanner() async {
    if (_banners.length >= HomeBannerService.maxCount) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('最多只能5張海報')));
      return;
    }
    final StoreBannerModel created = StoreBannerTemplates.apply(
      StoreBannerModel(
        id: 'home_${DateTime.now().millisecondsSinceEpoch}',
        enabled: true,
        sortOrder: _banners.length,
        sizePreset: StoreBannerSizePresets.standard,
        createdAt: DateTime.now(),
      ),
      StoreBannerTemplates.leftCopy,
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
      appBar: AppBar(title: const Text('活動海報管理')),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                _buildHintCard(),
                const SizedBox(height: 16),
                ReorderableListView(
                  buildDefaultDragHandles: false,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  onReorder: _onReorder,
                  children: List<Widget>.generate(_banners.length, (int index) {
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
                                child: const Icon(
                                  Icons.drag_handle,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                            AspectRatio(
                              aspectRatio: _frame.aspectRatio,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: banner.hasImage
                                    ? StoreBannerView(
                                        banner: banner,
                                        theme: _theme,
                                        scope: PetNestBannerScope.home,
                                        borderRadius: 16,
                                      )
                                    : ColoredBox(
                                        color: Colors.black12,
                                        child: Center(
                                          child: Text(
                                            '尚未上傳圖片',
                                            style: TextStyle(
                                              color: Colors.black54,
                                            ),
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('啟用'),
                              value: banner.enabled,
                              onChanged: _busy
                                  ? null
                                  : (_) => _toggleEnabled(index),
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
                                  onPressed: _busy
                                      ? null
                                      : () => _deleteBanner(index),
                                  child: const Text('刪除'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
                ElevatedButton(
                  onPressed: _busy ? null : _addBanner,
                  child: const Text('新增海報'),
                ),
              ],
            ),
    );
  }
}
