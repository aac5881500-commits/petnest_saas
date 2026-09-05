// 檔案名稱：lib/features/shop/pages/shop_environment_manage_page.dart
// 功能說明：後台環境介紹管理頁

import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:petnest_saas/core/models/environment_image_frame_setting.dart';
import 'package:petnest_saas/core/models/environment_intro_style.dart';
import 'package:petnest_saas/core/models/fixed_image_spec.dart';
import 'package:petnest_saas/core/services/shop_profile_service.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/features/shop/data/environment_facility_options.dart';
import 'package:petnest_saas/features/shop/pages/shop_environment_page.dart';
import 'package:petnest_saas/features/shop/widgets/environment/environment_feature_manager.dart';
import 'package:petnest_saas/features/shop/widgets/environment/environment_gallery_manager.dart';
import 'package:petnest_saas/features/shop/widgets/environment/environment_icon_picker_dialog.dart';
import 'package:petnest_saas/features/shop/widgets/environment/environment_image_upload_box.dart';
import 'package:petnest_saas/features/shop/widgets/media/fixed_aspect_image_crop_page.dart';

class ShopEnvironmentManagePage extends StatefulWidget {
  const ShopEnvironmentManagePage({super.key, required this.shopId});

  final String shopId;

  @override
  State<ShopEnvironmentManagePage> createState() =>
      _ShopEnvironmentManagePageState();
}

class _ShopEnvironmentManagePageState extends State<ShopEnvironmentManagePage> {
  bool _loading = true;
  bool _pickingImage = false;
  bool _uploadingHeroImage = false;
  bool _uploadingBannerImage = false;
  bool _saving = false;
  String? _busyMessage;

  List<Map<String, dynamic>> environmentGalleryImages = [];
  List<Map<String, dynamic>> environmentFeatures = [];
  List<String> selectedFacilityKeys = [
    'air_cleaner',
    'camera_24h',
    'hospital',
    'water',
    'sunlight',
    'disinfect',
  ];

  final TextEditingController heroTitleController = TextEditingController(
    text: '讓每一隻貓咪\n都能像在家一樣放鬆',
  );
  final TextEditingController heroSubtitleController = TextEditingController(
    text: '安心・舒適・乾淨的貓咪住宿空間',
  );
  final TextEditingController bannerTitleController = TextEditingController(
    text: '用心打造每一個細節\n只為給貓咪更好的住宿體驗',
  );
  final TextEditingController bottomNoteController = TextEditingController(
    text: '每隻貓咪個性不同，實際住宿安排會依照貓咪狀況與店家現場評估調整。',
  );

  String _heroImageUrl =
      'https://images.unsplash.com/photo-1519052537078-e6302a4968d4?w=1200';
  String _bannerImageUrl =
      'https://images.unsplash.com/photo-1518791841217-8f162f1e1131?w=1000';
  String _heroImagePath = '';
  String _bannerImagePath = '';

  EnvironmentImageFrameSetting _heroFrame = const EnvironmentImageFrameSetting(
    slot: EnvironmentImageSlot.hero,
  );
  EnvironmentImageFrameSetting _bannerFrame =
      const EnvironmentImageFrameSetting(
        slot: EnvironmentImageSlot.middleBanner,
      );

  String _savedHeroImageUrl = '';
  String _savedBannerImageUrl = '';
  String _savedHeroImagePath = '';
  String _savedBannerImagePath = '';
  EnvironmentImageFrameSetting _savedHeroFrame =
      const EnvironmentImageFrameSetting(slot: EnvironmentImageSlot.hero);
  EnvironmentImageFrameSetting _savedBannerFrame =
      const EnvironmentImageFrameSetting(
        slot: EnvironmentImageSlot.middleBanner,
      );

  EnvironmentIntroStyle _style = const EnvironmentIntroStyle();
  EnvironmentIntroStyle _savedStyle = const EnvironmentIntroStyle();

  final List<_TrackedEnvImage> _pendingUploads = <_TrackedEnvImage>[];
  final List<_TrackedEnvImage> _retiredOfficialImages = <_TrackedEnvImage>[];

  static const int _maxImageBytes = 5 * 1024 * 1024;

  bool get _imageBusy =>
      _pickingImage || _uploadingHeroImage || _uploadingBannerImage || _saving;

  bool get _hasUnsavedImageChanges {
    if (_pendingUploads.isNotEmpty || _retiredOfficialImages.isNotEmpty) {
      return true;
    }
    return _heroImageUrl != _savedHeroImageUrl ||
        _bannerImageUrl != _savedBannerImageUrl ||
        _heroImagePath != _savedHeroImagePath ||
        _bannerImagePath != _savedBannerImagePath ||
        _heroFrame.heightPreset != _savedHeroFrame.heightPreset ||
        _heroFrame.imageFit != _savedHeroFrame.imageFit ||
        _heroFrame.imageAlignment != _savedHeroFrame.imageAlignment ||
        _bannerFrame.heightPreset != _savedBannerFrame.heightPreset ||
        _bannerFrame.imageFit != _savedBannerFrame.imageFit ||
        _bannerFrame.imageAlignment != _savedBannerFrame.imageAlignment ||
        _style.displaySize != _savedStyle.displaySize ||
        _style.fontSize != _savedStyle.fontSize ||
        _style.cardLayout != _savedStyle.cardLayout ||
        _style.cardDensity != _savedStyle.cardDensity;
  }

