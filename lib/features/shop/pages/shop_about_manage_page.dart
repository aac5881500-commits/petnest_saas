// lib/features/shop/pages/shop_about_manage_page.dart
// 🐾 後台關於我們管理頁
// 店家可編輯前台關於我們的標題、簡介與品牌文字，並設定封面圖顯示範圍

import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:petnest_saas/core/models/about_cover_frame_setting.dart';
import 'package:petnest_saas/core/models/fixed_image_spec.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/services/shop_profile_service.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/features/shop/pages/shop_about_page.dart';
import 'package:petnest_saas/features/shop/widgets/about/about_cover_image_box.dart';
import 'package:petnest_saas/features/shop/widgets/media/fixed_aspect_image_crop_page.dart';
import 'package:petnest_saas/features/shop/widgets/media/fixed_image_spec_hint.dart';

class ShopAboutManagePage extends StatefulWidget {
  const ShopAboutManagePage({super.key, required this.shopId});

  final String shopId;

  @override
  State<ShopAboutManagePage> createState() => _ShopAboutManagePageState();
}

class _ShopAboutManagePageState extends State<ShopAboutManagePage> {
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

  _TrackedAboutImage? _pendingCover;
  _TrackedAboutImage? _retiredOfficial;

  static const int _maxImageBytes = 5 * 1024 * 1024;

  bool get _imageBusy => _pickingImage || _uploadingImage || _saving;

  bool get _hasUnsavedChanges {
    if (_pendingCover != null || _retiredOfficial != null) {
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
    super.dispose();
  }

  void _onDraftChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadAboutData() async {
    final DocumentSnapshot<Map<String, dynamic>> doc = await FirebaseFirestore
        .instance
        .collection('shops')
        .doc(widget.shopId)
        .get();

    final Map<String, dynamic> data = doc.data() ?? <String, dynamic>{};

    _titleController.text = (data['aboutTitle'] ?? '用心照顧每一隻貓咪，讓牠們在這裡安心生活。')
        .toString();
    _descriptionController.text =
        (data['aboutDescription'] ??
                '我們相信，每一隻貓咪都是家人。當您需要暫時離開時，我們會像您一樣，用心陪伴與照顧。')
            .toString();
    _messageController.text =
        (data['aboutMessage'] ??
                '出門在外，最放心不下的就是毛孩。我們會用耐心觀察、溫柔陪伴，讓牠們在這裡慢慢放鬆，也讓您每一次出門都能更放心。')
            .toString();

    _aboutImageUrl = (data['aboutImageUrl'] ?? '').toString().trim();
    _aboutImagePath = (data['aboutImageStoragePath'] ?? '').toString().trim();
    _frame = AboutCoverFrameSetting.fromMap(data);

    _savedTitle = _titleController.text;
    _savedDescription = _descriptionController.text;
    _savedMessage = _messageController.text;
    _savedAboutImageUrl = _aboutImageUrl;
    _savedAboutImagePath = _aboutImagePath;
    _savedFrame = _frame;
    _pendingCover = null;
    _retiredOfficial = null;

    if (!mounted) {
      return;
    }
    setState(() {
      _loading = false;
    });
  }

  bool _isPendingCurrent() {
    final _TrackedAboutImage? pending = _pendingCover;
    if (pending == null) {
      return false;
    }
    if (_aboutImagePath.isNotEmpty && pending.path == _aboutImagePath) {
      return true;
    }
    return _aboutImageUrl.isNotEmpty && pending.url == _aboutImageUrl;
  }

  bool _isOfficialImage(String path, String url) {
    if (path.isNotEmpty && path == _savedAboutImagePath) {
      return true;
    }
    if (url.isNotEmpty && url == _savedAboutImageUrl) {
      return true;
    }
    return false;
  }

  void _trackRetiredOfficial({required String path, required String url}) {
    if (path.isEmpty && url.isEmpty) {
      return;
    }
    final _TrackedAboutImage? current = _retiredOfficial;
    if (current != null &&
        ((path.isNotEmpty && current.path == path) ||
            (url.isNotEmpty && current.url == url))) {
      return;
    }
    _retiredOfficial = _TrackedAboutImage(path: path, url: url);
  }

  Future<void> _cleanupTracked(
    _TrackedAboutImage image, {
    required String reason,
  }) async {
    final bool cleaned = await ShopService.instance.tryDeleteAboutCoverImage(
      shopId: widget.shopId,
      imageStoragePath: image.path,
      imageUrl: image.url,
    );
    if (!cleaned) {
      debugPrint(
        'About cover leftover after $reason: path=${image.path} url=${image.url}',
      );
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
        _busyMessage = '正在處理圖片…';
      });

      await Future<void>.delayed(const Duration(milliseconds: 50));
      if (!mounted) {
        return;
      }

      final Uint8List? croppedBytes = await FixedAspectImageCropPage.open(
        context: context,
        imageBytes: originalBytes,
        spec: FixedImageSpec.aboutCover,
        title: '裁切關於我們封面',
      );

      if (croppedBytes == null || !mounted) {
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
      if (!mounted) {
        return;
      }

      setState(() {
        _busyMessage = '正在上傳圖片…';
      });

      final ShopAboutCoverImageUpload uploaded = await ShopService.instance
          .uploadAboutCoverImage(shopId: widget.shopId, bytes: croppedBytes);

      if (!mounted) {
        await ShopService.instance.tryDeleteAboutCoverImage(
          shopId: widget.shopId,
          imageStoragePath: uploaded.imageStoragePath,
          imageUrl: uploaded.imageUrl,
        );
        return;
      }

      final String previousUrl = _aboutImageUrl;
      final String previousPath = _aboutImagePath;

      if (_isPendingCurrent()) {
        final _TrackedAboutImage? replaced = _pendingCover;
        _pendingCover = null;
        if (replaced != null) {
          await _cleanupTracked(replaced, reason: 'replaced-pending');
        }
      } else if (_isOfficialImage(previousPath, previousUrl)) {
        _trackRetiredOfficial(path: previousPath, url: previousUrl);
      }

      _pendingCover = _TrackedAboutImage(
        path: uploaded.imageStoragePath,
        url: uploaded.imageUrl,
      );

      setState(() {
        _aboutImageUrl = uploaded.imageUrl;
        _aboutImagePath = uploaded.imageStoragePath;
      });
    } catch (_) {
      _showImageError('圖片處理失敗，請重新選擇圖片。');
    } finally {
      if (mounted) {
        setState(() {
          _pickingImage = false;
          _uploadingImage = false;
          _busyMessage = null;
        });
      }
    }
  }

