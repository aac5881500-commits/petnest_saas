// 檔案名稱：lib/features/auth/pages/shop_media_page.dart
// 說明：店家媒體設定頁
//
// 功能：
// - 上傳 Logo
// - 上傳封面
// - 限制 Logo 最大 3MB
// - 限制封面最大 5MB
// - 顯示上傳中狀態與結果提示

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:petnest_saas/core/services/shop_service.dart';

class ShopMediaPage extends StatefulWidget {
  const ShopMediaPage({
    super.key,
    required this.shopId,
  });

  final String shopId;

  @override
  State<ShopMediaPage> createState() => _ShopMediaPageState();
}

class _ShopMediaPageState extends State<ShopMediaPage> {
  bool _uploadingLogo = false;
  bool _uploadingCover = false;

  static const int _maxLogoBytes = 3 * 1024 * 1024; // 3MB
  static const int _maxCoverBytes = 5 * 1024 * 1024; // 5MB

  Future<void> _pickAndUploadLogo() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);

    if (file == null) return;

    setState(() {
      _uploadingLogo = true;
    });

    try {
      final Uint8List bytes = await file.readAsBytes();

      if (bytes.length > _maxLogoBytes) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logo 圖片太大，請小於 3MB')),
        );
        return;
      }

      await ShopService.instance.uploadShopLogo(
        shopId: widget.shopId,
        bytes: bytes,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logo 上傳成功')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logo 上傳失敗：$e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _uploadingLogo = false;
        });
      }
    }
  }

  Future<void> _pickAndUploadCover() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);

    if (file == null) return;

    setState(() {
      _uploadingCover = true;
    });

    try {
      final Uint8List bytes = await file.readAsBytes();

      if (bytes.length > _maxCoverBytes) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('封面圖片太大，請小於 5MB')),
        );
        return;
      }

      await ShopService.instance.uploadShopCover(
        shopId: widget.shopId,
        bytes: bytes,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('封面上傳成功')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('封面上傳失敗：$e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _uploadingCover = false;
        });
      }
    }
  }

  Widget _buildUploadButton({
    required String title,
    required bool loading,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        child: Text(loading ? '$title 上傳中...' : '選擇$title'),
      ),
    );
  }

  Widget _buildHintCard({
    required String title,
    required String desc,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        '$title\n$desc',
        style: const TextStyle(height: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isUploading = _uploadingLogo || _uploadingCover;

    return Scaffold(
      appBar: AppBar(
        title: const Text('店家封面 / Logo'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHintCard(
            title: 'Logo 建議',
            desc: '建議使用正方形圖片，檔案小於 3MB。',
          ),
          const SizedBox(height: 12),
          _buildUploadButton(
            title: 'Logo',
            loading: _uploadingLogo,
            onPressed: _pickAndUploadLogo,
          ),
          const SizedBox(height: 24),
          _buildHintCard(
            title: '封面建議',
            desc: '建議使用橫式圖片，檔案小於 5MB。',
          ),
          const SizedBox(height: 12),
          _buildUploadButton(
            title: '封面',
            loading: _uploadingCover,
            onPressed: _pickAndUploadCover,
          ),
          const SizedBox(height: 24),
          if (isUploading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}