  @override
  void initState() {
    super.initState();
    heroTitleController.addListener(_onPreviewTextChanged);
    heroSubtitleController.addListener(_onPreviewTextChanged);
    bannerTitleController.addListener(_onPreviewTextChanged);
    _loadEnvironmentIntro();
  }

  void _onPreviewTextChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadEnvironmentIntro() async {
    final DocumentSnapshot<Map<String, dynamic>> doc = await FirebaseFirestore
        .instance
        .collection('shops')
        .doc(widget.shopId)
        .get();

    final Map<String, dynamic>? data = doc.data();
    final Map<String, dynamic>? environmentIntro =
        data?['environmentIntro'] as Map<String, dynamic>?;

    if (environmentIntro != null) {
      heroTitleController.text =
          environmentIntro['heroTitle'] ?? heroTitleController.text;
      heroSubtitleController.text =
          environmentIntro['heroSubtitle'] ?? heroSubtitleController.text;
      bannerTitleController.text =
          environmentIntro['bannerTitle'] ?? bannerTitleController.text;
      bottomNoteController.text =
          environmentIntro['bottomNote'] ?? bottomNoteController.text;
      _heroImageUrl = (environmentIntro['heroImageUrl'] ?? _heroImageUrl)
          .toString();
      _bannerImageUrl = (environmentIntro['bannerImageUrl'] ?? _bannerImageUrl)
          .toString();
      _heroImagePath = (environmentIntro['heroImageStoragePath'] ?? '')
          .toString();
      _bannerImagePath = (environmentIntro['bannerImageStoragePath'] ?? '')
          .toString();
      environmentGalleryImages = _parseGalleryItems(
        environmentIntro['galleryImages'],
      );
      environmentFeatures = List<Map<String, dynamic>>.from(
        environmentIntro['features'] ?? [],
      );
      selectedFacilityKeys = List<String>.from(
        environmentIntro['facilityKeys'] ?? selectedFacilityKeys,
      );
      _heroFrame = EnvironmentImageFrameSetting.heroFromMap(environmentIntro);
      _bannerFrame = EnvironmentImageFrameSetting.bannerFromMap(
        environmentIntro,
      );
      _style = EnvironmentIntroStyle.fromMap(environmentIntro);
    }

    _savedHeroImageUrl = _heroImageUrl;
    _savedBannerImageUrl = _bannerImageUrl;
    _savedHeroImagePath = _heroImagePath;
    _savedBannerImagePath = _bannerImagePath;
    _savedHeroFrame = _heroFrame;
    _savedBannerFrame = _bannerFrame;
    _savedStyle = _style;
    _pendingUploads.clear();
    _retiredOfficialImages.clear();

    if (!mounted) {
      return;
    }
    setState(() {
      _loading = false;
    });
  }

