// 檔案名稱：lib/features/booking/pages/booking_review_page.dart
// 功能說明：讓會員針對已完成訂單新增評價
// ⭐ 訂單評價頁

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/review_service.dart';
import 'package:petnest_saas/core/models/review_model.dart';
import 'package:petnest_saas/features/booking/widgets/review_rating_stars.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:typed_data';

class BookingReviewPage extends StatefulWidget {
  const BookingReviewPage({super.key, required this.bookingId, this.review});

  final String bookingId;
  final ReviewModel? review;

  @override
  State<BookingReviewPage> createState() => _BookingReviewPageState();
}

class _BookingReviewPageState extends State<BookingReviewPage> {
  final TextEditingController _contentController = TextEditingController();

  int _rating = 5;
  int _environmentRating = 5;
  int _serviceRating = 5;
  int _priceRating = 5;

  bool _submitting = false;
  final List<XFile> _pickedImages = [];
  final List<String> _existingImageUrls = [];
  final ImagePicker _picker = ImagePicker();
  bool get _isEditing => widget.review != null;

  @override
  void initState() {
    super.initState();

    final review = widget.review;
    if (review != null) {
      _contentController.text = review.content;
      _rating = review.rating;
      _environmentRating = review.environmentRating;
      _serviceRating = review.serviceRating;
      _priceRating = review.priceRating;
      _existingImageUrls.addAll(review.imageUrls);
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    if (_submitting) return;

    final remainCount = 5 - _existingImageUrls.length - _pickedImages.length;

    if (remainCount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('評價照片最多 5 張')));
      return;
    }

    final images = await _picker.pickMultiImage(
      maxWidth: 1200,
      imageQuality: 75,
    );

    if (images.isEmpty) return;

    final selected = images.take(remainCount).toList();

    for (final image in selected) {
      final bytes = await image.readAsBytes();

      if (bytes.length > 5 * 1024 * 1024) {
        if (!mounted) return;

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('有圖片超過 5MB，已略過')));
        continue;
      }

      _pickedImages.add(image);
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _submitReview() async {
    if (_submitting) return;

    final content = _contentController.text.trim();

    if (content.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請先輸入評價內容')));
      return;
    }

    setState(() => _submitting = true);

    try {
      final uploadedUrls = await _uploadReviewImages();
      final imageUrls = [..._existingImageUrls, ...uploadedUrls];

      if (_isEditing) {
        await ReviewService.instance.updateMyReview(
          reviewId: widget.review!.reviewId,
          content: content,
          imageUrls: imageUrls,
        );
      } else {
        await ReviewService.instance.createReview(
          bookingId: widget.bookingId,
          rating: _rating,
          environmentRating: _environmentRating,
          serviceRating: _serviceRating,
          priceRating: _priceRating,
          content: content,
          imageUrls: imageUrls,
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_isEditing ? '評價已更新' : '感謝您的評價')));

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<List<String>> _uploadReviewImages() async {
    if (_pickedImages.isEmpty) return [];

    final urls = <String>[];

    for (final image in _pickedImages) {
      final bytes = await image.readAsBytes();

      final ref = FirebaseStorage.instance
          .ref()
          .child('review_images')
          .child(widget.bookingId)
          .child('${DateTime.now().millisecondsSinceEpoch}_${urls.length}.jpg');

      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));

      final url = await ref.getDownloadURL();
      urls.add(url);
    }

    return urls;
  }

  Widget _ratingRow({
    required String title,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: ReviewRatingStars(
              value: value,
              editable: !_submitting && !_isEditing,
              onChanged: onChanged,
            ),
          ),
          Text('$value 分'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? '修改評價' : '撰寫評價')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              '請分享這次住宿體驗，您的評價會幫助其他飼主選擇適合的旅宿。',
              style: TextStyle(height: 1.5),
            ),
          ),
          const SizedBox(height: 20),

          _ratingRow(
            title: '整體評分',
            value: _rating,
            onChanged: (value) => setState(() => _rating = value),
          ),
          _ratingRow(
            title: '環境',
            value: _environmentRating,
            onChanged: (value) => setState(() => _environmentRating = value),
          ),
          _ratingRow(
            title: '服務',
            value: _serviceRating,
            onChanged: (value) => setState(() => _serviceRating = value),
          ),
          _ratingRow(
            title: '價格',
            value: _priceRating,
            onChanged: (value) => setState(() => _priceRating = value),
          ),

          const SizedBox(height: 12),

          TextField(
            controller: _contentController,
            maxLines: 6,
            maxLength: 500,
            decoration: InputDecoration(
              labelText: '評價內容',
              hintText: '例如：環境很乾淨，店家每天都有回報照片，下次還會再來。',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),

          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('評價照片', style: TextStyle(fontWeight: FontWeight.bold)),
              TextButton.icon(
                onPressed: _submitting ? null : _pickImages,
                icon: const Icon(Icons.photo_library),
                label: Text(
                  '選擇照片 ${_existingImageUrls.length + _pickedImages.length}/5',
                ),
              ),
            ],
          ),
          if (_existingImageUrls.isNotEmpty || _pickedImages.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // 舊照片
                ...List.generate(_existingImageUrls.length, (index) {
                  final imageUrl = _existingImageUrls[index];

                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          imageUrl,
                          width: 88,
                          height: 88,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        right: 4,
                        top: 4,
                        child: InkWell(
                          onTap: _submitting
                              ? null
                              : () {
                                  setState(() {
                                    _existingImageUrls.removeAt(index);
                                  });
                                },
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }),

                // 新照片
                ...List.generate(_pickedImages.length, (index) {
                  final image = _pickedImages[index];

                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: FutureBuilder<Uint8List>(
                          future: image.readAsBytes(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return Container(
                                width: 88,
                                height: 88,
                                alignment: Alignment.center,
                                child: const CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              );
                            }

                            return Image.memory(
                              snapshot.data!,
                              width: 88,
                              height: 88,
                              fit: BoxFit.cover,
                            );
                          },
                        ),
                      ),
                      Positioned(
                        right: 4,
                        top: 4,
                        child: InkWell(
                          onTap: _submitting
                              ? null
                              : () {
                                  setState(() {
                                    _pickedImages.removeAt(index);
                                  });
                                },
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _submitting ? null : _submitReview,
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              label: Text(
                _submitting
                    ? '送出中...'
                    : _isEditing
                    ? '儲存修改'
                    : '送出評價',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
