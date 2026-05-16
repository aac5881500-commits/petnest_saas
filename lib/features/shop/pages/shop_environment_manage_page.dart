// lib/features/shop/pages/shop_environment_manage_page.dart
// 🐾 後台環境介紹管理頁
// 第一版先做 UI，不接 Firebase，之後再儲存到店家資料

import 'package:flutter/material.dart';
import 'package:petnest_saas/features/shop/pages/shop_environment_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:petnest_saas/features/shop/widgets/environment/environment_gallery_manager.dart';
import 'package:petnest_saas/features/shop/widgets/environment/environment_image_upload_box.dart';
import 'package:petnest_saas/features/shop/widgets/environment/environment_feature_manager.dart';
import 'package:petnest_saas/features/shop/widgets/environment/environment_icon_picker_dialog.dart';
import 'package:petnest_saas/features/shop/data/environment_facility_options.dart';


class ShopEnvironmentManagePage extends StatefulWidget {
  const ShopEnvironmentManagePage({
    super.key,
    required this.shopId,
  });

  final String shopId;

  @override
  State<ShopEnvironmentManagePage> createState() =>
      _ShopEnvironmentManagePageState();
}

class _ShopEnvironmentManagePageState extends State<ShopEnvironmentManagePage> {
    bool _loading = true;
      List<String> environmentGalleryImages = [];
        List<Map<String, dynamic>> environmentFeatures = [];
          List<String> selectedFacilityKeys = [
    'air_cleaner',
    'camera_24h',
    'hospital',
    'water',
    'sunlight',
    'disinfect',
  ];
      bool _uploadingHeroImage = false;
  bool _uploadingBannerImage = false;
  final heroTitleController = TextEditingController(
    text: '讓每一隻貓咪\n都能像在家一樣放鬆',
  );

  final heroSubtitleController = TextEditingController(
    text: '安心・舒適・乾淨的貓咪住宿空間',
  );

  final bannerTitleController = TextEditingController(
    text: '用心打造每一個細節\n只為給貓咪更好的住宿體驗',
  );

  final bottomNoteController = TextEditingController(
    text: '每隻貓咪個性不同，實際住宿安排會依照貓咪狀況與店家現場評估調整。',
  );
    final heroImageUrlController = TextEditingController(
    text: 'https://images.unsplash.com/photo-1519052537078-e6302a4968d4?w=1200',
  );

  final bannerImageUrlController = TextEditingController(
    text: 'https://images.unsplash.com/photo-1518791841217-8f162f1e1131?w=1000',
  );

  @override
  void initState() {
    super.initState();
    _loadEnvironmentIntro();
  }

  Future<void> _loadEnvironmentIntro() async {
    final doc = await FirebaseFirestore.instance
        .collection('shops')
        .doc(widget.shopId)
        .get();

    final data = doc.data();
    final environmentIntro =
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
                heroImageUrlController.text =
          environmentIntro['heroImageUrl'] ?? heroImageUrlController.text;
      bannerImageUrlController.text =
          environmentIntro['bannerImageUrl'] ?? bannerImageUrlController.text;
                environmentGalleryImages =
          List<String>.from(environmentIntro['galleryImages'] ?? []);
                environmentFeatures =
          List<Map<String, dynamic>>.from(environmentIntro['features'] ?? []);
                selectedFacilityKeys =
          List<String>.from(environmentIntro['facilityKeys'] ?? selectedFacilityKeys);
    }