  Future<void> _removeAboutImage() async {
    if (_imageBusy || (_aboutImageUrl.isEmpty && _aboutImagePath.isEmpty)) {
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('移除自訂封面圖'),
          content: const Text('移除後將恢復使用系統預設封面。自訂圖片也會從伺服器中刪除。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('移除並恢復預設'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final String previousUrl = _aboutImageUrl;
    final String previousPath = _aboutImagePath;
    final bool removingPending = _isPendingCurrent();
    final _TrackedAboutImage? pending = _pendingCover;
    final _TrackedAboutImage officialToDelete =
        _retiredOfficial ??
        (removingPending
            ? _TrackedAboutImage(
                path: _savedAboutImagePath,
                url: _savedAboutImageUrl,
              )
            : _TrackedAboutImage(path: previousPath, url: previousUrl));

    setState(() {
      _pickingImage = true;
      _busyMessage = '正在移除圖片…';
    });

    try {
      await FirebaseFirestore.instance
          .collection('shops')
          .doc(widget.shopId)
          .set({
            'aboutImageUrl': '',
            'aboutImageStoragePath': '',
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      if (removingPending && pending != null) {
        await _cleanupTracked(pending, reason: 'removed-unsaved');
      }

      final bool hasOfficial =
          officialToDelete.path.isNotEmpty || officialToDelete.url.isNotEmpty;
      bool cleaned = true;
      if (hasOfficial &&
          (officialToDelete.path != pending?.path ||
              officialToDelete.url != pending?.url)) {
        cleaned = await ShopService.instance.tryDeleteAboutCoverImage(
          shopId: widget.shopId,
          imageStoragePath: officialToDelete.path,
          imageUrl: officialToDelete.url,
        );
        if (!cleaned) {
          debugPrint(
            'About cover leftover after remove: '
            'path=${officialToDelete.path} url=${officialToDelete.url}',
          );
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _aboutImageUrl = '';
        _aboutImagePath = '';
        _savedAboutImageUrl = '';
        _savedAboutImagePath = '';
        _pendingCover = null;
        _retiredOfficial = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(cleaned ? '已恢復系統預設封面' : '照片已移除，但舊圖片清理失敗，請稍後再試。'),
        ),
      );
    } catch (_) {
      _showImageError('儲存失敗，請稍後再試');
    } finally {
      if (mounted) {
        setState(() {
          _pickingImage = false;
          _busyMessage = null;
        });
      }
    }
  }

  Future<void> _saveAboutData() async {
    if (_saving || _pickingImage || _uploadingImage) {
      return;
    }

    setState(() {
      _saving = true;
      _busyMessage = '正在儲存…';
    });

    try {
      await FirebaseFirestore.instance
          .collection('shops')
          .doc(widget.shopId)
          .set({
            'aboutTitle': _titleController.text.trim(),
            'aboutDescription': _descriptionController.text.trim(),
            'aboutMessage': _messageController.text.trim(),
            'aboutImageUrl': _aboutImageUrl,
            'aboutImageStoragePath': _aboutImagePath,
            ..._frame.toMap(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      bool cleanupFailed = false;
      final _TrackedAboutImage? retired = _retiredOfficial;
      if (retired != null &&
          retired.path != _aboutImagePath &&
          retired.url != _aboutImageUrl) {
        final bool cleaned = await ShopService.instance
            .tryDeleteAboutCoverImage(
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
        _savedTitle = _titleController.text;
        _savedDescription = _descriptionController.text;
        _savedMessage = _messageController.text;
        _savedAboutImageUrl = _aboutImageUrl;
        _savedAboutImagePath = _aboutImagePath;
        _savedFrame = _frame;
        _pendingCover = null;
        _retiredOfficial = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(cleanupFailed ? '設定已儲存，但舊圖片清理失敗，請稍後再試。' : '關於我們已儲存'),
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
          _busyMessage = null;
        });
      }
    }
  }

  Future<void> _cleanupPendingUploads({required String reason}) async {
    final _TrackedAboutImage? pending = _pendingCover;
    _pendingCover = null;
    if (pending != null) {
      await _cleanupTracked(pending, reason: reason);
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
        builder: (_) => ShopAboutPage(
          shopId: widget.shopId,
          theme: HomeThemeModel.classicDefault,
          previewTitle: _titleController.text,
          previewDescription: _descriptionController.text,
          previewMessage: _messageController.text,
          previewImageUrl: _aboutImageUrl,
          previewFrame: _frame,
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
                    child: const Text('預覽'),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: _imageBusy ? null : _saveAboutData,
                    child: Text(_saving ? '儲存中' : '儲存'),
                  ),
                ],
              ),
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1DD),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFFD7A8)),
                    ),
                    child: const Text(
                      '這裡設定的內容會顯示在前台「關於我們」頁面，建議以品牌故事、照顧理念、給飼主的話為主，避免和環境介紹重複。',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.6,
                        color: Color(0xFF6A4A24),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _sectionTitle('關於我們封面圖'),
                  const FixedImageSpecHint(spec: FixedImageSpec.aboutCover),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: AboutCoverImageBox(
                      imageUrl: _aboutImageUrl,
                      frame: _frame,
                      uploading: _uploadingImage,
                      busy: _imageBusy,
                      overlayTitle: _titleController.text,
                      overlaySubtitle: _descriptionController.text,
                      onUpload: _pickAndUploadAboutImage,
                      onDelete: _removeAboutImage,
                      onFrameChanged: (AboutCoverFrameSetting value) {
                        setState(() {
                          _frame = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  _sectionTitle('主標題'),
                  _inputBox(
                    controller: _titleController,
                    hint: '例如：用心照顧每一隻貓咪，讓牠們在這裡安心生活。',
                    maxLines: 3,
                  ),
                  const SizedBox(height: 20),
                  _sectionTitle('簡介文字'),
                  _inputBox(
                    controller: _descriptionController,
                    hint: '簡單介紹店家的理念與照顧方式',
                    maxLines: 5,
                  ),
                  const SizedBox(height: 20),
                  _sectionTitle('給毛爸媽的話'),
                  _inputBox(
                    controller: _messageController,
                    hint: '可以寫給飼主的一段溫暖文字',
                    maxLines: 8,
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _imageBusy ? null : _saveAboutData,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC47A2C),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: Text(
                        _saving ? '儲存中...' : '儲存關於我們',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
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
  const _TrackedAboutImage({required this.path, required this.url});

  final String path;
  final String url;
}
