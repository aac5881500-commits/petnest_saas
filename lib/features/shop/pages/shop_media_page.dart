// lib/features/shop/pages/shop_media_page.dart
// 🔥 店家媒體設定頁（活動海報管理 完整版）

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:petnest_saas/core/services/shop_profile_service.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/features/shop/widgets/media/banner_image_crop_page.dart';

class ShopMediaPage extends StatefulWidget {
  const ShopMediaPage({super.key, required this.shopId});

  final String shopId;

  @override
  State<ShopMediaPage> createState() => _ShopMediaPageState();
}

class _ShopMediaPageState extends State<ShopMediaPage> {
  bool _pickingImage = false;
  bool _uploading = false;
  bool _saving = false;
  bool _loaded = false;
  String? _busyMessage;

  List<Map<String, dynamic>> banners = [];
  List<Map<String, dynamic>> _savedBanners = [];

  final List<_TrackedBannerImage> _pendingUploads = <_TrackedBannerImage>[];
  final List<_TrackedBannerImage> _retiredOfficialImages =
      <_TrackedBannerImage>[];

  static const int _maxImageBytes = 5 * 1024 * 1024;

  bool get _hasUnsavedChanges {
    if (_pendingUploads.isNotEmpty || _retiredOfficialImages.isNotEmpty) {
      return true;
    }
    return !_bannerListsEqual(banners, _savedBanners);
  }

  bool get _imageBusy => _pickingImage || _uploading || _saving;

  @override
  void initState() {
    super.initState();
    _loadBanners();
  }

  Future<void> _loadBanners() async {
    final shop = await ShopService.instance.getShop(widget.shopId);
    final data = shop?['banners'];

    final List<Map<String, dynamic>> loaded = <Map<String, dynamic>>[];
    if (data is List) {
      for (final Object? item in data) {
        if (item is! Map) {
          continue;
        }
        loaded.add(_normalizeBanner(item));
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      banners = _cloneBanners(loaded);
      _savedBanners = _cloneBanners(loaded);
      _pendingUploads.clear();
      _retiredOfficialImages.clear();
      _loaded = true;
    });
  }

  Map<String, dynamic> _normalizeBanner(Map<dynamic, dynamic> raw) {
    return <String, dynamic>{
      'imageUrl': (raw['imageUrl'] ?? '').toString(),
      'imageStoragePath': (raw['imageStoragePath'] ?? '').toString(),
      'isActive': raw['isActive'] ?? true,
    };
  }

  List<Map<String, dynamic>> _cloneBanners(List<Map<String, dynamic>> source) {
    return source
        .map((Map<String, dynamic> item) => Map<String, dynamic>.from(item))
        .toList();
  }

  bool _bannerListsEqual(
    List<Map<String, dynamic>> left,
    List<Map<String, dynamic>> right,
  ) {
    if (left.length != right.length) {
      return false;
    }

    for (int i = 0; i < left.length; i++) {
      if (_bannerImageUrl(left[i]) != _bannerImageUrl(right[i]) ||
          _bannerStoragePath(left[i]) != _bannerStoragePath(right[i]) ||
          (left[i]['isActive'] == true) != (right[i]['isActive'] == true)) {
        return false;
      }
    }
    return true;
  }

  String _bannerImageUrl(Map<String, dynamic> banner) {
    return (banner['imageUrl'] ?? '').toString().trim();
  }

  String _bannerStoragePath(Map<String, dynamic> banner) {
    return (banner['imageStoragePath'] ?? '').toString().trim();
  }

  bool _isPendingPath(String path) {
    return path.isNotEmpty &&
        _pendingUploads.any((_TrackedBannerImage item) => item.path == path);
  }

  bool _isOfficialImage(String path, String url) {
    for (final Map<String, dynamic> saved in _savedBanners) {
      final String savedPath = _bannerStoragePath(saved);
      final String savedUrl = _bannerImageUrl(saved);
      if (path.isNotEmpty && savedPath == path) {
        return true;
      }
      if (url.isNotEmpty && savedUrl == url) {
        return true;
      }
    }
    return false;
  }

  void _trackRetiredOfficial(String path, String url) {
    if (path.isEmpty && url.isEmpty) {
      return;
    }

    final bool alreadyTracked = _retiredOfficialImages.any(
      (_TrackedBannerImage item) =>
          (path.isNotEmpty && item.path == path) ||
          (url.isNotEmpty && item.url == url),
    );
    if (alreadyTracked) {
      return;
    }

    _retiredOfficialImages.add(_TrackedBannerImage(path: path, url: url));
  }

  Future<void> _cleanupTracked(
    _TrackedBannerImage image, {
    required String reason,
  }) async {
    final bool cleaned = await ShopService.instance.tryDeleteShopBannerImage(
      shopId: widget.shopId,
      imageStoragePath: image.path,
      imageUrl: image.url,
    );
    if (!cleaned) {
      debugPrint(
        'Banner image leftover after $reason: path=${image.path} url=${image.url}',
      );
    }
  }

