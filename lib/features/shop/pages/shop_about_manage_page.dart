import 'dart:async';
import 'dart:convert';
import 'package:petnest_saas/core/models/about_page_setting.dart';
import '../widgets/about/about_intro_view.dart';
import '../widgets/about/about_media.dart';
import '../widgets/about/about_items_editor.dart';
import '../widgets/about/about_appearance_editor.dart';
import '../widgets/environment/environment_draft_preview.dart';
import '../widgets/shop_room_type_workspace.dart';
import 'package:petnest_saas/features/shop/widgets/shop_dashboard_navigation.dart';
// 檔案名稱：lib/features/shop/pages/shop_about_manage_page.dart
// 功能說明：後台關於我們管理頁
// 店家可編輯前台關於我們的標題、簡介與品牌文字，並設定封面圖顯示範圍

import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:petnest_saas/core/models/about_cover_frame_setting.dart';
import 'package:petnest_saas/core/models/fixed_image_spec.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/services/shop_profile_service.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/features/shop/widgets/about/about_cover_image_box.dart';
import 'package:petnest_saas/features/shop/widgets/media/fixed_aspect_image_crop_page.dart';

class ShopAboutManagePage extends StatefulWidget {
  const ShopAboutManagePage({
    super.key,
    required this.shopId,
    this.shopStream,
    this.saveAbout,
  });

  final String shopId;
  final Stream<Map<String, dynamic>?>? shopStream;
  final Future<void> Function(Map<String, dynamic>)? saveAbout;

  @override
  State<ShopAboutManagePage> createState() => _ShopAboutManagePageState();
}

