import 'package:petnest_saas/features/shop/widgets/shop_dashboard_navigation.dart';
// 檔案名稱：lib/features/shop/pages/shop_environment_manage_page.dart
// 功能說明：後台環境介紹管理頁

import 'dart:typed_data';
import 'dart:convert';
import 'package:petnest_saas/features/shop/widgets/environment/environment_appearance_editor.dart';
import 'package:petnest_saas/core/models/environment_presentation.dart';
import 'package:petnest_saas/features/shop/widgets/environment/environment_services_editor.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/features/shop/widgets/environment/environment_intro_view.dart';
import 'package:petnest_saas/features/shop/widgets/environment/environment_draft_preview.dart';

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
  const ShopEnvironmentManagePage({
    super.key,
    required this.shopId,
    this.loadShop,
    this.saveIntro,
  });

  final String shopId;
  final Future<Map<String, dynamic>?> Function()? loadShop;
  final Future<void> Function(Map<String, dynamic>)? saveIntro;

  @override
  State<ShopEnvironmentManagePage> createState() =>
      _ShopEnvironmentManagePageState();
}

class _ShopEnvironmentManagePageState extends State<ShopEnvironmentManagePage>
    with
        SingleTickerProviderStateMixin,
        ShopDashboardLeaveAware<ShopEnvironmentManagePage> {
  late final TabController _settingsTabs;
  List<String> _savedFacilities = [];
  HomeThemeModel _previewTheme = HomeThemeModel.classicDefault;
  EnvironmentPresentation _presentation = EnvironmentPresentation();
  EnvironmentPresentation _savedPresentation = EnvironmentPresentation();
  String _savedFeaturesSnapshot = '', _savedGallerySnapshot = '';
  String _dataSnapshot(Object? value) =>
      jsonEncode(value, toEncodable: (value) => value.toString());
  bool _inlinePreviewVisible = false;
  final _previewKey = GlobalKey<EnvironmentDraftPreviewState>();
  final Map<String, GlobalKey> _previewSections = {
    for (final id in ['features', 'care', 'gallery']) id: GlobalKey(),
  };
  String _presentationSnapshot(EnvironmentPresentation value) =>
      jsonEncode(value.toMap(), toEncodable: (value) => value.toString());
  @override
  bool get dashboardHasUnsavedChanges => _hasUnsavedImageChanges;
  @override
  bool get dashboardIsBusy => _imageBusy;
  String? _dashboardSavedText;
  String get _dashboardText => [
    heroTitleController.text,
    heroSubtitleController.text,
    bannerTitleController.text,
    bottomNoteController.text,
  ].map((value) => '${value.length}:$value').join();

  bool _loading = true;
  bool _loaded = false;
  Object? _loadError;
  int _loadRequest = 0;
  bool get _canUseDraft => _loaded && !_loading && _loadError == null;
  bool _pickingImage = false;
  bool _uploadingHeroImage = false;
  bool _uploadingBannerImage = false;
  bool _saving = false;
  String? _busyMessage;

  List<Map<String, dynamic>> environmentGalleryImages = [];
  List<Map<String, dynamic>> environmentFeatures = [];
  List<String> selectedFacilityKeys = [];

  final TextEditingController heroTitleController = TextEditingController();
  final TextEditingController heroSubtitleController = TextEditingController();
  final TextEditingController bannerTitleController = TextEditingController();
  final TextEditingController bottomNoteController = TextEditingController();

  String _heroImageUrl = '';
  String _bannerImageUrl = '';
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
    if (!_loaded) return false;
    if (!_loading &&
        (_dataSnapshot(environmentFeatures) != _savedFeaturesSnapshot ||
            _dataSnapshot(_galleryPayload()) != _savedGallerySnapshot ||
            _presentationSnapshot(_presentation) !=
                _presentationSnapshot(_savedPresentation) ||
            _dashboardSavedText != _dashboardText ||
            selectedFacilityKeys.length != _savedFacilities.length ||
            !selectedFacilityKeys.every(_savedFacilities.contains))) {
      return true;
    }
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
    _settingsTabs = TabController(length: 5, vsync: this);
    heroTitleController.addListener(_onPreviewTextChanged);
    heroSubtitleController.addListener(_onPreviewTextChanged);
    bannerTitleController.addListener(_onPreviewTextChanged);
    bottomNoteController.addListener(_onPreviewTextChanged);
    _loadEnvironmentIntro();
  }

  void _onPreviewTextChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadEnvironmentIntro() async {
    final request = ++_loadRequest;
    final shopId = widget.shopId;
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final data = widget.loadShop != null
          ? await widget.loadShop!()
          : (await FirebaseFirestore.instance
                    .collection('shops')
                    .doc(shopId)
                    .get())
                .data();
      if (!mounted || request != _loadRequest || widget.shopId != shopId) {
        return;
      }
      if (data == null) throw StateError('找不到店家資料');
      final home = data['homeAppearance'];
      if (home is Map) {
        final modern = home['modern'];
        _previewTheme = home['layout'] == 'modern'
            ? HomeThemeModel.fromMap(
                modern is Map ? modern['themeColors'] : null,
                fallback: HomeThemeModel.modernDefault,
              )
            : HomeThemeModel.fromClassicSettings(rawData: home);
      }
      final Map<String, dynamic>? environmentIntro =
          data['environmentIntro'] as Map<String, dynamic>?;

      _presentation = EnvironmentPresentation.fromMap(
        environmentIntro?['environmentPresentation'],
      );
      _savedPresentation = _presentation;
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
        _bannerImageUrl =
            (environmentIntro['bannerImageUrl'] ?? _bannerImageUrl).toString();
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
      _dashboardSavedText = _dashboardText;
      _savedFacilities = List<String>.from(selectedFacilityKeys);
      _savedFeaturesSnapshot = _dataSnapshot(environmentFeatures);
      _savedGallerySnapshot = _dataSnapshot(_galleryPayload());
      _pendingUploads.clear();
      _retiredOfficialImages.clear();

      setState(() {
        _loaded = true;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || request != _loadRequest || widget.shopId != shopId) {
        return;
      }
      setState(() {
        _loading = false;
        _loadError = error;
      });
    }
  }

  @override
  void dispose() {
    _settingsTabs.dispose();
    heroTitleController.removeListener(_onPreviewTextChanged);
    heroSubtitleController.removeListener(_onPreviewTextChanged);
    bannerTitleController.removeListener(_onPreviewTextChanged);
    bottomNoteController.removeListener(_onPreviewTextChanged);
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

  Future<bool> _deleteTrackedImage(_TrackedEnvImage image) {
    if (image.slot == 'service') {
      return ShopService.instance.tryDeleteEnvironmentFeatureImage(
        shopId: widget.shopId,
        imageStoragePath: image.path,
        imageUrl: image.url,
      );
    }
    return ShopService.instance.tryDeleteEnvironmentIntroImage(
      shopId: widget.shopId,
      imageStoragePath: image.path,
      imageUrl: image.url,
    );
  }

  Future<void> _cleanupTracked(
    _TrackedEnvImage image, {
    required String reason,
  }) async {
    final bool cleaned = await _deleteTrackedImage(image);
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
      if (image.path == _savedHeroImagePath ||
          image.path == _savedBannerImagePath ||
          _savedPresentation.services.any(
            (service) =>
                (image.path.isNotEmpty && service.imagePath == image.path) ||
                (image.url.isNotEmpty && service.imageUrl == image.url),
          )) {
        continue;
      }
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
        await _persistAuxiliarySections(section: 'galleryImages');
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
      await _persistAuxiliarySections(section: 'galleryImages');
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
                _persistAuxiliarySections(
                  section: 'features',
                  propagateError: false,
                );
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
            _persistAuxiliarySections(
              section: 'features',
              propagateError: false,
            );
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
        await _persistAuxiliarySections(section: 'features');
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
      await _persistAuxiliarySections(section: 'features');
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
      await _persistAuxiliarySections(section: 'features');
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

    await _persistAuxiliarySections(section: 'features', propagateError: false);
  }

  Future<void> _persistAuxiliarySections({
    required String section,
    bool propagateError = true,
  }) async {
    assert(section == 'features' || section == 'galleryImages');
    final payload = section == 'features'
        ? environmentFeatures
              .map((item) => Map<String, dynamic>.of(item))
              .toList()
        : _galleryPayload();
    final snapshot = _dataSnapshot(payload);
    try {
      await FirebaseFirestore.instance
          .collection('shops')
          .doc(widget.shopId)
          .update({
            'environmentIntro.$section': payload,
            'environmentIntro.updatedAt': FieldValue.serverTimestamp(),
          });
      if (mounted) {
        setState(() {
          if (section == 'features') {
            _savedFeaturesSnapshot = snapshot;
          } else {
            _savedGallerySnapshot = snapshot;
          }
        });
      }
    } catch (_) {
      if (propagateError) rethrow;
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('局部儲存失敗，草稿已保留，請使用上方儲存重試')));
      }
    }
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
      'environmentPresentation': _presentation.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  // Preserve Firestore values while detaching nested maps/lists from the draft.
  Object? _copyDraftValue(Object? value) {
    if (value is Map) {
      return <String, dynamic>{
        for (final entry in value.entries)
          entry.key as String: _copyDraftValue(entry.value),
      };
    }
    if (value is List) return value.map(_copyDraftValue).toList();
    return value;
  }

  Future<void> _save() async {
    if (!_canUseDraft || _imageBusy) {
      return;
    }

    final shopId = widget.shopId;
    final payload =
        _copyDraftValue(_environmentIntroPayload()) as Map<String, dynamic>;
    final savingText = _dashboardText;
    final savingHeroUrl = _heroImageUrl;
    final savingBannerUrl = _bannerImageUrl;
    final savingHeroPath = _heroImagePath;
    final savingBannerPath = _bannerImagePath;
    final savingHeroFrame = _heroFrame;
    final savingBannerFrame = _bannerFrame;
    final savingStyle = _style;
    final savingFeatures = List<Map<String, dynamic>>.from(
      payload['features'] as List,
    );
    final savingGallery = List<Map<String, dynamic>>.from(
      payload['galleryImages'] as List,
    );
    final savingFacilities = List<String>.from(payload['facilityKeys'] as List);
    final savingPresentation = EnvironmentPresentation.fromMap(
      payload['environmentPresentation'],
    );
    final savingPending = [..._pendingUploads];
    final savingRetired = [..._retiredOfficialImages];
    setState(() {
      _saving = true;
      _busyMessage = '正在儲存環境介紹…';
    });

    try {
      if (widget.saveIntro != null) {
        await widget.saveIntro!(payload);
      } else {
        await FirebaseFirestore.instance.collection('shops').doc(shopId).set({
          'environmentIntro': payload,
        }, SetOptions(merge: true));
      }
      if (!mounted || widget.shopId != shopId) return;

      final Set<String> usedPaths = <String>{
        if (savingHeroPath.isNotEmpty) savingHeroPath,
        if (savingBannerPath.isNotEmpty) savingBannerPath,
        ...savingPresentation.services.map((s) => s.imagePath),
        ...savingFeatures.map(_mapImagePath),
        ...savingGallery.map(_mapImagePath),
        // Retain anything also referenced by a later draft edit.
        if (_heroImagePath.isNotEmpty) _heroImagePath,
        if (_bannerImagePath.isNotEmpty) _bannerImagePath,
        ..._presentation.services.map((s) => s.imagePath),
        ...environmentFeatures.map(_mapImagePath),
        ...environmentGalleryImages.map(_mapImagePath),
      };
      final Set<String> usedUrls = <String>{
        if (savingHeroUrl.isNotEmpty) savingHeroUrl,
        if (savingBannerUrl.isNotEmpty) savingBannerUrl,
        ...savingPresentation.services.map((s) => s.imageUrl),
        ...savingFeatures.map(_mapImageUrl),
        ...savingGallery.map(_mapImageUrl),
        if (_heroImageUrl.isNotEmpty) _heroImageUrl,
        if (_bannerImageUrl.isNotEmpty) _bannerImageUrl,
        ..._presentation.services.map((s) => s.imageUrl),
        ...environmentFeatures.map(_mapImageUrl),
        ...environmentGalleryImages.map(_mapImageUrl),
      };

      bool cleanupFailed = false;
      for (final _TrackedEnvImage retired in [
        ...savingRetired,
        ...savingPending,
      ]) {
        if (!mounted || widget.shopId != shopId) return;
        if ((retired.path.isNotEmpty && usedPaths.contains(retired.path)) ||
            (retired.url.isNotEmpty && usedUrls.contains(retired.url))) {
          continue;
        }

        final bool cleaned = await _deleteTrackedImage(retired);
        if (!cleaned) {
          cleanupFailed = true;
        }
      }

      if (!mounted || widget.shopId != shopId) {
        return;
      }

      setState(() {
        _savedHeroImageUrl = savingHeroUrl;
        _savedBannerImageUrl = savingBannerUrl;
        _savedHeroImagePath = savingHeroPath;
        _savedBannerImagePath = savingBannerPath;
        _savedHeroFrame = savingHeroFrame;
        _savedBannerFrame = savingBannerFrame;
        _savedStyle = savingStyle;
        _savedPresentation = savingPresentation;
        _savedFeaturesSnapshot = _dataSnapshot(savingFeatures);
        _savedGallerySnapshot = _dataSnapshot(savingGallery);
        _dashboardSavedText = savingText;
        _savedFacilities = savingFacilities;
        _pendingUploads.removeWhere(savingPending.contains);
        _retiredOfficialImages.removeWhere(savingRetired.contains);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            cleanupFailed
                ? '設定已儲存，但舊圖片清理失敗，請稍後再試。'
                : _hasUnsavedImageChanges
                ? '這次變更已儲存，另有未儲存內容'
                : '環境介紹已儲存',
          ),
        ),
      );
    } catch (_) {
      if (!mounted || widget.shopId != shopId) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('儲存失敗，草稿已保留，請稍後重試')));
    } finally {
      if (mounted && widget.shopId == shopId) {
        setState(() {
          _saving = false;
          _busyMessage = null;
        });
      }
    }
  }

  Future<void> _onPopAttempt({required bool didPop}) async {
    if (!didPop && await dashboardConfirmLeave() && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Future<bool> dashboardConfirmLeave() async {
    if (!dashboardHasUnsavedChanges && !dashboardIsBusy) return true;

    if (_imageBusy) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_saving ? '儲存中，請稍候再離開' : '圖片處理中，請稍候再離開')),
      );
      return false;
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
      return false;
    }

    await _cleanupPendingUploads(reason: 'discard-unsaved');
    if (!mounted) {
      return false;
    }
    return true;
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
          presentation: _presentation,
          theme: _previewTheme,
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

  Widget _buildLoadError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 40),
          const SizedBox(height: 12),
          const Text('環境介紹讀取失敗', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('請確認網路連線或存取權限，再重新載入。', textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _loadEnvironmentIntro,
            icon: const Icon(Icons.refresh),
            label: const Text('重新載入'),
          ),
        ],
      ),
    ),
  );

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
    final desktop = MediaQuery.sizeOf(context).width >= 1100;
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
                bottom: desktop && !_loading
                    ? PreferredSize(
                        preferredSize: const Size.fromHeight(36),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            _hasUnsavedImageChanges ? '有未儲存變更' : '已儲存',
                          ),
                        ),
                      )
                    : null,
                backgroundColor: const Color(0xFFFFFCF7),
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                actions: [
                  TextButton(
                    onPressed: _imageBusy || !_canUseDraft
                        ? null
                        : (desktop ? _openDraftPreview : _openPreview),
                    child: Text(desktop ? '放大預覽' : '預覽'),
                  ),
                  if (desktop)
                    FilledButton(
                      onPressed: _imageBusy || !_canUseDraft ? null : _save,
                      child: Text(_saving ? '儲存中' : '儲存'),
                    )
                  else
                    TextButton(
                      onPressed: _imageBusy || !_canUseDraft ? null : _save,
                      child: Text(_saving ? '儲存中' : '儲存'),
                    ),
                ],
              ),
              body: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _loadError != null
                  ? _buildLoadError()
                  : desktop
                  ? _buildDesktopWorkspace()
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: _buildManagementChildren(),
                    ),
            ),
            _buildBusyOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _emptyDraftPreview() => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.add_photo_alternate_outlined,
            size: 56,
            color: _previewTheme.primaryColor,
          ),
          const SizedBox(height: 16),
          Text(
            '環境介紹尚未加入內容',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: _previewTheme.textColor,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '選擇範本只會調整排版。加入封面文案、環境特色、設備或相簿照片後，就會在這裡即時顯示。',
            textAlign: TextAlign.center,
            style: TextStyle(
              height: 1.6,
              color: _previewTheme.secondaryTextColor,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            key: const ValueKey<String>('environment-add-starter-copy'),
            onPressed: _imageBusy
                ? null
                : () {
                    heroTitleController.text = '歡迎參觀我們的環境';
                    heroSubtitleController.text = '在這裡介紹店內空間、照護設備與住宿環境，讓家長更安心。';
                    _settingsTabs.animateTo(1);
                  },
            icon: const Icon(Icons.edit_note),
            label: const Text('加入起始文案'),
          ),
          const SizedBox(height: 8),
          Text(
            '加入後可自行修改，按儲存才會發布。',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: _previewTheme.secondaryTextColor,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _draftContent(
    ScrollController controller, {
    Map<String, GlobalKey>? sectionKeys,
  }) {
    return ColoredBox(
      color: _previewTheme.backgroundColor,
      child: EnvironmentIntroView(
        emptyState: _emptyDraftPreview(),
        scrollController: controller,
        style: _style,
        presentation: _presentation,
        sectionKeys: sectionKeys ?? _previewSections,
        theme: _previewTheme,
        heroTitle: heroTitleController.text,
        heroSubtitle: heroSubtitleController.text,
        heroImageUrl: _heroImageUrl,
        heroFrame: _heroFrame,
        bannerTitle: bannerTitleController.text,
        bannerImageUrl: _bannerImageUrl,
        bannerFrame: _bannerFrame,
        features: environmentFeatures,
        galleryImages: environmentGalleryImages.map(_mapImageUrl).toList(),
        careItems: environmentFacilityOptions
            .where((item) => selectedFacilityKeys.contains(item['key']))
            .toList(),
        bottomNote: bottomNoteController.text,
        imageBuilder: environmentIntroNetworkImage,
        featureIconOf: environmentIntroIcon,
      ),
    );
  }

  Future<void> _openDraftPreview({String? locate}) async {
    final previewKey = GlobalKey<EnvironmentDraftPreviewState>();
    final sectionKeys = {
      for (final id in ['features', 'care', 'gallery']) id: GlobalKey(),
    };
    if (locate != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        previewKey.currentState?.reveal(sectionKeys[locate]!);
      });
    }
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(20),
        child: SizedBox(
          width: 1400,
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  tooltip: '關閉預覽',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              Expanded(
                child: EnvironmentDraftPreview(
                  key: previewKey,
                  contentBuilder: (controller) =>
                      _draftContent(controller, sectionKeys: sectionKeys),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopWorkspace() {
    final sections = _buildManagementChildren()
        .whereType<_EnvironmentSettingSection>()
        .toList();
    return LayoutBuilder(
      builder: (context, constraints) {
        final split = constraints.maxWidth >= 1100;
        _inlinePreviewVisible = split;
        final contentWidth = constraints.maxWidth.clamp(0.0, 1680.0);
        final previewWidth = (contentWidth - 68).clamp(600.0, 1680.0) * .4;
        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: contentWidth,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Keep the preview mounted when chat temporarily reduces available width.
                  SizedBox(
                    width: split ? previewWidth : 0,
                    child: Offstage(
                      offstage: !split,
                      child: OverflowBox(
                        alignment: Alignment.topLeft,
                        minWidth: previewWidth,
                        maxWidth: previewWidth,
                        child: EnvironmentDraftPreview(
                          key: _previewKey,
                          contentBuilder: _draftContent,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: split ? 20 : 0),
                  Expanded(
                    child: Column(
                      children: [
                        if (!split)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: OutlinedButton.icon(
                              onPressed: _imageBusy ? null : _openDraftPreview,
                              icon: const Icon(Icons.preview_outlined),
                              label: const Text('查看即時預覽'),
                            ),
                          ),
                        TabBar(
                          controller: _settingsTabs,
                          isScrollable: true,
                          tabAlignment: TabAlignment.start,
                          tabs: const [
                            Tab(text: '版型與樣式'),
                            Tab(text: '封面與文案'),
                            Tab(text: '環境特色'),
                            Tab(text: '設備與服務'),
                            Tab(text: '相簿與提醒'),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: TabBarView(
                            controller: _settingsTabs,
                            children: List.generate(
                              5,
                              (index) => ListView(
                                key: PageStorageKey(
                                  'environment-settings-$index',
                                ),
                                padding: EdgeInsets.zero,
                                children: [
                                  if (index == 1) _buildTipCard(),
                                  if (index == 2 || index == 4)
                                    const Padding(
                                      padding: EdgeInsets.only(bottom: 12),
                                      child: Text(
                                        '版型、文案、設備與服務需按儲存後生效；環境特色與相簿操作會立即儲存。',
                                      ),
                                    ),
                                  if (index == 0) ...[
                                    sections.firstWhere(
                                      (section) => section.tab == 0,
                                    ),
                                    sections
                                        .where((section) => section.tab == 0)
                                        .elementAt(1),
                                    _groupLabel('進階調整'),
                                    ...sections
                                        .where((section) => section.tab == 0)
                                        .skip(2),
                                  ] else
                                    ...sections.where(
                                      (section) => section.tab == index,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildManagementChildren() => [
    _buildTipCard(),
    _buildTemplateSelector(),
    _buildAppearanceSection(),
    _groupLabel('進階調整'),
    _buildSectionCard(
      settingsTab: 0,
      title: '整體顯示尺寸',
      subtitle: '調整卡片間距、圖片區塊與設備卡大小',
      children: [
        _buildChoiceChips(
          value: _style.displaySize,
          options: const <Map<String, String>>[
            {'value': EnvironmentIntroStyle.sizeCompact, 'label': '小'},
            {'value': EnvironmentIntroStyle.sizeStandard, 'label': '標準'},
            {'value': EnvironmentIntroStyle.sizeLarge, 'label': '大'},
          ],
          onSelected: (String value) {
            setState(() {
              _presentation = _presentation.copyWith({'customized': true});
              _style = _style.copyWith(displaySize: value);
            });
          },
        ),
      ],
    ),
    _buildSectionCard(
      settingsTab: 0,
      title: '環境特色卡片版型',
      subtitle: '所有特色卡使用同一種版型',
      children: [
        _buildChoiceChips(
          value: _style.cardLayout,
          options: const <Map<String, String>>[
            {'value': EnvironmentIntroStyle.layoutHorizontal, 'label': '橫向圖卡'},
            {'value': EnvironmentIntroStyle.layoutVertical, 'label': '上圖下文'},
            {'value': EnvironmentIntroStyle.layoutText, 'label': '重點文字卡'},
          ],
          onSelected: (String value) {
            setState(() {
              _presentation = _presentation.copyWith({'customized': true});
              _style = _style.copyWith(cardLayout: value);
            });
          },
        ),
      ],
    ),
    _buildSectionCard(
      settingsTab: 0,
      title: '環境特色卡片高度',
      subtitle: '調整內距與圖片大小，文字多時卡片仍會長高',
      children: [
        _buildChoiceChips(
          value: _style.cardDensity,
          options: const <Map<String, String>>[
            {'value': EnvironmentIntroStyle.densityCompact, 'label': '精簡'},
            {'value': EnvironmentIntroStyle.densityStandard, 'label': '標準'},
            {'value': EnvironmentIntroStyle.densityComfortable, 'label': '寬鬆'},
          ],
          onSelected: (String value) {
            setState(() {
              _presentation = _presentation.copyWith({'customized': true});
              _style = _style.copyWith(cardDensity: value);
            });
          },
        ),
      ],
    ),
    _groupLabel('首頁主視覺'),
    _buildSectionCard(
      settingsTab: 1,
      title: '首頁大圖文案',
      subtitle: '顯示在環境介紹頁最上方',
      children: [
        _buildTextField(
          controller: heroTitleController,
          label: '主標題',
          maxLines: 2,
        ),
        const SizedBox(height: 12),
        _buildTextField(controller: heroSubtitleController, label: '副標題'),
      ],
    ),
    _buildSectionCard(
      settingsTab: 1,
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
          onFrameChanged: (EnvironmentImageFrameSetting value) {
            setState(() {
              _heroFrame = value;
            });
          },
        ),
      ],
    ),
    _groupLabel('環境內容'),
    _buildSectionCard(
      settingsTab: 2,
      title: '環境特色卡片',
      subtitle: '顯示在前台「我們的環境特色」區塊',
      children: [
        _locateButton('features'),
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
            _persistAuxiliarySections(
              section: 'features',
              propagateError: false,
            );
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
      settingsTab: 3,
      title: '安心設備與貼心服務',
      subtitle: '勾選後會顯示在前台設備區塊',
      children: [
        _locateButton('care'),
        EnvironmentServicesEditor(
          selectedKeys: selectedFacilityKeys,
          presentation: _presentation,
          busy: _imageBusy,
          iconOf: environmentIntroIcon,
          onSelected: (keys) => setState(() {
            selectedFacilityKeys = keys;
            _presentation = _presentation.copyWith({'groupFacilities': true});
          }),
          onChanged: _setPresentation,
          onUpload: _uploadServiceImage,
          onRemoveImage: _removeServiceImage,
          onDelete: _deleteService,
        ),
      ],
    ),
    _groupLabel('其他內容'),
    _buildSectionCard(
      settingsTab: 1,
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
      settingsTab: 1,
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
          onUpload: () => _pickAndUploadImage(type: 'banner'),
          onDelete: () => _removeSlotImage(type: 'banner'),
          onFrameChanged: (EnvironmentImageFrameSetting value) {
            setState(() {
              _bannerFrame = value;
            });
          },
        ),
      ],
    ),
    _buildSectionCard(
      settingsTab: 4,
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
      settingsTab: 4,
      title: '環境照片牆',
      subtitle: '顯示在環境介紹主要內容最下方，最多 12 張',
      children: [
        _locateButton('gallery'),
        EnvironmentGalleryManager(
          images: environmentGalleryImages.map(_mapImageUrl).toList(),
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
  ];

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
        '版型、文案、設備與服務需按儲存後生效；環境特色與相簿操作會立即儲存。大圖、橫幅與自訂服務照片會先上傳暫存，儲存成功後才發布並清理不再使用的舊圖。',
        style: TextStyle(
          height: 1.5,
          color: Color(0xFF6F5A43),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required int settingsTab,
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return _EnvironmentSettingSection(
      tab: settingsTab,
      child: Container(
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
      ),
    );
  }

  void _setPresentation(EnvironmentPresentation value) {
    setState(() => _presentation = value.copyWith({'customized': true}));
  }

  Widget _locateButton(String section) => Align(
    alignment: Alignment.centerRight,
    child: TextButton.icon(
      onPressed: () => _locatePreview(section),
      icon: const Icon(Icons.my_location, size: 18),
      label: const Text('定位預覽'),
    ),
  );

  Future<void> _locatePreview(String section) async {
    final shown = switch (section) {
      'features' => environmentFeatures.isNotEmpty,
      'gallery' => environmentGalleryImages.isNotEmpty,
      _ =>
        environmentFacilityOptions.any(
              (item) =>
                  selectedFacilityKeys.contains(item['key']) &&
                  !_presentation.hiddenFacilityKeys.contains(item['key']),
            ) ||
            _presentation.services.any((s) => s.visible),
    };
    if (!shown) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('此區塊目前沒有顯示內容')));
      return;
    }
    if (!_inlinePreviewVisible || _previewKey.currentState == null) {
      await _openDraftPreview(locate: section);
      return;
    }
    await _previewKey.currentState!.reveal(_previewSections[section]!);
  }

  Widget _buildAppearanceSection() => _buildSectionCard(
    settingsTab: 0,
    title: '整頁外觀',
    subtitle: '只套用環境介紹；儲存後才更新正式內容。',
    children: [
      EnvironmentAppearanceEditor(
        appearance: _presentation.appearance,
        theme: _previewTheme,
        busy: _imageBusy,
        onChanged: (value) => _setPresentation(
          _presentation.copyWith({'appearance': value.toMap()}),
        ),
        fontSizeControl: _buildChoiceChips(
          value: _style.fontSize,
          options: const <Map<String, String>>[
            {'value': EnvironmentIntroStyle.fontSmall, 'label': '小'},
            {'value': EnvironmentIntroStyle.fontStandard, 'label': '標準'},
            {'value': EnvironmentIntroStyle.fontLarge, 'label': '大'},
          ],
          onSelected: (String value) {
            setState(() {
              _presentation = _presentation.copyWith({'customized': true});
              _style = _style.copyWith(fontSize: value);
            });
          },
        ),
      ),
    ],
  );

  Widget _buildTemplateSelector() => _buildSectionCard(
    settingsTab: 0,
    title: '整頁快速範本',
    subtitle: _presentation.preset.isEmpty
        ? '目前沿用原有版面；選擇範本不會變更文案或照片。'
        : '${EnvironmentPresentation.presets[_presentation.preset]}${_presentation.customized ? '・已自訂' : ''}（儲存後生效）',
    children: [
      LayoutBuilder(
        builder: (context, constraints) {
          // Keep two usable cards on common phone widths instead of leaving half
          // of the section empty. Very narrow containers keep a single column.
          final available = constraints.maxWidth;
          final cardWidth =
              (available >= 250 ? (available - 10) / 2 : available)
                  .clamp(0.0, 150.0)
                  .toDouble();
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final preset in EnvironmentPresentation.presets.entries)
                SizedBox(
                  width: cardWidth,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.all(10),
                      side: BorderSide(
                        color: _presentation.preset == preset.key
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey.shade300,
                      ),
                    ),
                    onPressed: _imageBusy
                        ? null
                        : () => setState(() {
                            _presentation = _presentation.applyPreset(
                              preset.key,
                            );
                            _style = _style.copyWith(
                              displaySize: preset.key == 'minimal'
                                  ? 'compact'
                                  : 'standard',
                              cardLayout: preset.key == 'photo'
                                  ? 'vertical'
                                  : 'horizontal',
                              cardDensity: preset.key == 'minimal'
                                  ? 'compact'
                                  : 'comfortable',
                            );
                          }),
                    child: Column(
                      children: [
                        EnvironmentTemplateThumbnail(preset: preset.key),
                        const SizedBox(height: 6),
                        Text(preset.value),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    ],
  );

  void _retireServicePhoto(EnvironmentServiceCard service) {
    if (service.imageUrl.isEmpty && service.imagePath.isEmpty) return;
    _trackRetiredOfficial(
      slot: 'service',
      path: service.imagePath,
      url: service.imageUrl,
    );
  }

  void _removeServiceImage(String id) {
    if (_imageBusy) return;
    final services = _presentation.services;
    final index = services.indexWhere((s) => s.id == id);
    if (index < 0) return;
    _retireServicePhoto(services[index]);
    services[index] = services[index].copyWith({
      'imageUrl': '',
      'imageStoragePath': '',
    });
    _setPresentation(
      _presentation.copyWith({
        'customServices': services.map((s) => s.toMap()).toList(),
      }),
    );
  }

  Future<void> _deleteService(String id) async {
    if (_imageBusy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('刪除自訂服務？'),
        content: const Text('按儲存後才會從正式內容移除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('刪除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final services = _presentation.services;
    final index = services.indexWhere((s) => s.id == id);
    if (index < 0) return;
    _retireServicePhoto(services.removeAt(index));
    _setPresentation(
      _presentation.copyWith({
        'customServices': services.map((s) => s.toMap()).toList(),
      }),
    );
  }

  Future<void> _uploadServiceImage(String id) async {
    if (_imageBusy) return;
    setState(() {
      _pickingImage = true;
      _busyMessage = '選擇服務照片…';
    });
    try {
      final image = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (image == null || !mounted) return;
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      if (bytes.isEmpty || bytes.length > _maxImageBytes) {
        _showImageError('單張圖片須為有效圖片，且不超過 5 MB');
        return;
      }
      final cropped = await FixedAspectImageCropPage.open(
        context: context,
        imageBytes: bytes,
        spec: FixedImageSpec.environmentFeature,
        title: '裁切服務照片',
      );
      if (cropped == null || !mounted) return;
      if (cropped.isEmpty || cropped.length > _maxImageBytes) {
        _showImageError('處理後的圖片不可超過 5 MB');
        return;
      }
      setState(() => _busyMessage = '正在上傳服務照片…');
      final uploaded = await ShopService.instance.uploadEnvironmentFeatureImage(
        shopId: widget.shopId,
        bytes: cropped,
      );
      final tracked = _TrackedEnvImage(
        slot: 'service',
        path: uploaded.imageStoragePath,
        url: uploaded.imageUrl,
      );
      if (!mounted) {
        await _cleanupTracked(tracked, reason: 'closed-service-upload');
        return;
      }
      _pendingUploads.add(tracked);
      final services = _presentation.services;
      final index = services.indexWhere((s) => s.id == id);
      if (index < 0) return;
      _retireServicePhoto(services[index]);
      services[index] = services[index].copyWith({
        'imageUrl': uploaded.imageUrl,
        'imageStoragePath': uploaded.imageStoragePath,
      });
      _setPresentation(
        _presentation.copyWith({
          'customServices': services.map((s) => s.toMap()).toList(),
        }),
      );
    } catch (_) {
      _showImageError('服務照片處理失敗，請稍後再試');
    } finally {
      if (mounted) {
        setState(() {
          _pickingImage = false;
          _busyMessage = null;
        });
      }
    }
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

// 設定分類僅用於桌機分頁；手機仍沿用原本順序。
class _EnvironmentSettingSection extends StatelessWidget {
  const _EnvironmentSettingSection({required this.tab, required this.child});
  final int tab;
  final Widget child;
  @override
  Widget build(BuildContext context) => child;
}
