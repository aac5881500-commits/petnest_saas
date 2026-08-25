// lib/features/booking/pages/customer_daily_care_photo_page.dart
// 📷 客戶端每日照護照片頁
// 功能：讓會員在入住期間查看店家回報的照護照片。
// 平常只載入 previewUrl 小圖，不提供原始下載版。
// 退房後的照片下載功能會由另一個流程處理。

import 'package:flutter/material.dart';

import '../../../core/models/daily_care_photo_model.dart';
import '../../../core/services/daily_care_photo_service.dart';

class CustomerDailyCarePhotoPage extends StatelessWidget {
  const CustomerDailyCarePhotoPage({
    super.key,
    required this.bookingId,
    required this.roomName,
  });

  final String bookingId;
  final String roomName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(title: const Text('照護照片')),
      body: StreamBuilder<List<DailyCarePhotoModel>>(
        stream: DailyCarePhotoService.instance.streamBookingPhotos(
          bookingId: bookingId,
        ),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Text(
                  '讀取照護照片失敗\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final List<DailyCarePhotoModel> photos =
              snapshot.data ?? <DailyCarePhotoModel>[];

          if (photos.isEmpty) {
            return const _EmptyPhotoView();
          }

          final Map<String, List<DailyCarePhotoModel>> grouped =
              <String, List<DailyCarePhotoModel>>{};

          for (final DailyCarePhotoModel photo in photos) {
            final String dateKey = _dateKey(photo.recordDate);

            grouped.putIfAbsent(dateKey, () => <DailyCarePhotoModel>[]);

            grouped[dateKey]!.add(photo);
          }

          final List<String> dateKeys = grouped.keys.toList()..sort();

          return ListView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
            children: <Widget>[
              _headerCard(),

              const SizedBox(height: 14),

              for (final String dateKey in dateKeys) ...<Widget>[
                _datePhotoCard(
                  context: context,
                  dateKey: dateKey,
                  photos: grouped[dateKey]!,
                ),
                const SizedBox(height: 12),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _headerCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF3D6F9F).withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF3D6F9F).withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.photo_camera_outlined,
              color: Color(0xFF3D6F9F),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  '住宿照護照片',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  roomName.trim().isEmpty ? '店家每日回報照片' : '$roomName・店家每日回報照片',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _datePhotoCard({
    required BuildContext context,
    required String dateKey,
    required List<DailyCarePhotoModel> photos,
  }) {
    photos.sort((DailyCarePhotoModel a, DailyCarePhotoModel b) {
      final int sessionCompare = a.sessionIndex.compareTo(b.sessionIndex);

      if (sessionCompare != 0) {
        return sessionCompare;
      }

      final DateTime aTime = a.createdAt ?? DateTime(1970);

      final DateTime bTime = b.createdAt ?? DateTime(1970);

      return aTime.compareTo(bTime);
    });

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.calendar_today_outlined,
                size: 17,
                color: Color(0xFF3D6F9F),
              ),
              const SizedBox(width: 7),
              Text(
                dateKey,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              Text(
                '${photos.length} 張',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
          ),

          const SizedBox(height: 12),

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: photos.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 7,
              mainAxisSpacing: 7,
              childAspectRatio: 1,
            ),
            itemBuilder: (context, index) {
              final DailyCarePhotoModel photo = photos[index];

              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  _showPreview(context, photo);
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      Container(
                        color: Colors.grey.shade100,
                        child: Image.network(
                          photo.previewUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(
                              child: Icon(
                                Icons.broken_image_outlined,
                                color: Colors.grey,
                              ),
                            );
                          },
                        ),
                      ),

                      Positioned(
                        left: 5,
                        bottom: 5,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            photo.sessionName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showPreview(BuildContext context, DailyCarePhotoModel photo) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.all(18),
          backgroundColor: Colors.black,
          child: Stack(
            children: <Widget>[
              InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Image.network(
                  photo.previewUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const SizedBox(
                      height: 300,
                      child: Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: Colors.white,
                          size: 42,
                        ),
                      ),
                    );
                  },
                ),
              ),
              Positioned(
                top: 6,
                right: 6,
                child: IconButton.filled(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                  icon: const Icon(Icons.close),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static String _dateKey(DateTime value) {
    return '${value.year}/'
        '${value.month.toString().padLeft(2, '0')}/'
        '${value.day.toString().padLeft(2, '0')}';
  }
}

class _EmptyPhotoView extends StatelessWidget {
  const _EmptyPhotoView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.photo_library_outlined,
              size: 54,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 14),
            const Text(
              '目前還沒有照護照片',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              '店家上傳照護照片後，會顯示在這裡。',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