class _ShopAboutManagePageState extends State<ShopAboutManagePage>
    with ShopDashboardLeaveAware<ShopAboutManagePage> {
  @override
  bool get dashboardHasUnsavedChanges => _hasUnsavedChanges;
  @override
  bool get dashboardIsBusy => _imageBusy;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _pickingImage = false;
  bool _uploadingImage = false;
  String? _busyMessage;

  String _aboutImageUrl = '';
  String _aboutImagePath = '';
  AboutCoverFrameSetting _frame = const AboutCoverFrameSetting();

  String _savedTitle = '';
  String _savedDescription = '';
  String _savedMessage = '';
  String _savedAboutImageUrl = '';
  String _savedAboutImagePath = '';
  AboutCoverFrameSetting _savedFrame = const AboutCoverFrameSetting();

  final _pendingImages = <_TrackedAboutImage>[];
  AboutPageSetting _setting = AboutPageSetting(),
      _savedSetting = AboutPageSetting();
  Map<String, dynamic> _shop = {};
  StreamSubscription<Map<String, dynamic>?>? _shopSubscription;
  Object? _loadError;
  bool _preview = false, _seeded = false;
  int _tab = 0;

  static const int _maxImageBytes = 5 * 1024 * 1024;

  bool get _imageBusy => _pickingImage || _uploadingImage || _saving;

  bool get _hasUnsavedChanges {
    if (_pendingImages.isNotEmpty ||
        jsonEncode(_setting.toMap()) != jsonEncode(_savedSetting.toMap())) {
      return true;
    }
    return _titleController.text != _savedTitle ||
        _descriptionController.text != _savedDescription ||
        _messageController.text != _savedMessage ||
        _aboutImageUrl != _savedAboutImageUrl ||
        _aboutImagePath != _savedAboutImagePath ||
        _frame.imageFit != _savedFrame.imageFit ||
        _frame.imageAlignment != _savedFrame.imageAlignment ||
        _frame.heightPreset != _savedFrame.heightPreset;
  }

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_onDraftChanged);
    _descriptionController.addListener(_onDraftChanged);
    _messageController.addListener(_onDraftChanged);
    _loadAboutData();
  }

  @override
  void dispose() {
    _titleController.removeListener(_onDraftChanged);
    _descriptionController.removeListener(_onDraftChanged);
    _messageController.removeListener(_onDraftChanged);
    _titleController.dispose();
    _descriptionController.dispose();
    _messageController.dispose();
    _shopSubscription?.cancel();
    super.dispose();
  }

  void _onDraftChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _loadAboutData() {
    final shopId = widget.shopId;
    _shopSubscription?.cancel();
    _shopSubscription =
        (widget.shopStream ?? ShopService.instance.streamShop(shopId)).listen(
          (data) {
            if (!mounted || widget.shopId != shopId) return;
            if (data == null) {
              setState(() {
                _loading = false;
                _loadError = '找不到店家';
              });
              return;
            }
            _shop = data;
            if (!_seeded) {
              _titleController.text = (data['aboutTitle'] ?? '').toString();
              _descriptionController.text = (data['aboutDescription'] ?? '')
                  .toString();
              _messageController.text = (data['aboutMessage'] ?? '').toString();
              _aboutImageUrl = (data['aboutImageUrl'] ?? '').toString().trim();
              _setting = AboutPageSetting.fromShop(data);
              _aboutImagePath =
                  (_setting.toMap()['uploadedCoverStoragePath'] ??
                          data['aboutImageStoragePath'] ??
                          '')
                      .toString()
                      .trim();
              _frame = _setting.coverFrame(data);
              _captureSaved();
              _seeded = true;
            }
            setState(() {
              _loading = false;
              _loadError = null;
            });
          },
          onError: (Object error) {
            if (mounted && widget.shopId == shopId) {
              setState(() {
                _loading = false;
                _loadError = error;
              });
            }
          },
        );
  }

  void _captureSaved() {
    _savedTitle = _titleController.text;
    _savedDescription = _descriptionController.text;
    _savedMessage = _messageController.text;
    _savedAboutImageUrl = _aboutImageUrl;
    _savedAboutImagePath = _aboutImagePath;
    _savedFrame = _frame;
    _savedSetting = _setting;
  }

  void _restoreSaved() {
    _titleController.text = _savedTitle;
    _descriptionController.text = _savedDescription;
    _messageController.text = _savedMessage;
    _aboutImageUrl = _savedAboutImageUrl;
    _aboutImagePath = _savedAboutImagePath;
    _frame = _savedFrame;
    _setting = _savedSetting;
  }

  @override
  void didUpdateWidget(covariant ShopAboutManagePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shopId != widget.shopId) {
      // 舊店儲存結果尚未確認時不刪檔，避免移除剛正式引用的上傳圖。
      if (_saving) {
        _pendingImages.clear();
      } else {
        _cleanupPendingUploads(reason: 'switch-shop');
      }
      _saving = false;
      _pickingImage = false;
      _uploadingImage = false;
      _busyMessage = null;
      _seeded = false;
      _loading = true;
      _shop = {};
      _loadError = null;
      _loadAboutData();
    }
  }

  Future<void> _cleanupTracked(
    _TrackedAboutImage image, {
    required String reason,
  }) async {
    try {
      final bool cleaned = await ShopService.instance.tryDeleteAboutCoverImage(
        shopId: image.shopId,
        imageStoragePath: image.path,
        imageUrl: image.url,
      );
      if (!cleaned) {
        debugPrint(
          'About cover leftover after $reason: path=${image.path} url=${image.url}',
        );
      }
    } catch (error) {
      debugPrint('About pending image cleanup failed: $error');
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

  Future<void> _pickAndUploadAboutImage() async {
    if (_imageBusy) {
      return;
    }

    final operationShopId = widget.shopId;
    setState(() {
      _pickingImage = true;
      _uploadingImage = true;
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

      if (file == null || (!mounted || widget.shopId != operationShopId)) {
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

      if ((!mounted || widget.shopId != operationShopId)) {
        return;
      }

      setState(() {
        _busyMessage = '正在處理圖片…';
      });

      await Future<void>.delayed(const Duration(milliseconds: 50));
      if ((!mounted || widget.shopId != operationShopId)) {
        return;
      }

      final Uint8List? croppedBytes = await FixedAspectImageCropPage.open(
        context: context,
        imageBytes: originalBytes,
        spec: FixedImageSpec.aboutCover,
        title: '裁切關於我們封面',
      );

      if (croppedBytes == null ||
          (!mounted || widget.shopId != operationShopId)) {
        return;
      }
      if (croppedBytes.length > _maxImageBytes) {
        _showImageError('單張圖片最大 5 MB，請換一張較小的照片');
        return;
      }

      setState(() {
        _busyMessage = '正在套用圖片設定…';
      });
      await Future<void>.delayed(const Duration(milliseconds: 50));
      if ((!mounted || widget.shopId != operationShopId)) {
        return;
      }

      setState(() {
        _busyMessage = '正在上傳圖片…';
      });

      final ShopAboutCoverImageUpload uploaded = await ShopService.instance
          .uploadAboutCoverImage(shopId: operationShopId, bytes: croppedBytes);

      if ((!mounted || widget.shopId != operationShopId)) {
        await ShopService.instance.tryDeleteAboutCoverImage(
          shopId: operationShopId,
          imageStoragePath: uploaded.imageStoragePath,
          imageUrl: uploaded.imageUrl,
        );
        return;
      }

      _pendingImages.add(
        _TrackedAboutImage(
          path: uploaded.imageStoragePath,
          url: uploaded.imageUrl,
          shopId: operationShopId,
        ),
      );
      _setting = _setting.copyWith({
        'cover': const AboutMedia(source: 'legacy').toMap(),
        'uploadedCoverStoragePath': uploaded.imageStoragePath,
      });
      setState(() {
        _aboutImageUrl = uploaded.imageUrl;
        _aboutImagePath = uploaded.imageStoragePath;
      });
    } catch (_) {
      _showImageError('圖片處理失敗，請重新選擇圖片。');
    } finally {
      if (mounted && widget.shopId == operationShopId) {
        setState(() {
          _pickingImage = false;
          _uploadingImage = false;
          _busyMessage = null;
        });
      }
    }
  }

  Future<void> _removeAboutImage() async {
    if (_imageBusy) return;
    setState(() {
      _aboutImageUrl = '';
      _aboutImagePath = '';
      _setting = _setting.copyWith({
        'cover': const AboutMedia().toMap(),
        'uploadedCoverStoragePath': '',
      });
    });
  }

  Future<AboutMedia?> _uploadContentPhoto() async {
    if (_imageBusy) return null;
    final shopId = widget.shopId;
    setState(() {
      _pickingImage = true;
      _busyMessage = '正在上傳圖片…';
    });
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 2400,
        maxHeight: 2400,
        imageQuality: 92,
      );
      if (file == null || !mounted || widget.shopId != shopId) return null;
      final bytes = await file.readAsBytes();
      if (bytes.length > _maxImageBytes) {
        _showImageError('單張圖片最大 5 MB');
        return null;
      }
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        _showImageError('圖片格式無法讀取，請改用 JPG 或 PNG');
        return null;
      }
      final jpeg = Uint8List.fromList(
        img.encodeJpg(img.bakeOrientation(decoded), quality: 90),
      );
      if (jpeg.length > _maxImageBytes) {
        _showImageError('圖片處理後超過 5 MB，請換較小的照片');
        return null;
      }
      final uploaded = await ShopService.instance.uploadAboutCoverImage(
        shopId: shopId,
        bytes: jpeg,
      );
      final tracked = _TrackedAboutImage(
        path: uploaded.imageStoragePath,
        url: uploaded.imageUrl,
        shopId: shopId,
      );
      if (!mounted || widget.shopId != shopId) {
        await _cleanupTracked(tracked, reason: 'late-upload');
        return null;
      }
      _pendingImages.add(tracked);
      return AboutMedia(source: 'shop', url: uploaded.imageUrl);
    } catch (_) {
      _showImageError('圖片上傳失敗，請稍後重試');
      return null;
    } finally {
      if (mounted && widget.shopId == shopId) {
        setState(() {
          _pickingImage = false;
          _busyMessage = null;
        });
      }
    }
  }

  Future<void> _saveAboutData() async {
    if (_imageBusy || !_seeded || !_hasUnsavedChanges || _loadError != null) {
      return;
    }
    final shopId = widget.shopId;
    final savingTitle = _titleController.text;
    final savingDescription = _descriptionController.text;
    final savingMessage = _messageController.text;
    final savingImageUrl = _aboutImageUrl;
    final savingImagePath = _aboutImagePath;
    final savingFrame = _frame;
    final savingSetting = AboutPageSetting.fromMap(
      jsonDecode(jsonEncode(_setting.toMap())),
    );
    final pending = [..._pendingImages];
    setState(() {
      _saving = true;
      _busyMessage = '正在儲存…';
    });
    try {
      final next = <String, dynamic>{
        'aboutTitle': savingTitle.trim(),
        'aboutDescription': savingDescription.trim(),
        'aboutMessage': savingMessage.trim(),
        'aboutImageUrl': savingImageUrl,
      };
      final old = <String, dynamic>{
        'aboutTitle': _savedTitle.trim(),
        'aboutDescription': _savedDescription.trim(),
        'aboutMessage': _savedMessage.trim(),
        'aboutImageUrl': _savedAboutImageUrl,
      };
      final updates = <String, dynamic>{
        for (final e in next.entries)
          if (e.value != old[e.key]) e.key: e.value,
      };
      updates.addAll(aboutPageUpdates(_savedSetting, savingSetting));
      if (updates.isNotEmpty) {
        if (widget.saveAbout != null) {
          await widget.saveAbout!(updates);
        } else {
          await FirebaseFirestore.instance
              .collection('shops')
              .doc(shopId)
              .update({...updates, 'updatedAt': FieldValue.serverTimestamp()});
        }
      }
      if (!mounted || widget.shopId != shopId) return;
      final stored = jsonEncode({
        'cover': savingImageUrl,
        'setting': savingSetting.toMap(),
      });
      _pendingImages.removeWhere(pending.contains);
      // Only the submitted snapshot was saved. A focused text input may still
      // receive keyboard input while pointer interaction is blocked.
      _savedTitle = savingTitle;
      _savedDescription = savingDescription;
      _savedMessage = savingMessage;
      _savedAboutImageUrl = savingImageUrl;
      _savedAboutImagePath = savingImagePath;
      _savedFrame = savingFrame;
      _savedSetting = savingSetting;
      for (final image in pending) {
        if (!stored.contains(jsonEncode(image.url))) {
          await _cleanupTracked(image, reason: 'saved-unused');
        }
      }
      if (!mounted || widget.shopId != shopId) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_hasUnsavedChanges ? '這次變更已儲存，另有未儲存內容' : '關於我們已儲存'),
        ),
      );
    } catch (_) {
      if (mounted && widget.shopId == shopId) {
        _showImageError('儲存失敗，草稿已保留，請確認權限或稍後重試');
      }
    } finally {
      if (mounted && widget.shopId == shopId) {
        setState(() {
          _saving = false;
          _busyMessage = null;
        });
      }
    }
  }

  Future<void> _cleanupPendingUploads({required String reason}) async {
    final pending = [..._pendingImages];
    _pendingImages.clear();
    for (final image in pending) {
      await _cleanupTracked(image, reason: reason);
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
          actions: [
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
    if (mounted) setState(_restoreSaved);
    if (!mounted) {
      return false;
    }
    return true;
  }

  Map<String, dynamic> get _draftShop => {
    ..._shop,
    '_aboutMediaPhotos': [
      for (final section in ['stories', 'principles', 'team', 'credentials'])
        for (final item in _setting.items(section))
          if (item.image.source == 'shop' && item.image.url.isNotEmpty)
            item.image.url,
      for (final image in _pendingImages) image.url,
    ],
    'aboutTitle': _titleController.text,
    'aboutDescription': _descriptionController.text,
    'aboutMessage': _messageController.text,
    'aboutImageUrl': _aboutImageUrl,
    ..._frame.toMap(),
  };
  HomeThemeModel get _previewTheme =>
      AboutPageSetting.shopTheme(_shop, HomeThemeModel.classicDefault);
  Widget _previewPane() => EnvironmentDraftPreview(
    notice: '所有變更均為草稿，按儲存後才會更新正式內容。',
    contentBuilder: (scroll) => AboutIntroView(
      shop: _draftShop,
      setting: _setting,
      theme: _previewTheme,
      scrollController: scroll,
      preview: true,
    ),
  );
  void _openPreview() => showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      child: SizedBox(
        width: 1200,
        height: MediaQuery.sizeOf(context).height * .9,
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                tooltip: '關閉放大預覽',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ),
            Expanded(child: _previewPane()),
          ],
        ),
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
    if (_loadError != null && !_seeded) {
      return Scaffold(
        appBar: AppBar(title: const Text('關於我們管理')),
        body: Center(
          child: TextButton(
            onPressed: () {
              setState(() => _loading = true);
              _loadAboutData();
            },
            child: const Text('資料讀取失敗，點此重試'),
          ),
        ),
      );
    }
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return PopScope(
      canPop: !_imageBusy && !_hasUnsavedChanges,
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
                backgroundColor: const Color(0xFFFFFCF7),
                elevation: 0,
                surfaceTintColor: Colors.transparent,
                title: const Text(
                  '關於我們管理',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF3A2A1A),
                  ),
                ),
                actions: [
                  TextButton(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: _imageBusy ? null : _openPreview,
                    child: const Text('放大預覽'),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed:
                        _imageBusy || _loadError != null || !_hasUnsavedChanges
                        ? null
                        : _saveAboutData,
                    child: Text(_saving ? '儲存中' : '儲存'),
                  ),
                ],
              ),
              body: _workspace(),
            ),
            _buildBusyOverlay(),
          ],
        ),
      ),
    );
  }

  void _changeSetting(AboutPageSetting next) => setState(() => _setting = next);
  Widget _workspace() => ShopRoomTypeWorkspace(
    preview: _previewPane(),
    showPreview: _preview,
    onPreviewChanged: (v) => setState(() => _preview = v),
    editLabel: '編輯',
    previewLabel: '預覽',
    editor: IgnorePointer(
      ignoring: _imageBusy,
      child: DefaultTabController(
        length: 4,
        child: Column(
          children: [
            if (_loadError != null)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    const Expanded(child: Text('店家資料更新失敗，草稿已保留。')),
                    TextButton(
                      onPressed: _loadAboutData,
                      child: const Text('重試'),
                    ),
                  ],
                ),
              ),
            TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              onTap: (v) => setState(() => _tab = v),
              tabs: const [
                Tab(text: '介紹內容'),
                Tab(text: '照片素材'),
                Tab(text: '理念與團隊'),
                Tab(text: '排版外觀'),
              ],
            ),
            Expanded(
              child: IndexedStack(
                index: _tab,
                children: [
                  _settingsScroll('content', [
                    const ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.storefront_outlined),
                      title: Text('店家資訊固定顯示'),
                      subtitle: Text('電話、地址、營業時間與許可字號自動引用基本資料。可在「排版外觀」選擇呈現方式。'),
                    ),
                    const Text('填寫品牌介紹與服務特色，左側可即時預覽；儲存後才會更新前台。'),
                    _sectionTitle('主標題'),
                    _inputBox(
                      controller: _titleController,
                      hint: '例如品牌名稱或你的照護理念（選填）',
                      maxLines: 3,
                    ),
                    _sectionTitle('簡介'),
                    _inputBox(
                      controller: _descriptionController,
                      hint: '簡單介紹店家、照護方式與經營理念',
                      maxLines: 5,
                    ),
                    _sectionTitle('完整介紹／給毛孩爸媽的話'),
                    _inputBox(
                      controller: _messageController,
                      hint: '分享創店故事、照顧方式與希望傳達的真實內容',
                      maxLines: 8,
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('長介紹使用展開閱讀'),
                      value: _setting.expandable,
                      onChanged: (v) =>
                          _changeSetting(_setting.copyWith({'expandable': v})),
                    ),
                    AboutItemsEditor(
                      section: 'highlights',
                      items: _setting.items('highlights'),
                      shop: _draftShop,
                      onChanged: (items) => _changeSetting(
                        _setting.withItems('highlights', items),
                      ),
                      onUpload: _uploadContentPhoto,
                    ),
                    const Text('可填寫實際提供的房型設備、陪伴方式或清潔安排。空白特色不會顯示。'),
                    AboutItemsEditor(
                      section: 'stories',
                      items: _setting.items('stories'),
                      shop: _draftShop,
                      onChanged: (items) =>
                          _changeSetting(_setting.withItems('stories', items)),
                      onUpload: _uploadContentPhoto,
                    ),
                  ]),
                  _settingsScroll('photos', [
                    _sectionTitle('介紹封面來源'),
                    AboutMediaField(
                      value: _setting.cover,
                      shop: _draftShop,
                      onChanged: (image) => _changeSetting(
                        _setting.copyWith({'cover': image.toMap()}),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () => _changeSetting(
                          _setting.copyWith({
                            'cover': const AboutMedia(source: 'legacy').toMap(),
                          }),
                        ),
                        child: const Text('使用原有關於我們封面'),
                      ),
                    ),
                    const Text('下方保留原有封面上傳、裁切與顯示範圍。移除只解除本頁引用，不刪除已儲存圖片。'),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 320),
                        child: AboutCoverImageBox(
                          showHeightSetting: _setting.layout == 'classic',
                          imageUrl: _aboutImageUrl,
                          frame: _frame,
                          uploading: _uploadingImage,
                          busy: _imageBusy,
                          overlayTitle: _titleController.text,
                          overlaySubtitle: _descriptionController.text,
                          onUpload: _pickAndUploadAboutImage,
                          onDelete: _removeAboutImage,
                          onFrameChanged: (value) => setState(() {
                            _frame = value;
                            _setting = _setting.copyWith({
                              'coverFrame': value.toMap(),
                            });
                          }),
                        ),
                      ),
                    ),
                    _sectionTitle('介紹配圖比例'),
                    const Text('套用於分段配圖與新版封面；原有排版的封面沿用上方高度選項。'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        for (final e in const {
                          'square': '正方形',
                          'landscape': '4:3',
                          'wide': '16:9',
                        }.entries)
                          ChoiceChip(
                            label: Text(e.value),
                            selected:
                                _setting.choice('imageRatio', [
                                  'square',
                                  'landscape',
                                  'wide',
                                ], 'landscape') ==
                                e.key,
                            onSelected: (_) => _changeSetting(
                              _setting.withAppearance({'imageRatio': e.key}),
                            ),
                          ),
                      ],
                    ),
                    const Text('故事與理念的個別配圖在各內容項目內設定；人物及證照只能使用真實店家素材。'),
                  ]),
                  _settingsScroll('people', [
                    for (final section in [
                      'principles',
                      'team',
                      'credentials',
                    ]) ...[
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          '顯示${AboutPageSetting.sectionNames[section]}',
                        ),
                        value: _setting.visible(section),
                        onChanged: (v) =>
                            _changeSetting(_setting.setVisible(section, v)),
                      ),
                      AboutItemsEditor(
                        section: section,
                        items: _setting.items(section),
                        shop: _draftShop,
                        onChanged: (items) =>
                            _changeSetting(_setting.withItems(section, items)),
                        onUpload: _uploadContentPhoto,
                      ),
                      const SizedBox(height: 20),
                    ],
                    if ('${_shop['licenseNumber'] ?? ''}'.trim().isNotEmpty)
                      Text(
                        '已引用基本資料的公開許可字號：${_shop['licenseNumber']}。不需在經歷重複輸入。',
                      ),
                    _sectionTitle('各區塊顯示與順序'),
                    for (var i = 0; i < _setting.sectionOrder.length; i++)
                      Row(
                        children: [
                          Expanded(
                            child: SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                AboutPageSetting.sectionNames[_setting
                                    .sectionOrder[i]]!,
                              ),
                              value: _setting.visible(_setting.sectionOrder[i]),
                              subtitle: _setting.sectionOrder[i] == 'contact'
                                  ? const Text('固定顯示，可調整順序')
                                  : null,
                              onChanged: _setting.sectionOrder[i] == 'contact'
                                  ? null
                                  : (v) => _changeSetting(
                                      _setting.setVisible(
                                        _setting.sectionOrder[i],
                                        v,
                                      ),
                                    ),
                            ),
                          ),
                          IconButton(
                            tooltip: '區塊上移',
                            onPressed: i > 0
                                ? () => _moveSection(i, i - 1)
                                : null,
                            icon: const Icon(Icons.arrow_upward),
                          ),
                          IconButton(
                            tooltip: '區塊下移',
                            onPressed: i + 1 < _setting.sectionOrder.length
                                ? () => _moveSection(i, i + 1)
                                : null,
                            icon: const Icon(Icons.arrow_downward),
                          ),
                        ],
                      ),
                  ]),
                  _settingsScroll('appearance', [
                    AboutAppearanceEditor(
                      setting: _setting,
                      theme: _previewTheme,
                      onChanged: _changeSetting,
                    ),
                  ]),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(_hasUnsavedChanges ? '有未儲存變更' : '已儲存'),
                    ),
                    FilledButton(
                      onPressed:
                          _hasUnsavedChanges &&
                              !_imageBusy &&
                              _loadError == null
                          ? _saveAboutData
                          : null,
                      child: Text(_saving ? '儲存中…' : '儲存'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  Widget _settingsScroll(String id, List<Widget> children) => ListView(
    key: PageStorageKey<String>('about-settings-$id'),
    padding: const EdgeInsets.all(16),
    children: [
      for (final child in children)
        Padding(padding: const EdgeInsets.only(bottom: 16), child: child),
    ],
  );
  void _moveSection(int from, int to) {
    final order = _setting.sectionOrder;
    order.insert(to, order.removeAt(from));
    _changeSetting(_setting.copyWith({'sectionOrder': order}));
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: Color(0xFF3A2A1A),
        ),
      ),
    );
  }

  Widget _inputBox({
    required TextEditingController controller,
    required String hint,
    required int maxLines,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.all(16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
      ),
    );
  }
}

class _TrackedAboutImage {
  const _TrackedAboutImage({
    required this.path,
    required this.url,
    required this.shopId,
  });

  final String shopId;
  final String path;
  final String url;
}
