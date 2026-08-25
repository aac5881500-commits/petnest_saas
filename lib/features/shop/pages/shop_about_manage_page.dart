// lib/features/shop/pages/shop_about_manage_page.dart
// 🐾 後台關於我們管理頁
// 店家可編輯前台關於我們的標題、簡介與品牌文字

import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/features/shop/pages/shop_about_page.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';

class ShopAboutManagePage extends StatefulWidget {
  const ShopAboutManagePage({super.key, required this.shopId});

  final String shopId;

  @override
  State<ShopAboutManagePage> createState() => _ShopAboutManagePageState();
}

class _ShopAboutManagePageState extends State<ShopAboutManagePage> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _messageController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _hasEdited = false;
  bool _uploadingImage = false;
  String _aboutImageUrl = '';

  static const int _maxImageBytes = 5 * 1024 * 1024;

  @override
  void initState() {
    super.initState();
    _loadAboutData();
    _titleController.addListener(_onEdited);
    _descriptionController.addListener(_onEdited);
    _messageController.addListener(_onEdited);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadAboutData() async {
    final doc = await FirebaseFirestore.instance
        .collection('shops')
        .doc(widget.shopId)
        .get();

    final data = doc.data() ?? {};

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

    _aboutImageUrl = (data['aboutImageUrl'] ?? '').toString();

    if (!mounted) return;
    setState(() {
      _loading = false;
    });
  }

  void _onEdited() {
    if (_hasEdited) return;

    setState(() {
      _hasEdited = true;
    });
  }

  Future<void> _pickAndUploadAboutImage() async {
    final picker = ImagePicker();

    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );

    if (file == null) return;

    setState(() {
      _uploadingImage = true;
    });

    try {
      final Uint8List originalBytes = await file.readAsBytes();

      final decoded = img.decodeImage(originalBytes);

      if (decoded == null) {
        throw Exception('圖片格式不支援，請使用 JPG 或 PNG');
      }

      final resized = img.copyResize(decoded, width: 1200);

      final jpg = img.encodeJpg(resized, quality: 85);
      final bytes = Uint8List.fromList(jpg);

      if (bytes.length > _maxImageBytes) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('圖片需小於 5MB')));
        return;
      }

      if (_aboutImageUrl.isNotEmpty) {
        await ShopService.instance.deleteImageByUrl(_aboutImageUrl);
      }

      final url = await ShopService.instance.uploadShopCover(
        shopId: widget.shopId,
        bytes: bytes,
      );

      if (!mounted) return;

      setState(() {
        _aboutImageUrl = url;
        _hasEdited = true;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('上傳失敗：$e')));
    } finally {
      if (!mounted) return;

      setState(() {
        _uploadingImage = false;
      });
    }
  }

  Future<void> _saveAboutData() async {
    if (_saving) return;

    setState(() {
      _saving = true;
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
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      if (!mounted) return;

      setState(() {
        _hasEdited = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('關於我們已儲存')));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('儲存失敗：$e')));
    } finally {
      if (!mounted) return;

      setState(() {
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return PopScope(
      canPop: !_hasEdited,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final shouldLeave = await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('尚未儲存'),
              content: const Text('你有尚未儲存的修改，確定要離開嗎？'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('繼續編輯'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('離開'),
                ),
              ],
            );
          },
        );

        if (shouldLeave == true && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFFFCF7),
        appBar: AppBar(
          backgroundColor: const Color(0xFFFFFCF7),
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          title: const Text(
            '關於我們管理',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFF3A2A1A),
            ),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              tooltip: '前台預覽',
              icon: const Icon(Icons.visibility),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ShopAboutPage(
                      shopId: widget.shopId,
                      theme: HomeThemeModel.classicDefault,
                    ),
                  ),
                );
              },
            ),
            TextButton(
              onPressed: _saving ? null : _saveAboutData,
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

            _sectionTitle('關於我們封面圖'),

            const SizedBox(height: 8),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_aboutImageUrl.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Image.network(_aboutImageUrl, fit: BoxFit.cover),
                      ),
                    )
                  else
                    Container(
                      height: 160,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF1DD),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text(
                        '尚未上傳封面圖',
                        style: TextStyle(
                          color: Color(0xFF8A6A45),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),

                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _uploadingImage
                          ? null
                          : _pickAndUploadAboutImage,
                      icon: _uploadingImage
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.image),
                      label: Text(_uploadingImage ? '上傳中...' : '上傳 / 更換封面圖'),
                    ),
                  ),
                ],
              ),
            ),

            if (_aboutImageUrl.isNotEmpty) ...[
              const SizedBox(height: 10),

              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () async {
                    final shouldDelete = await showDialog<bool>(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          title: const Text('刪除封面圖'),
                          content: const Text('確定要刪除這張封面圖嗎？'),
                          actions: [
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context, false);
                              },
                              child: const Text('取消'),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context, true);
                              },
                              child: const Text('刪除'),
                            ),
                          ],
                        );
                      },
                    );

                    if (shouldDelete != true) return;

                    try {
                      await ShopService.instance.deleteImageByUrl(
                        _aboutImageUrl,
                      );

                      setState(() {
                        _aboutImageUrl = '';
                        _hasEdited = true;
                      });

                      if (!mounted) return;

                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(const SnackBar(content: Text('封面圖已刪除')));
                    } catch (e) {
                      if (!mounted) return;

                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('刪除失敗：$e')));
                    }
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('刪除封面圖'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                ),
              ),
            ],

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
                onPressed: _saving ? null : _saveAboutData,
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