  @override
  void dispose() {
    heroTitleController.removeListener(_onPreviewTextChanged);
    heroSubtitleController.removeListener(_onPreviewTextChanged);
    bannerTitleController.removeListener(_onPreviewTextChanged);
    heroTitleController.dispose();
    heroSubtitleController.dispose();
    bannerTitleController.dispose();
    bottomNoteController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _parseGalleryItems(dynamic raw) {
    final List<Map<String, dynamic>> items = <Map<String, dynamic>>[];
    if (raw is! List) {
      return items;
    }

    for (final Object? item in raw) {
      if (item is String && item.trim().isNotEmpty) {
        items.add(<String, dynamic>{
          'imageUrl': item.trim(),
          'imageStoragePath': '',
        });
        continue;
      }

      if (item is Map) {
        final String imageUrl = (item['imageUrl'] ?? '').toString().trim();
        if (imageUrl.isEmpty) {
          continue;
        }
        items.add(<String, dynamic>{
          'imageUrl': imageUrl,
          'imageStoragePath': (item['imageStoragePath'] ?? '')
              .toString()
              .trim(),
        });
      }
    }
    return items;
  }

  String _mapImageUrl(Map<String, dynamic> item) {
    return (item['imageUrl'] ?? '').toString().trim();
  }

  String _mapImagePath(Map<String, dynamic> item) {
    return (item['imageStoragePath'] ?? '').toString().trim();
  }

  List<Map<String, dynamic>> _galleryPayload() {
    return environmentGalleryImages
        .map(
          (Map<String, dynamic> item) => <String, dynamic>{
            'imageUrl': _mapImageUrl(item),
            'imageStoragePath': _mapImagePath(item),
          },
        )
        .toList();
  }

  bool _isPendingPath(String path) {
    return path.isNotEmpty &&
        _pendingUploads.any((_TrackedEnvImage item) => item.path == path);
  }

  bool _isOfficialImage(String path, String url) {
    if (path.isNotEmpty &&
        (path == _savedHeroImagePath || path == _savedBannerImagePath)) {
      return true;
    }
    if (url.isNotEmpty &&
        (url == _savedHeroImageUrl || url == _savedBannerImageUrl)) {
      return true;
    }
    return false;
  }

  void _trackRetiredOfficial({
    required String slot,
    required String path,
    required String url,
  }) {
    if (path.isEmpty && url.isEmpty) {
      return;
    }

    final bool alreadyTracked = _retiredOfficialImages.any(
      (_TrackedEnvImage item) =>
          (path.isNotEmpty && item.path == path) ||
          (url.isNotEmpty && item.url == url),
    );
    if (alreadyTracked) {
      return;
    }

    _retiredOfficialImages.add(
      _TrackedEnvImage(slot: slot, path: path, url: url),
    );
  }

  Future<void> _cleanupTracked(
    _TrackedEnvImage image, {
    required String reason,
  }) async {
    final bool cleaned = await ShopService.instance
        .tryDeleteEnvironmentIntroImage(
          shopId: widget.shopId,
          imageStoragePath: image.path,
          imageUrl: image.url,
        );
    if (!cleaned) {
      debugPrint(
        'Environment intro image leftover after $reason: '
        'slot=${image.slot} path=${image.path} url=${image.url}',
      );
    }
  }

  Future<void> _cleanupPendingUploads({required String reason}) async {
    final List<_TrackedEnvImage> pending = List<_TrackedEnvImage>.from(
      _pendingUploads,
    );
    _pendingUploads.clear();
    for (final _TrackedEnvImage image in pending) {
      await _cleanupTracked(image, reason: reason);
    }
  }

  void _showImageError(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickAndUploadImage({required String type}) async {
    if (_imageBusy) {
      return;
    }

    setState(() {
      _pickingImage = true;
      _busyMessage = null;
      if (type == 'hero') {
        _uploadingHeroImage = true;
      } else {
        _uploadingBannerImage = true;
      }
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
        _busyMessage = '正在準備圖片…';
      });

      await Future<void>.delayed(const Duration(milliseconds: 50));
      if (!mounted) {
        return;
      }

      final FixedImageSpec spec = type == 'hero'
          ? FixedImageSpec.environmentHero
          : FixedImageSpec.environmentBanner;

      final Uint8List? croppedBytes = await FixedAspectImageCropPage.open(
        context: context,
        imageBytes: originalBytes,
        spec: spec,
        title: type == 'hero' ? '裁切環境介紹首頁大圖' : '裁切環境介紹中間橫幅',
      );

      if (croppedBytes == null || !mounted) {
        return;
      }

      if (croppedBytes.length > _maxImageBytes) {
        _showImageError('單張圖片最大 5 MB，請換一張較小的照片');
        return;
      }

      setState(() {
        _busyMessage = '正在上傳圖片…';
      });

      final ShopEnvironmentIntroImageUpload uploaded = await ShopService
          .instance
          .uploadEnvironmentIntroImage(
            shopId: widget.shopId,
            slot: type,
            bytes: croppedBytes,
          );

      if (!mounted) {
        await ShopService.instance.tryDeleteEnvironmentIntroImage(
          shopId: widget.shopId,
          imageStoragePath: uploaded.imageStoragePath,
          imageUrl: uploaded.imageUrl,
        );
        return;
      }

      final String previousUrl = type == 'hero'
          ? _heroImageUrl
          : _bannerImageUrl;
      final String previousPath = type == 'hero'
          ? _heroImagePath
          : _bannerImagePath;

      if (_isPendingPath(previousPath)) {
        final int pendingIndex = _pendingUploads.indexWhere(
          (_TrackedEnvImage item) => item.path == previousPath,
        );
        if (pendingIndex >= 0) {
          final _TrackedEnvImage replaced = _pendingUploads.removeAt(
            pendingIndex,
          );
          await _cleanupTracked(replaced, reason: 'replaced-pending');
        }
      } else if (_isOfficialImage(previousPath, previousUrl)) {
        _trackRetiredOfficial(slot: type, path: previousPath, url: previousUrl);
      }

      _pendingUploads.add(
        _TrackedEnvImage(
          slot: type,
          path: uploaded.imageStoragePath,
          url: uploaded.imageUrl,
        ),
      );

      setState(() {
        if (type == 'hero') {
          _heroImageUrl = uploaded.imageUrl;
          _heroImagePath = uploaded.imageStoragePath;
        } else {
          _bannerImageUrl = uploaded.imageUrl;
          _bannerImagePath = uploaded.imageStoragePath;
        }
      });
    } catch (_) {
      _showImageError('圖片處理失敗，請重新選擇圖片。');
    } finally {
      if (mounted) {
        setState(() {
          _pickingImage = false;
          _uploadingHeroImage = false;
          _uploadingBannerImage = false;
          _busyMessage = null;
        });
      }
    }
  }

  Future<void> _removeSlotImage({required String type}) async {
    if (_imageBusy) {
      return;
    }

    final String previousUrl = type == 'hero' ? _heroImageUrl : _bannerImageUrl;
    final String previousPath = type == 'hero'
        ? _heroImagePath
        : _bannerImagePath;

    if (_isPendingPath(previousPath)) {
      final int pendingIndex = _pendingUploads.indexWhere(
        (_TrackedEnvImage item) => item.path == previousPath,
      );
      if (pendingIndex >= 0) {
        final _TrackedEnvImage pending = _pendingUploads.removeAt(pendingIndex);
        await _cleanupTracked(pending, reason: 'removed-unsaved');
      }
    } else if (_isOfficialImage(previousPath, previousUrl)) {
      _trackRetiredOfficial(slot: type, path: previousPath, url: previousUrl);
    }

    if (!mounted) {
      return;
    }

    setState(() {
      if (type == 'hero') {
        _heroImageUrl = '';
        _heroImagePath = '';
      } else {
        _bannerImageUrl = '';
        _bannerImagePath = '';
      }
    });
  }

  Future<void> _pickAndUploadGalleryImage() async {
    if (_imageBusy) {
      return;
    }
    if (environmentGalleryImages.length >= 12) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('環境照片最多上傳 12 張')));
      return;
    }

    setState(() {
      _pickingImage = true;
      _busyMessage = null;
    });

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image == null || !mounted) {
        return;
      }

      setState(() {
        _busyMessage = '正在讀取圖片…';
      });

      final Uint8List originalBytes = await image.readAsBytes();
      if (originalBytes.isEmpty) {
        _showImageError('圖片處理失敗，請重新選擇圖片。');
        return;
      }
      if (originalBytes.length > _maxImageBytes) {
        _showImageError('單張圖片最大 5 MB，請換一張較小的照片');
        return;
      }

      setState(() {
        _busyMessage = '正在處理圖片…';
      });

      final Uint8List? compressed = ShopService.instance
          .compressEnvironmentImageBytes(bytes: originalBytes, maxSide: 1600);
      if (compressed == null || compressed.isEmpty) {
        _showImageError('圖片處理失敗，請重新選擇圖片。');
        return;
      }

      setState(() {
        _busyMessage = '正在上傳圖片…';
      });

      final ShopEnvironmentIntroImageUpload uploaded = await ShopService
          .instance
          .uploadEnvironmentGalleryImage(
            shopId: widget.shopId,
            bytes: compressed,
          );

      environmentGalleryImages.add(<String, dynamic>{
        'imageUrl': uploaded.imageUrl,
        'imageStoragePath': uploaded.imageStoragePath,
      });

      try {
        await _persistAuxiliarySections();
      } catch (_) {
        environmentGalleryImages.removeLast();
        await ShopService.instance.tryDeleteEnvironmentGalleryImage(
          shopId: widget.shopId,
          imageStoragePath: uploaded.imageStoragePath,
          imageUrl: uploaded.imageUrl,
        );
        _showImageError('圖片處理失敗，請重新選擇圖片。');
        return;
      }

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('環境照片已上傳')));
    } catch (_) {
      _showImageError('圖片處理失敗，請重新選擇圖片。');
    } finally {
      if (mounted) {
        setState(() {
          _pickingImage = false;
          _busyMessage = null;
        });
      }
    }
  }

  Future<void> _deleteGalleryImage(int index) async {
    if (_imageBusy || index < 0 || index >= environmentGalleryImages.length) {
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('移除環境照片'),
          content: const Text('確定要移除這張照片嗎？\n移除後前台將不再顯示，伺服器上的圖片檔也會一併刪除。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('移除並刪除'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final Map<String, dynamic> removed = environmentGalleryImages[index];
    final List<Map<String, dynamic>> previous = List<Map<String, dynamic>>.from(
      environmentGalleryImages,
    );

    setState(() {
      _pickingImage = true;
      _busyMessage = '正在移除照片…';
      environmentGalleryImages.removeAt(index);
    });

    try {
      await _persistAuxiliarySections();
    } catch (_) {
      if (mounted) {
        setState(() {
          environmentGalleryImages = previous;
        });
        _showImageError('儲存失敗，請稍後再試');
      }
      return;
    } finally {
      if (mounted) {
        setState(() {
          _pickingImage = false;
          _busyMessage = null;
        });
      }
    }

    final bool cleaned = await ShopService.instance
        .tryDeleteEnvironmentGalleryImage(
          shopId: widget.shopId,
          imageStoragePath: _mapImagePath(removed),
          imageUrl: _mapImageUrl(removed),
        );

    if (!mounted) {
      return;
    }
    if (!cleaned) {
      debugPrint(
        'Environment gallery image leftover after delete: '
        'path=${_mapImagePath(removed)} url=${_mapImageUrl(removed)}',
      );
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(cleaned ? '環境照片已刪除' : '照片已移除，但舊圖片清理失敗，請稍後再試。')),
    );
  }

  Future<void> _editFeature(int index) async {
    if (index < 0 || index >= environmentFeatures.length) {
      return;
    }

    final Map<String, dynamic> item = environmentFeatures[index];
    final TextEditingController titleController = TextEditingController(
      text: item['title'] ?? '',
    );
    final TextEditingController descriptionController = TextEditingController(
      text: item['description'] ?? '',
    );

    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('編輯環境特色'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: '特色標題'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: '特色說明'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  environmentFeatures[index] = {
                    ...environmentFeatures[index],
                    'title': titleController.text.trim(),
                    'description': descriptionController.text.trim(),
                  };
                });
                _persistAuxiliarySections();
                Navigator.pop(context);
              },
              child: const Text('儲存'),
            ),
          ],
        );
      },
    );

    titleController.dispose();
    descriptionController.dispose();
  }

  Future<void> _changeFeatureIcon(int index) async {
    if (index < 0 || index >= environmentFeatures.length) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return EnvironmentIconPickerDialog(
          onSelect: (String selectedKey) {
            setState(() {
              environmentFeatures[index] = {
                ...environmentFeatures[index],
                'icon': selectedKey,
              };
            });
            _persistAuxiliarySections();
          },
        );
      },
    );
  }

  Future<void> _pickAndUploadFeatureImage(int index) async {
    if (_imageBusy || index < 0 || index >= environmentFeatures.length) {
      return;
    }

    setState(() {
      _pickingImage = true;
      _busyMessage = null;
    });

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image == null || !mounted) {
        return;
      }

      setState(() {
        _busyMessage = '正在讀取圖片…';
      });

      final Uint8List originalBytes = await image.readAsBytes();
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
        _busyMessage = '正在準備圖片…';
      });

      final Uint8List? cropped = await FixedAspectImageCropPage.open(
        context: context,
        imageBytes: originalBytes,
        spec: FixedImageSpec.environmentFeature,
        title: '裁切環境特色圖片',
      );
      if (cropped == null || !mounted) {
        return;
      }
      if (cropped.length > _maxImageBytes) {
        _showImageError('單張圖片最大 5 MB，請換一張較小的照片');
        return;
      }

      setState(() {
        _busyMessage = '正在上傳圖片…';
      });

      final ShopEnvironmentIntroImageUpload uploaded = await ShopService
          .instance
          .uploadEnvironmentFeatureImage(shopId: widget.shopId, bytes: cropped);

      final Map<String, dynamic> previous = Map<String, dynamic>.from(
        environmentFeatures[index],
      );
      final String oldUrl = _mapImageUrl(previous);
      final String oldPath = _mapImagePath(previous);

      setState(() {
        environmentFeatures[index] = {
          ...environmentFeatures[index],
          'imageUrl': uploaded.imageUrl,
          'imageStoragePath': uploaded.imageStoragePath,
        };
      });

      try {
        await _persistAuxiliarySections();
      } catch (_) {
        if (mounted) {
          setState(() {
            environmentFeatures[index] = previous;
          });
        }
        await ShopService.instance.tryDeleteEnvironmentFeatureImage(
          shopId: widget.shopId,
          imageStoragePath: uploaded.imageStoragePath,
          imageUrl: uploaded.imageUrl,
        );
        _showImageError('圖片處理失敗，請重新選擇圖片。');
        return;
      }

      if (oldUrl.isNotEmpty || oldPath.isNotEmpty) {
        final bool cleaned = await ShopService.instance
            .tryDeleteEnvironmentFeatureImage(
              shopId: widget.shopId,
              imageStoragePath: oldPath,
              imageUrl: oldUrl,
            );
        if (!cleaned) {
          debugPrint(
            'Environment feature image leftover after replace: path=$oldPath url=$oldUrl',
          );
        }
      }

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('特色圖片已上傳')));
    } catch (_) {
      _showImageError('圖片處理失敗，請重新選擇圖片。');
    } finally {
      if (mounted) {
        setState(() {
          _pickingImage = false;
          _busyMessage = null;
        });
      }
    }
  }

  Future<void> _removeFeatureImage(int index) async {
    if (_imageBusy || index < 0 || index >= environmentFeatures.length) {
      return;
    }

    final String oldUrl = _mapImageUrl(environmentFeatures[index]);
    final String oldPath = _mapImagePath(environmentFeatures[index]);
    if (oldUrl.isEmpty && oldPath.isEmpty) {
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('移除特色圖片'),
          content: const Text('移除後前台將不再顯示，伺服器圖片也會同步刪除。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('移除並刪除'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final Map<String, dynamic> previous = Map<String, dynamic>.from(
      environmentFeatures[index],
    );

    setState(() {
      _pickingImage = true;
      _busyMessage = '正在移除圖片…';
      environmentFeatures[index] = {
        ...environmentFeatures[index],
        'imageUrl': '',
        'imageStoragePath': '',
      };
    });

    try {
      await _persistAuxiliarySections();
    } catch (_) {
      if (mounted) {
        setState(() {
          environmentFeatures[index] = previous;
        });
        _showImageError('儲存失敗，請稍後再試');
      }
      return;
    } finally {
      if (mounted) {
        setState(() {
          _pickingImage = false;
          _busyMessage = null;
        });
      }
    }

    final bool cleaned = await ShopService.instance
        .tryDeleteEnvironmentFeatureImage(
          shopId: widget.shopId,
          imageStoragePath: oldPath,
          imageUrl: oldUrl,
        );

    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(cleaned ? '特色圖片已移除' : '設定已儲存，但舊圖片清理失敗，請稍後再試。')),
    );
  }

  Future<void> _openFeatureImageManager(int index) async {
    if (_imageBusy || index < 0 || index >= environmentFeatures.length) {
      return;
    }

    final String imageUrl = _mapImageUrl(environmentFeatures[index]);

    await showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '特色圖片',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  FixedImageSpec.environmentFeature.hintText,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: Color(0xFF8A6A45),
                  ),
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: AspectRatio(
                    aspectRatio: 4 / 3,
                    child: imageUrl.isEmpty
                        ? const ColoredBox(
                            color: Color(0xFFF5EBDD),
                            child: Center(
                              child: Text(
                                '尚未上傳圖片',
                                style: TextStyle(
                                  color: Color(0xFF8A6A45),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          )
                        : Image.network(imageUrl, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    _pickAndUploadFeatureImage(index);
                  },
                  icon: const Icon(Icons.upload_rounded),
                  label: Text(imageUrl.isEmpty ? '上傳照片' : '更換圖片'),
                ),
                if (imageUrl.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _removeFeatureImage(index);
                    },
                    child: const Text('移除圖片'),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _deleteFeatureAt(int index) async {
    if (_imageBusy || index < 0 || index >= environmentFeatures.length) {
      return;
    }

    final Map<String, dynamic> feature = environmentFeatures[index];
    final bool hasImage =
        _mapImageUrl(feature).isNotEmpty || _mapImagePath(feature).isNotEmpty;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('刪除環境特色'),
          content: Text(
            hasImage ? '刪除後此特色與相關圖片都會移除，且無法復原。' : '確定要刪除這張環境特色嗎？刪除後無法復原。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('刪除特色'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final List<Map<String, dynamic>> previous = environmentFeatures
        .map((Map<String, dynamic> item) => Map<String, dynamic>.from(item))
        .toList();
    final String oldUrl = _mapImageUrl(feature);
    final String oldPath = _mapImagePath(feature);

    setState(() {
      _pickingImage = true;
      _busyMessage = '正在刪除特色…';
      environmentFeatures.removeAt(index);
    });

    try {
      await _persistAuxiliarySections();
    } catch (_) {
      if (mounted) {
        setState(() {
          environmentFeatures = previous;
        });
        _showImageError('儲存失敗，請稍後再試');
      }
      return;
    } finally {
      if (mounted) {
        setState(() {
          _pickingImage = false;
          _busyMessage = null;
        });
      }
    }

    if (oldUrl.isNotEmpty || oldPath.isNotEmpty) {
      final bool cleaned = await ShopService.instance
          .tryDeleteEnvironmentFeatureImage(
            shopId: widget.shopId,
            imageStoragePath: oldPath,
            imageUrl: oldUrl,
          );
      if (!cleaned) {
        debugPrint(
          'Environment feature image leftover after delete card: path=$oldPath url=$oldUrl',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('設定已儲存，但舊圖片清理失敗，請稍後再試。')),
          );
          return;
        }
      }
    }

    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('環境特色已刪除')));
  }

  Future<void> _changeFeatureLayout(int index) async {
    if (index < 0 || index >= environmentFeatures.length) {
      return;
    }

    final String currentLayout =
        environmentFeatures[index]['layout'] ?? 'imageRight';
    final String nextLayout = currentLayout == 'imageLeft'
        ? 'imageRight'
        : 'imageLeft';

    setState(() {
      environmentFeatures[index] = {
        ...environmentFeatures[index],
        'layout': nextLayout,
      };
    });

    await _persistAuxiliarySections();
  }

  Future<void> _persistAuxiliarySections() async {
    await FirebaseFirestore.instance.collection('shops').doc(widget.shopId).set(
      {
        'environmentIntro': {
          'galleryImages': _galleryPayload(),
          'features': environmentFeatures,
          'facilityKeys': selectedFacilityKeys,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      },
      SetOptions(merge: true),
    );
  }

  Map<String, dynamic> _environmentIntroPayload() {
    return <String, dynamic>{
      'heroTitle': heroTitleController.text.trim(),
      'heroSubtitle': heroSubtitleController.text.trim(),
      'bannerTitle': bannerTitleController.text.trim(),
      'bottomNote': bottomNoteController.text.trim(),
      'heroImageUrl': _heroImageUrl.trim(),
      'bannerImageUrl': _bannerImageUrl.trim(),
      'heroImageStoragePath': _heroImagePath.trim(),
      'bannerImageStoragePath': _bannerImagePath.trim(),
      ..._heroFrame.toMap(),
      ..._bannerFrame.toMap(),
      ..._style.toMap(),
      'galleryImages': _galleryPayload(),
      'features': environmentFeatures,
      'facilityKeys': selectedFacilityKeys,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('shops')
          .doc(widget.shopId)
          .set({
            'environmentIntro': _environmentIntroPayload(),
          }, SetOptions(merge: true));

      final Set<String> usedPaths = <String>{
        if (_heroImagePath.isNotEmpty) _heroImagePath,
        if (_bannerImagePath.isNotEmpty) _bannerImagePath,
      };
      final Set<String> usedUrls = <String>{
        if (_heroImageUrl.isNotEmpty) _heroImageUrl,
        if (_bannerImageUrl.isNotEmpty) _bannerImageUrl,
      };

      bool cleanupFailed = false;
      for (final _TrackedEnvImage retired in _retiredOfficialImages) {
        if ((retired.path.isNotEmpty && usedPaths.contains(retired.path)) ||
            (retired.url.isNotEmpty && usedUrls.contains(retired.url))) {
          continue;
        }

        final bool cleaned = await ShopService.instance
            .tryDeleteEnvironmentIntroImage(
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
        _savedHeroImageUrl = _heroImageUrl;
        _savedBannerImageUrl = _bannerImageUrl;
        _savedHeroImagePath = _heroImagePath;
        _savedBannerImagePath = _bannerImagePath;
        _savedHeroFrame = _heroFrame;
        _savedBannerFrame = _bannerFrame;
        _savedStyle = _style;
        _pendingUploads.clear();
        _retiredOfficialImages.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(cleanupFailed ? '設定已儲存，但舊圖片清理失敗，請稍後再試。' : '環境介紹已儲存'),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('儲存失敗，請稍後再試')));
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _onPopAttempt({required bool didPop}) async {
    if (didPop) {
      return;
    }

    if (_imageBusy) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_saving ? '儲存中，請稍候再離開' : '圖片處理中，請稍候再離開')),
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

  void _openPreview() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ShopEnvironmentPage(
          shopId: widget.shopId,
          heroTitle: heroTitleController.text,
          heroSubtitle: heroSubtitleController.text,
          bannerTitle: bannerTitleController.text,
          bottomNote: bottomNoteController.text,
          heroImageUrl: _heroImageUrl,
          bannerImageUrl: _bannerImageUrl,
          heroFrame: _heroFrame,
          bannerFrame: _bannerFrame,
          style: _style,
          features: environmentFeatures,
          galleryImages: environmentGalleryImages
              .map(_mapImageUrl)
              .where((String url) => url.isNotEmpty)
              .toList(),
          facilityKeys: selectedFacilityKeys,
        ),
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
      canPop: !_imageBusy && !_hasUnsavedImageChanges,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        _onPopAttempt(didPop: didPop);
      },
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            Scaffold(
              backgroundColor: const Color(0xFFFFFCF7),
              appBar: AppBar(
                title: const Text('環境介紹管理'),
                backgroundColor: const Color(0xFFFFFCF7),
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                actions: [
                  TextButton(
                    onPressed: _imageBusy ? null : _openPreview,
                    child: const Text('預覽'),
                  ),
                  TextButton(
                    onPressed: _imageBusy ? null : _save,
                    child: Text(_saving ? '儲存中' : '儲存'),
                  ),
                ],
              ),
              body: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _buildTipCard(),
                        _groupLabel('整體顯示設定'),
                        _buildSectionCard(
                          title: '整體顯示尺寸',
                          subtitle: '調整卡片間距、圖片區塊與設備卡大小',
                          children: [
                            _buildChoiceChips(
                              value: _style.displaySize,
                              options: const <Map<String, String>>[
                                {
                                  'value': EnvironmentIntroStyle.sizeCompact,
                                  'label': '小',
                                },
                                {
                                  'value': EnvironmentIntroStyle.sizeStandard,
                                  'label': '標準',
                                },
                                {
                                  'value': EnvironmentIntroStyle.sizeLarge,
                                  'label': '大',
                                },
                              ],
                              onSelected: (String value) {
                                setState(() {
                                  _style = _style.copyWith(displaySize: value);
                                });
                              },
                            ),
                          ],
                        ),
                        _buildSectionCard(
                          title: '整體字體大小',
                          subtitle: '一次調整標題、卡片與提醒文字',
                          children: [
                            _buildChoiceChips(
                              value: _style.fontSize,
                              options: const <Map<String, String>>[
                                {
                                  'value': EnvironmentIntroStyle.fontSmall,
                                  'label': '小',
                                },
                                {
                                  'value': EnvironmentIntroStyle.fontStandard,
                                  'label': '標準',
                                },
                                {
                                  'value': EnvironmentIntroStyle.fontLarge,
                                  'label': '大',
                                },
                              ],
                              onSelected: (String value) {
                                setState(() {
                                  _style = _style.copyWith(fontSize: value);
                                });
                              },
                            ),
                          ],
                        ),
                        _buildSectionCard(
                          title: '環境特色卡片版型',
                          subtitle: '所有特色卡使用同一種版型',
                          children: [
                            _buildChoiceChips(
                              value: _style.cardLayout,
                              options: const <Map<String, String>>[
                                {
                                  'value':
                                      EnvironmentIntroStyle.layoutHorizontal,
                                  'label': '橫向圖卡',
                                },
                                {
                                  'value': EnvironmentIntroStyle.layoutVertical,
                                  'label': '上圖下文',
                                },
                                {
                                  'value': EnvironmentIntroStyle.layoutText,
                                  'label': '重點文字卡',
                                },
                              ],
                              onSelected: (String value) {
                                setState(() {
                                  _style = _style.copyWith(cardLayout: value);
                                });
                              },
                            ),
                          ],
                        ),
                        _buildSectionCard(
                          title: '環境特色卡片高度',
                          subtitle: '調整內距與圖片大小，文字多時卡片仍會長高',
                          children: [
                            _buildChoiceChips(
                              value: _style.cardDensity,
                              options: const <Map<String, String>>[
                                {
                                  'value': EnvironmentIntroStyle.densityCompact,
                                  'label': '精簡',
                                },
                                {
                                  'value':
                                      EnvironmentIntroStyle.densityStandard,
                                  'label': '標準',
                                },
                                {
                                  'value':
                                      EnvironmentIntroStyle.densityComfortable,
                                  'label': '寬鬆',
                                },
                              ],
                              onSelected: (String value) {
                                setState(() {
                                  _style = _style.copyWith(cardDensity: value);
                                });
                              },
                            ),
                          ],
                        ),
                        _groupLabel('首頁主視覺'),
                        _buildSectionCard(
                          title: '首頁大圖文案',
                          subtitle: '顯示在環境介紹頁最上方',
                          children: [
                            _buildTextField(
                              controller: heroTitleController,
                              label: '主標題',
                              maxLines: 2,
                            ),
                            const SizedBox(height: 12),
                            _buildTextField(
                              controller: heroSubtitleController,
                              label: '副標題',
                            ),
                          ],
                        ),
                        _buildSectionCard(
                          title: '首頁大圖',
                          subtitle: '可選擇顯示範圍、高度與填滿方式，儲存後才會更新前台正式圖片',
                          children: [
                            EnvironmentImageUploadBox(
                              title: '首頁大圖',
                              imageUrl: _heroImageUrl,
                              frame: _heroFrame,
                              uploading: _uploadingHeroImage,
                              busy: _imageBusy,
                              overlayTitle: heroTitleController.text,
                              overlaySubtitle: heroSubtitleController.text,
                              hint: FixedImageSpec.environmentHero.hintText,
                              onUpload: () => _pickAndUploadImage(type: 'hero'),
                              onDelete: () => _removeSlotImage(type: 'hero'),
                              onFrameChanged:
                                  (EnvironmentImageFrameSetting value) {
                                    setState(() {
                                      _heroFrame = value;
                                    });
                                  },
                            ),
                          ],
                        ),
                        _groupLabel('環境內容'),
                        _buildSectionCard(
                          title: '環境特色卡片',
                          subtitle: '顯示在前台「我們的環境特色」區塊',
                          children: [
                            EnvironmentFeatureManager(
                              features: environmentFeatures,
                              busy: _imageBusy,
                              onAdd: () {
                                setState(() {
                                  environmentFeatures.add({
                                    'icon': 'home',
                                    'title': '新的環境特色',
                                    'description': '請輸入環境特色說明',
                                    'imageUrl': '',
                                    'imageStoragePath': '',
                                    'layout': 'imageRight',
                                  });
                                });
                                _persistAuxiliarySections();
                              },
                              onEdit: _editFeature,
                              onManageImage: _openFeatureImageManager,
                              onChangeIcon: _changeFeatureIcon,
                              onChangeLayout: _changeFeatureLayout,
                              onDelete: _deleteFeatureAt,
                            ),
                          ],
                        ),
                        _buildSectionCard(
                          title: '安心照護設備',
                          subtitle: '勾選後會顯示在前台設備區塊',
                          children: [_buildFacilitySelector()],
                        ),
                        _groupLabel('其他內容'),
                        _buildSectionCard(
                          title: '中間橫幅文案',
                          subtitle: '顯示在環境介紹中段的大圖上',
                          children: [
                            _buildTextField(
                              controller: bannerTitleController,
                              label: '橫幅文字',
                              maxLines: 2,
                            ),
                          ],
                        ),
                        _buildSectionCard(
                          title: '中間橫幅圖片',
                          subtitle: '可選擇顯示範圍、高度與填滿方式，儲存後才會更新前台正式圖片',
                          children: [
                            EnvironmentImageUploadBox(
                              title: '中間橫幅圖',
                              imageUrl: _bannerImageUrl,
                              frame: _bannerFrame,
                              uploading: _uploadingBannerImage,
                              busy: _imageBusy,
                              overlayTitle: bannerTitleController.text,
                              hint: FixedImageSpec.environmentBanner.hintText,
                              onUpload: () =>
                                  _pickAndUploadImage(type: 'banner'),
                              onDelete: () => _removeSlotImage(type: 'banner'),
                              onFrameChanged:
                                  (EnvironmentImageFrameSetting value) {
                                    setState(() {
                                      _bannerFrame = value;
                                    });
                                  },
                            ),
                          ],
                        ),
                        _buildSectionCard(
                          title: '底部提醒文字',
                          subtitle: '顯示在環境照片牆上方',
                          children: [
                            _buildTextField(
                              controller: bottomNoteController,
                              label: '提醒文字',
                              maxLines: 3,
                            ),
                          ],
                        ),
                        _buildSectionCard(
                          title: '環境照片牆',
                          subtitle: '顯示在環境介紹主要內容最下方，最多 12 張',
                          children: [
                            EnvironmentGalleryManager(
                              images: environmentGalleryImages
                                  .map(_mapImageUrl)
                                  .toList(),
                              busy: _imageBusy,
                              onDelete: _deleteGalleryImage,
                              onUpload: _pickAndUploadGalleryImage,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: _imageBusy ? null : _save,
                            icon: const Icon(Icons.save_rounded),
                            label: Text(_saving ? '儲存中' : '儲存環境介紹'),
                          ),
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

  Widget _groupLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: Color(0xFF8A6A45),
        ),
      ),
    );
  }

  Widget _buildChoiceChips({
    required String value,
    required List<Map<String, String>> options,
    required ValueChanged<String> onSelected,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((Map<String, String> option) {
        final String optionValue = option['value']!;
        final bool selected = optionValue == value;
        return ChoiceChip(
          label: Text(option['label']!),
          selected: selected,
          onSelected: (_) => onSelected(optionValue),
        );
      }).toList(),
    );
  }

  Widget _buildTipCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1DD),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFD7A8)),
      ),
      child: const Text(
        '首頁大圖與中間橫幅圖會先上傳暫存，按「儲存環境介紹」後才會成為正式圖片。整體顯示尺寸、字體與特色卡版型也需按儲存後才會更新前台。更換後，舊圖會在儲存成功後才清除。',
        style: TextStyle(
          height: 1.5,
          color: Color(0xFF6F5A43),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF0E0CC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: Color(0xFF3A2A1A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 13, color: Color(0xFF8A6A45)),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _buildFacilitySelector() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: environmentFacilityOptions.map((Map<String, dynamic> item) {
        final String key = item['key'] as String;
        final bool selected = selectedFacilityKeys.contains(key);

        return FilterChip(
          label: Text(item['title']),
          selected: selected,
          avatar: Icon(
            item['icon'] as IconData,
            size: 18,
            color: selected ? Colors.white : const Color(0xFFB87535),
          ),
          selectedColor: const Color(0xFFB87535),
          checkmarkColor: Colors.white,
          labelStyle: TextStyle(
            color: selected ? Colors.white : const Color(0xFF3A2A1A),
            fontWeight: FontWeight.w700,
          ),
          onSelected: (bool value) {
            setState(() {
              if (value) {
                selectedFacilityKeys.add(key);
              } else {
                selectedFacilityKeys.remove(key);
              }
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFFFFFCF7),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

class _TrackedEnvImage {
  const _TrackedEnvImage({
    required this.slot,
    required this.path,
    required this.url,
  });

  final String slot;
  final String path;
  final String url;
}