    if (!mounted) return;
    setState(() {
      _loading = false;
    });
  }
  @override
  void dispose() {
    heroTitleController.dispose();
    heroSubtitleController.dispose();
    bannerTitleController.dispose();
    bottomNoteController.dispose();
        heroImageUrlController.dispose();
    bannerImageUrlController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage({
    required String type,
  }) async {
    final picker = ImagePicker();

    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );

    if (image == null) return;

    setState(() {
      if (type == 'hero') {
        _uploadingHeroImage = true;
      } else {
        _uploadingBannerImage = true;
      }
    });

    try {
           final bytes = await image.readAsBytes();

      const maxImageSize = 5 * 1024 * 1024; // 5MB

      if (bytes.length > maxImageSize) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('圖片太大，請選擇 5MB 以下的圖片'),
          ),
        );
        return;
      }

      final filePath = 'shops/${widget.shopId}/environment/$type.jpg';

      final ref = FirebaseStorage.instance.ref(filePath);

      await ref.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final downloadUrl = await ref.getDownloadURL();

      if (type == 'hero') {
        heroImageUrlController.text = downloadUrl;
      } else {
        bannerImageUrlController.text = downloadUrl;
      }

      await _save();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('圖片已上傳')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('圖片上傳失敗：$e')),
      );
    } finally {
      if (!mounted) return;

      setState(() {
        _uploadingHeroImage = false;
        _uploadingBannerImage = false;
      });
    }
  }

  Future<void> _pickAndUploadGalleryImage() async {
    if (environmentGalleryImages.length >= 12) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('環境照片最多上傳 12 張')),
      );
      return;
    }

    final picker = ImagePicker();

    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );

    if (image == null) return;

    try {
      final bytes = await image.readAsBytes();

      const maxImageSize = 5 * 1024 * 1024; // 5MB

      if (bytes.length > maxImageSize) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('圖片太大，請選擇 5MB 以下的圖片')),
        );
        return;
      }

      final index = environmentGalleryImages.length;

      final filePath =
          'shops/${widget.shopId}/environment/gallery_$index.jpg';

      final ref = FirebaseStorage.instance.ref(filePath);

      await ref.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final downloadUrl = await ref.getDownloadURL();

      setState(() {
        environmentGalleryImages.add(downloadUrl);
      });

      await _save();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('環境照片已上傳')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('環境照片上傳失敗：$e')),
      );
    }
  }

    Future<void> _deleteGalleryImage(int index) async {
    if (index < 0 || index >= environmentGalleryImages.length) return;

    final imageUrl = environmentGalleryImages[index];

    try {
      await FirebaseStorage.instance
          .refFromURL(imageUrl)
          .delete();
    } catch (e) {
      debugPrint('刪除 Storage 圖片失敗：$e');
    }

    setState(() {
      environmentGalleryImages.removeAt(index);
    });

    await _save();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('環境照片已刪除')),
    );
  }

  Future<void> _editFeature(int index) async {
    if (index < 0 || index >= environmentFeatures.length) return;

    final item = environmentFeatures[index];

    final titleController = TextEditingController(
      text: item['title'] ?? '',
    );

    final descriptionController = TextEditingController(
      text: item['description'] ?? '',
    );

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('編輯環境特色'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: '特色標題',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: '特色說明',
                ),
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

                _save();
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
    if (index < 0 || index >= environmentFeatures.length) return;

    await showDialog(
      context: context,
      builder: (context) {
        return EnvironmentIconPickerDialog(
          onSelect: (selectedKey) {
            setState(() {
              environmentFeatures[index] = {
                ...environmentFeatures[index],
                'icon': selectedKey,
              };
            });

            _save();
          },
        );
      },
    );
  }

  Future<void> _pickAndUploadFeatureImage(int index) async {
    if (index < 0 || index >= environmentFeatures.length) return;

    final picker = ImagePicker();

    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 85,
    );

    if (image == null) return;

    try {
      final bytes = await image.readAsBytes();

      const maxImageSize = 5 * 1024 * 1024;

      if (bytes.length > maxImageSize) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('圖片太大，請選擇 5MB 以下的圖片')),
        );
        return;
      }

      final filePath =
          'shops/${widget.shopId}/environment/features/feature_$index.jpg';

      final ref = FirebaseStorage.instance.ref(filePath);

      await ref.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final downloadUrl = await ref.getDownloadURL();

      setState(() {
        environmentFeatures[index] = {
          ...environmentFeatures[index],
          'imageUrl': downloadUrl,
        };
      });

      await _save();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('特色圖片已上傳')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('特色圖片上傳失敗：$e')),
      );
    }
  }

  Future<void> _save() async {
  await FirebaseFirestore.instance
      .collection('shops')
      .doc(widget.shopId)
      .set({
    'environmentIntro': {
      'heroTitle': heroTitleController.text.trim(),
      'heroSubtitle': heroSubtitleController.text.trim(),
      'bannerTitle': bannerTitleController.text.trim(),
      'bottomNote': bottomNoteController.text.trim(),
      'heroImageUrl': heroImageUrlController.text.trim(),
      'bannerImageUrl': bannerImageUrlController.text.trim(),
      'galleryImages': environmentGalleryImages,
      'features': environmentFeatures,
      'facilityKeys': selectedFacilityKeys,
      'updatedAt': FieldValue.serverTimestamp(),
    },
  }, SetOptions(merge: true));

  if (!mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('環境介紹已儲存')),
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFCF7),
      appBar: AppBar(
        title: const Text('環境介紹管理'),
        backgroundColor: const Color(0xFFFFFCF7),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: [
  TextButton(
    onPressed: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ShopEnvironmentPage(
  shopId: widget.shopId,
  heroTitle: heroTitleController.text,
  heroSubtitle: heroSubtitleController.text,
  bannerTitle: bannerTitleController.text,
  bottomNote: bottomNoteController.text,
),
        ),
      );
    },
    child: const Text('預覽'),
  ),
  TextButton(
    onPressed: _save,
    child: const Text('儲存'),
  ),
],
      ),
            body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildTipCard(),

          const SizedBox(height: 16),

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
            title: '圖片設定',
            subtitle: '店主可從後台上傳環境介紹圖片',
            children: [
              EnvironmentImageUploadBox(
                title: '首頁大圖',
                imageUrl: heroImageUrlController.text,
                uploading: _uploadingHeroImage,
                onUpload: () => _pickAndUploadImage(type: 'hero'),
              ),
              const SizedBox(height: 16),
              EnvironmentImageUploadBox(
                title: '中間橫幅圖',
                imageUrl: bannerImageUrlController.text,
                uploading: _uploadingBannerImage,
                onUpload: () => _pickAndUploadImage(type: 'banner'),
              ),
            ],
          ),

          const SizedBox(height: 16),

          _buildSectionCard(
            title: '環境照片牆',
            subtitle: '最多可上傳 12 張，會顯示在前台環境照片區',
            children: [
              EnvironmentGalleryManager(
  images: environmentGalleryImages,
  onDelete: _deleteGalleryImage,
  onUpload: _pickAndUploadGalleryImage,
),
            ],
          ),
          
          const SizedBox(height: 16),

          _buildSectionCard(
            title: '環境特色卡片',
            subtitle: '顯示在前台「我們的環境特色」區塊',
            children: [
              EnvironmentFeatureManager(
  features: environmentFeatures,
  onAdd: () {
    setState(() {
      environmentFeatures.add({
        'icon': 'home',
        'title': '新的環境特色',
        'description': '請輸入環境特色說明',
        'imageUrl': '',
      });
    });
    _save();
  },
  onEdit: _editFeature,
  onUploadImage: _pickAndUploadFeatureImage,
  onChangeIcon: _changeFeatureIcon,
  onDelete: (index) {
    setState(() {
      environmentFeatures.removeAt(index);
    });
    _save();
  },
),
            ],
          ),

          const SizedBox(height: 16),

          _buildSectionCard(
            title: '安心照護設備',
            subtitle: '勾選後會顯示在前台設備區塊',
            children: [
              _buildFacilitySelector(),
            ],
          ),

          const SizedBox(height: 16),

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

          const SizedBox(height: 16),

          _buildSectionCard(
            title: '底部提醒文字',
            subtitle: '顯示在環境介紹頁最下方',
            children: [
              _buildTextField(
                controller: bottomNoteController,
                label: '提醒文字',
                maxLines: 3,
              ),
            ],
          ),

          const SizedBox(height: 28),

          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_rounded),
              label: const Text('儲存環境介紹'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1DD),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFD7A8)),
      ),
      child: const Text(
        '圖片會自動壓縮並限制 5MB 以下，重新上傳會覆蓋原本圖片。',
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
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF8A6A45),
            ),
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
      children: environmentFacilityOptions.map((item) {
        final key = item['key'] as String;

        final selected = selectedFacilityKeys.contains(key);

        return FilterChip(
          label: Text(item['title']),
          selected: selected,
          avatar: Icon(
            item['icon'] as IconData,
            size: 18,
            color: selected
                ? Colors.white
                : const Color(0xFFB87535),
          ),
          selectedColor: const Color(0xFFB87535),
          checkmarkColor: Colors.white,
          labelStyle: TextStyle(
            color: selected
                ? Colors.white
                : const Color(0xFF3A2A1A),
            fontWeight: FontWeight.w700,
          ),
          onSelected: (value) {
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
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}