  Future<void> _cleanupPendingUploads({required String reason}) async {
    final List<_TrackedBannerImage> pending = List<_TrackedBannerImage>.from(
      _pendingUploads,
    );
    _pendingUploads.clear();

    for (final _TrackedBannerImage image in pending) {
      await _cleanupTracked(image, reason: reason);
    }
  }

  String _friendlyUploadError(Object error) {
    final String text = error.toString().toLowerCase();

    if (text.contains('network') ||
        text.contains('socket') ||
        text.contains('unavailable')) {
      return '網路不穩定，圖片上傳失敗，請稍後再試';
    }

    if (text.contains('unauthorized') ||
        text.contains('permission') ||
        text.contains('forbidden')) {
      return '沒有上傳權限，請重新登入後再試';
    }

    if (text.contains('quota') ||
        text.contains('too large') ||
        text.contains('413')) {
      return '圖片太大，請換一張較小的照片';
    }

    return '圖片上傳失敗，請稍後再試';
  }

  void _showImageError(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickAndUploadImage(int index) async {
    if (_imageBusy) {
      return;
    }

    setState(() {
      _pickingImage = true;
      _busyMessage = null;
    });

    try {
      final ImagePicker picker = ImagePicker();

      final XFile? file = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2400,
        maxHeight: 2400,
        imageQuality: 92,
      );

      if (file == null || !mounted) {
        return;
      }

      setState(() {
        _busyMessage = '正在讀取圖片…';
      });

      late final Uint8List originalBytes;
      try {
        originalBytes = await file.readAsBytes();
      } catch (_) {
        _showImageError('圖片處理失敗，請重新選擇圖片。');
        return;
      }

      if (originalBytes.isEmpty) {
        _showImageError('圖片處理失敗，請重新選擇圖片。');
        return;
      }

      if (originalBytes.length > _maxImageBytes) {
        _showImageError('單張圖片最大 5 MB，請換一張較小的照片');
        return;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _busyMessage = null;
      });

      final Uint8List? croppedBytes = await BannerImageCropPage.open(
        context: context,
        imageBytes: originalBytes,
      );

      if (croppedBytes == null || !mounted) {
        return;
      }

      if (croppedBytes.length > _maxImageBytes) {
        _showImageError('單張圖片最大 5 MB，請換一張較小的照片');
        return;
      }

      setState(() {
        _uploading = true;
        _busyMessage = '正在上傳圖片…';
      });

      final ShopBannerImageUpload uploaded = await ShopService.instance
          .uploadShopBannerImage(shopId: widget.shopId, bytes: croppedBytes);

      if (!mounted) {
        await ShopService.instance.tryDeleteShopBannerImage(
          shopId: widget.shopId,
          imageStoragePath: uploaded.imageStoragePath,
          imageUrl: uploaded.imageUrl,
        );
        return;
      }

      final Map<String, dynamic> banner = banners[index];
      final String previousUrl = _bannerImageUrl(banner);
      final String previousPath = _bannerStoragePath(banner);

      if (_isPendingPath(previousPath)) {
        final int pendingIndex = _pendingUploads.indexWhere(
          (_TrackedBannerImage item) => item.path == previousPath,
        );
        if (pendingIndex >= 0) {
          final _TrackedBannerImage replaced = _pendingUploads.removeAt(
            pendingIndex,
          );
          await _cleanupTracked(replaced, reason: 'replaced-pending');
        }
      } else if (_isOfficialImage(previousPath, previousUrl)) {
        _trackRetiredOfficial(previousPath, previousUrl);
      }

      _pendingUploads.add(
        _TrackedBannerImage(
          path: uploaded.imageStoragePath,
          url: uploaded.imageUrl,
        ),
      );

      setState(() {
        banners[index]['imageUrl'] = uploaded.imageUrl;
        banners[index]['imageStoragePath'] = uploaded.imageStoragePath;
      });
    } catch (error) {
      _showImageError(_friendlyUploadError(error));
    } finally {
      if (mounted) {
        setState(() {
          _pickingImage = false;
          _uploading = false;
          _busyMessage = null;
        });
      }
    }
  }

  Future<void> _removeBannerAt(int index) async {
    final Map<String, dynamic> banner = banners[index];
    final String url = _bannerImageUrl(banner);
    final String path = _bannerStoragePath(banner);

    if (_isPendingPath(path)) {
      final int pendingIndex = _pendingUploads.indexWhere(
        (_TrackedBannerImage item) => item.path == path,
      );
      if (pendingIndex >= 0) {
        final _TrackedBannerImage pending = _pendingUploads.removeAt(
          pendingIndex,
        );
        await _cleanupTracked(pending, reason: 'removed-unsaved-banner');
      }
    } else if (_isOfficialImage(path, url)) {
      _trackRetiredOfficial(path, url);
    }

    if (!mounted) {
      return;
    }

    setState(() {
      banners.removeAt(index);
    });
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }

    setState(() => _saving = true);

    try {
      await ShopService.instance.updateShop(
        shopId: widget.shopId,
        data: {'banners': _cloneBanners(banners)},
      );

      final Set<String> usedPaths = banners
          .map(_bannerStoragePath)
          .where((String path) => path.isNotEmpty)
          .toSet();
      final Set<String> usedUrls = banners
          .map(_bannerImageUrl)
          .where((String url) => url.isNotEmpty)
          .toSet();

      bool cleanupFailed = false;
      for (final _TrackedBannerImage retired in _retiredOfficialImages) {
        if ((retired.path.isNotEmpty && usedPaths.contains(retired.path)) ||
            (retired.url.isNotEmpty && usedUrls.contains(retired.url))) {
          continue;
        }

        final bool cleaned = await ShopService.instance.tryDeleteShopBannerImage(
          shopId: widget.shopId,
          imageStoragePath: retired.path,
          imageUrl: retired.url,
        );
        if (!cleaned) {
          cleanupFailed = true;
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _savedBanners = _cloneBanners(banners);
        _pendingUploads.clear();
        _retiredOfficialImages.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            cleanupFailed
                ? '海報已儲存，但舊圖片清理失敗，系統稍後仍可再次清理。'
                : '儲存成功',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('儲存失敗，請稍後再試')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _onPopAttempt({required bool didPop}) async {
    if (didPop) {
      return;
    }

    if (_uploading || _pickingImage) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_uploading ? '圖片上傳中，請稍候再離開' : '圖片處理中，請稍候再離開'),
        ),
      );
      return;
    }

    final bool? discard = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('尚有未儲存的變更'),
          content: const Text('離開後，本次尚未儲存的修改將會放棄。'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('繼續編輯'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('放棄變更'),
            ),
          ],
        );
      },
    );

    if (discard != true || !mounted) {
      return;
    }

    await _cleanupPendingUploads(reason: 'discard-unsaved');
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
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
          Text(
            '其他尺寸也可以上傳，下一步可拖曳、縮放並選擇實際顯示範圍。',
            style: TextStyle(height: 1.4),
          ),
          SizedBox(height: 4),
          Text('單張圖片最大 5 MB'),
        ],
      ),
    );
  }

  Widget _buildBusyOverlay() {
    final String? message = _busyMessage;
    if (message == null || message.isEmpty) {
      return const SizedBox.shrink();
    }

    return Positioned.fill(
      child: AbsorbPointer(
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.45),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: Colors.white),
                const SizedBox(height: 16),
                Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_imageBusy && (!_loaded || !_hasUnsavedChanges),
      onPopInvokedWithResult: (bool didPop, Object? result) {
        _onPopAttempt(didPop: didPop);
      },
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
        children: [
          Scaffold(
            appBar: AppBar(title: const Text('活動海報管理'), actions: const []),
            bottomNavigationBar: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _imageBusy ? null : _save,
                    icon: const Icon(Icons.save),
                    label: Text(_saving ? '儲存中' : '儲存海報設定'),
                  ),
                ),
              ),
            ),
            body: !_loaded
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildHintCard(),

                      const SizedBox(height: 16),

                      ReorderableListView(
                        buildDefaultDragHandles: false,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        onReorder: (oldIndex, newIndex) {
                          if (_imageBusy) {
                            return;
                          }
                          setState(() {
                            if (newIndex > oldIndex) newIndex--;
                            final item = banners.removeAt(oldIndex);
                            banners.insert(newIndex, item);
                          });
                        },
                        children: banners.asMap().entries.map((entry) {
                          final index = entry.key;
                          final banner = entry.value;
                          final bool hasImage = _bannerImageUrl(banner).isNotEmpty;

                          return Card(
                            key: ValueKey('banner_$index'),
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                children: [
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

                                  hasImage
                                      ? AspectRatio(
                                          aspectRatio: 16 / 9,
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            child: Image.network(
                                              banner['imageUrl'],
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        )
                                      : const Text('尚未上傳圖片'),

                                  const SizedBox(height: 6),

                                  ElevatedButton(
                                    onPressed: _imageBusy
                                        ? null
                                        : () => _pickAndUploadImage(index),
                                    child: Text(hasImage ? '更換圖片' : '上傳圖片'),
                                  ),

                                  SwitchListTile(
                                    title: const Text('啟用'),
                                    value: banner['isActive'] == true,
                                    onChanged: _imageBusy
                                        ? null
                                        : (value) {
                                            setState(() {
                                              banner['isActive'] = value;
                                            });
                                          },
                                  ),

                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: _imageBusy
                                          ? null
                                          : () => _removeBannerAt(index),
                                      child: const Text('刪除'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      ElevatedButton(
                        onPressed: _imageBusy
                            ? null
                            : () {
                                if (banners.length >= 5) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('最多只能5張海報')),
                                  );
                                  return;
                                }

                                setState(() {
                                  banners.add(<String, dynamic>{
                                    'imageUrl': '',
                                    'imageStoragePath': '',
                                    'isActive': true,
                                  });
                                });
                              },
                        child: const Text('新增海報'),
                      ),
                    ],
                  ),
          ),
          _buildBusyOverlay(),
        ],
        ),
      ),
    );
  }
}

class _TrackedBannerImage {
  const _TrackedBannerImage({required this.path, required this.url});

  final String path;
  final String url;
}
