// 檔案名稱：lib/features/auth/pages/my_shop_card_media_page.dart
// 功能說明：上傳平台首頁「我的店家卡片」專用大圖與 Logo
// 🖼️ 我的店家卡片圖片設定頁
// 注意：這裡不影響店家前台 coverUrl / logoUrl

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:petnest_saas/core/services/shop_card_media_service.dart';

class MyShopCardMediaPage extends StatefulWidget {
  const MyShopCardMediaPage({super.key, required this.shopId});

  final String shopId;

  @override
  State<MyShopCardMediaPage> createState() => _MyShopCardMediaPageState();
}

class _MyShopCardMediaPageState extends State<MyShopCardMediaPage> {
  bool _uploadingCover = false;
  bool _uploadingLogo = false;

  Future<void> _pickAndUploadCover() async {
    await _pickAndUpload(isCover: true);
  }

  Future<void> _pickAndUploadLogo() async {
    await _pickAndUpload(isCover: false);
  }

  Future<void> _pickAndUpload({required bool isCover}) async {
    try {
      final picker = ImagePicker();

      final file = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: isCover ? 1600 : 600,
      );

      if (file == null) return;

      final bytes = await file.readAsBytes();

      if (bytes.lengthInBytes > ShopCardMediaService.maxImageBytes) {
        if (!mounted) return;

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('圖片不可超過 5MB')));
        return;
      }

      setState(() {
        if (isCover) {
          _uploadingCover = true;
        } else {
          _uploadingLogo = true;
        }
      });

      if (isCover) {
        await ShopCardMediaService.instance.uploadPlatformHomeCover(
          shopId: widget.shopId,
          bytes: bytes,
        );
      } else {
        await ShopCardMediaService.instance.uploadPlatformHomeLogo(
          shopId: widget.shopId,
          bytes: bytes,
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(isCover ? '大圖已更新' : 'Logo 已更新')));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('上傳失敗：$e')));
    } finally {
      if (!mounted) return;

      setState(() {
        if (isCover) {
          _uploadingCover = false;
        } else {
          _uploadingLogo = false;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('店家卡片圖片')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _UploadCard(
            title: '我的店家卡片大圖',
            subtitle: '顯示在平台首頁「我的店家」卡片上方，不影響店家前台封面。',
            icon: Icons.image,
            uploading: _uploadingCover,
            onTap: _pickAndUploadCover,
          ),

          const SizedBox(height: 12),

          _UploadCard(
            title: '我的店家卡片 Logo',
            subtitle: '顯示在平台首頁「我的店家」卡片內，不影響店家前台 Logo。',
            icon: Icons.account_circle,
            uploading: _uploadingLogo,
            onTap: _pickAndUploadLogo,
          ),

          const SizedBox(height: 16),

          Text(
            '圖片限制：單張不可超過 5MB。上傳新圖後，系統會自動刪除舊圖並更新資料。',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }
}

class _UploadCard extends StatelessWidget {
  const _UploadCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.uploading,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool uploading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: uploading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.chevron_right),
        onTap: uploading ? null : onTap,
      ),
    );
  }
}
