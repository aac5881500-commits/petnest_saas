// lib/features/booking/pages/customer_daily_care_download_page.dart
// 📦 退房照護資料下載頁
// 功能：會員完成退房後，在下載期限內下載每日照護紀錄與高清照護照片。
// 注意：入住期間不可使用此頁取得高清照片。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:universal_html/html.dart' as html;
import 'package:petnest_saas/core/models/daily_care_photo_download_model.dart';
import 'package:petnest_saas/core/models/daily_care_record_model.dart';
import 'package:petnest_saas/core/models/daily_care_setting_model.dart';
import 'package:petnest_saas/core/models/daily_care_stay_info.dart';
import 'package:petnest_saas/core/services/daily_care_photo_download_service.dart';
import 'package:petnest_saas/core/services/daily_care_record_service.dart';
import 'package:petnest_saas/core/models/daily_care_report_data.dart';
import 'package:petnest_saas/core/services/daily_care_report_export_service.dart';
import 'package:petnest_saas/core/services/daily_care_setting_service.dart';

class CustomerDailyCareDownloadPage extends StatefulWidget {
  const CustomerDailyCareDownloadPage({
    super.key,
    required this.shopId,
    required this.bookingId,
    required this.roomName,
  });

  /// 店家 ID
  final String shopId;

  /// 訂單 ID
  final String bookingId;

  /// 入住房間名稱
  final String roomName;

  @override
  State<CustomerDailyCareDownloadPage> createState() =>
      _CustomerDailyCareDownloadPageState();
}

class _CustomerDailyCareDownloadPageState
    extends State<CustomerDailyCareDownloadPage> {
  bool _generating = false;

  String get shopId => widget.shopId;
  String get bookingId => widget.bookingId;
  String get roomName => widget.roomName;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .snapshots(),
      builder: (context, bookingSnapshot) {
        if (bookingSnapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(title: const Text('退房照護資料')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (bookingSnapshot.hasError ||
            !bookingSnapshot.hasData ||
            !bookingSnapshot.data!.exists) {
          return Scaffold(
            appBar: AppBar(title: const Text('退房照護資料')),
            body: const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('無法取得訂單資料。', textAlign: TextAlign.center),
              ),
            ),
          );
        }

        final Map<String, dynamic> data =
            bookingSnapshot.data!.data() ?? <String, dynamic>{};

        final String status = (data['status'] ?? '').toString().trim();

        final dynamic rawCheckOutAt = data['checkOutAt'];

        DateTime? checkOutAt;

        if (rawCheckOutAt is Timestamp) {
          checkOutAt = rawCheckOutAt.toDate();
        } else if (rawCheckOutAt is DateTime) {
          checkOutAt = rawCheckOutAt;
        } else if (rawCheckOutAt is String) {
          checkOutAt = DateTime.tryParse(rawCheckOutAt);
        }

        /// 必須是真正完成退房，
        /// 而且 Firestore 中具有實際退房時間。
        if (status != 'completed' || checkOutAt == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('退房照護資料')),
            body: const SafeArea(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    '此訂單尚未完成退房，暫時不能使用退房下載功能。',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          );
        }

        final DateTime confirmedCheckOutAt = checkOutAt;

        return FutureBuilder<List<Object?>>(
          future: Future.wait<Object?>(<Future<Object?>>[
            DailyCareSettingService.instance.getSetting(shopId),
            FirebaseFirestore.instance.collection('shops').doc(shopId).get(),
          ]),
          builder: (context, settingSnapshot) {
            if (settingSnapshot.connectionState == ConnectionState.waiting) {
              return Scaffold(
                appBar: AppBar(title: const Text('退房照護資料')),
                body: const Center(child: CircularProgressIndicator()),
              );
            }

            if (settingSnapshot.hasError ||
                !settingSnapshot.hasData ||
                settingSnapshot.data == null ||
                settingSnapshot.data!.isEmpty) {
              return Scaffold(
                appBar: AppBar(title: const Text('退房照護資料')),
                body: const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('無法取得照護下載設定。', textAlign: TextAlign.center),
                  ),
                ),
              );
            }

            final setting = settingSnapshot.data![0] as DailyCareSettingModel;
            final DocumentSnapshot<Map<String, dynamic>> shopSnapshot =
                settingSnapshot.data![1]
                    as DocumentSnapshot<Map<String, dynamic>>;
            final String shopLogoUrl = (shopSnapshot.data()?['logoUrl'] ?? '')
                .toString()
                .trim();
            final DailyCareStayInfo stayInfo = DailyCareStayInfo.fromBookingMap(
              data,
              fallbackRoomName: roomName,
              shopLogoUrl: shopLogoUrl,
            );
            final String resolvedRoomName = stayInfo.roomName.isNotEmpty
                ? stayInfo.roomName
                : roomName;

            /// 真正下載截止時間：
            ///
            /// checkOutAt
            /// +
            /// 店主設定 downloadHoursAfterCheckout
            final DateTime actualDownloadDeadline = confirmedCheckOutAt.add(
              Duration(hours: setting.downloadHoursAfterCheckout),
            );

            final bool isExpired = !DateTime.now().isBefore(
              actualDownloadDeadline,
            );

            return Scaffold(
              appBar: AppBar(title: const Text('退房照護資料')),
              body: SafeArea(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      resolvedRoomName,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (stayInfo.petNamesText.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        stayInfo.petNamesText,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                    if (stayInfo.stayDateText.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        stayInfo.stayDateText,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),

                    Text(isExpired ? '照護資料下載期限已結束' : '退房後可在期限內下載本次住宿的照護紀錄與照片。'),

                    const SizedBox(height: 8),

                    Text(
                      '退房時間：'
                      '${_formatDateTime(confirmedCheckOutAt)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      '下載截止時間：'
                      '${_formatDateTime(actualDownloadDeadline)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: isExpired
                            ? Colors.grey.shade700
                            : Colors.orange.shade900,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 24),

                    /// 📋 每日照護報告圖片
                    StreamBuilder(
                      stream: DailyCareRecordService.instance
                          .streamBookingRecords(bookingId: bookingId),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const _DownloadItemCard(
                            icon: Icons.image_outlined,
                            title: '每日照護報告',
                            description: '正在載入照護紀錄...',
                            enabled: false,
                            buttonLabel: '產生照護報告',
                            onPressed: null,
                          );
                        }

                        if (snapshot.hasError) {
                          return const _DownloadItemCard(
                            icon: Icons.image_outlined,
                            title: '每日照護報告',
                            description: '照護紀錄載入失敗。',
                            enabled: false,
                            buttonLabel: '產生照護報告',
                            onPressed: null,
                          );
                        }

                        final List<DailyCareRecordModel> records =
                            snapshot.data ?? <DailyCareRecordModel>[];

                        final int recordCount = records.length;

                        return _DownloadItemCard(
                          icon: Icons.image_outlined,
                          title: '每日照護報告',
                          description: recordCount > 0
                              ? '精簡統計版把整次住宿濃縮成一張圖；完整版保留每天每次紀錄。'
                              : '目前沒有可產出的照護紀錄。',
                          enabled:
                              !isExpired && recordCount > 0 && !_generating,
                          busy: _generating,
                          buttonLabel: _generating ? '產生報告中...' : '產生照護報告',
                          onPressed: () {
                            _openReportSheet(
                              records: records,
                              stayInfo: stayInfo,
                              setting: setting,
                              booking: data,
                              shop: shopSnapshot.data() ?? <String, dynamic>{},
                            );
                          },
                        );
                      },
                    ),

                    const SizedBox(height: 12),

                    /// 📥 高清照護照片
                    ///
                    /// 只讀：
                    /// daily_care_photo_downloads
                    ///
                    /// 真正圖片則透過：
                    /// downloadStoragePath
                    ///
                    /// 不再使用永久 downloadUrl。
                    StreamBuilder<List<DailyCarePhotoDownloadModel>>(
                      stream: DailyCarePhotoDownloadService.instance
                          .streamBookingDownloads(bookingId: bookingId),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const _DownloadItemCard(
                            icon: Icons.photo_library_outlined,
                            title: '照護照片',
                            description: '正在載入高清照護照片...',
                            enabled: false,
                            onPressed: null,
                          );
                        }

                        if (snapshot.hasError) {
                          return const _DownloadItemCard(
                            icon: Icons.photo_library_outlined,
                            title: '照護照片',
                            description: '高清照護照片載入失敗。',
                            enabled: false,
                            onPressed: null,
                          );
                        }

                        final List<DailyCarePhotoDownloadModel> photos =
                            snapshot.data ?? <DailyCarePhotoDownloadModel>[];

                        final int photoCount = photos.length;

                        return _DownloadItemCard(
                          icon: Icons.photo_library_outlined,
                          title: '照護照片',
                          description: photoCount > 0
                              ? '共有 $photoCount 張高清照護照片可下載。'
                              : '目前沒有可下載的高清照護照片。',
                          enabled: !isExpired && photoCount > 0,
                          onPressed: () async {
                            await _downloadPhotos(
                              context: context,
                              photos: photos,
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openReportSheet({
    required List<DailyCareRecordModel> records,
    required DailyCareStayInfo stayInfo,
    required DailyCareSettingModel setting,
    required Map<String, dynamic> booking,
    required Map<String, dynamic> shop,
  }) async {
    final DailyCareReportExportService export =
        DailyCareReportExportService.instance;
    final List<DateTime> dates = export.recordCareDates(
      stay: stayInfo,
      records: records,
    );
    if (dates.isEmpty) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const Text(
                    '下載照護報告',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '住宿照護統計',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '將整次住宿照護濃縮成一張簡單統計圖片',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      _generateReport(
                        records: records,
                        stayInfo: stayInfo,
                        setting: setting,
                        booking: booking,
                        shop: shop,
                        kind: DailyCareReportExportKind.summary,
                      );
                    },
                    child: const Text('下載精簡版'),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    '完整照護紀錄',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '包含每天每次照護與完整概況',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      _generateReport(
                        records: records,
                        stayInfo: stayInfo,
                        setting: setting,
                        booking: booking,
                        shop: shop,
                        kind: DailyCareReportExportKind.fullStay,
                      );
                    },
                    child: const Text('下載完整版'),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    '單日詳細版',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '選擇住宿日期後，產生該日完整照護報告',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 8),
                  if (dates.length == 1)
                    OutlinedButton(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        _generateReport(
                          records: records,
                          stayInfo: stayInfo,
                          setting: setting,
                          booking: booking,
                          shop: shop,
                          onlyDate: dates.first,
                          kind: DailyCareReportExportKind.singleDay,
                        );
                      },
                      child: Text(
                        '下載 ${dates.first.month}/${dates.first.day} 單日詳細版',
                      ),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: dates.map((DateTime date) {
                        return OutlinedButton(
                          onPressed: () {
                            Navigator.of(sheetContext).pop();
                            _generateReport(
                              records: records,
                              stayInfo: stayInfo,
                              setting: setting,
                              booking: booking,
                              shop: shop,
                              onlyDate: date,
                              kind: DailyCareReportExportKind.singleDay,
                            );
                          },
                          child: Text('${date.month}/${date.day}'),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _generateReport({
    required List<DailyCareRecordModel> records,
    required DailyCareStayInfo stayInfo,
    required DailyCareSettingModel setting,
    required Map<String, dynamic> booking,
    required Map<String, dynamic> shop,
    DateTime? onlyDate,
    DailyCareReportExportKind kind = DailyCareReportExportKind.fullStay,
  }) async {
    if (_generating) {
      return;
    }

    setState(() {
      _generating = true;
    });

    try {
      final DailyCareReportExportService export =
          DailyCareReportExportService.instance;
      final data = export.buildReport(
        booking: booking,
        shop: shop,
        stay: stayInfo,
        setting: setting,
        records: records,
        onlyDate: onlyDate,
        kind: kind,
      );
      if (kind != DailyCareReportExportKind.summary && data.days.isEmpty) {
        throw StateError('沒有可產出的照護日期');
      }
      if (kind == DailyCareReportExportKind.summary && records.isEmpty) {
        throw StateError('沒有可產出的照護紀錄');
      }

      final ImageProvider? logo = await export.preloadLogo(
        context,
        data.shopLogoUrl,
      );
      if (!mounted) {
        return;
      }

      await export.exportPng(
        context: context,
        data: data,
        logoProvider: logo,
        fileName: export.fileName(data: data),
      );

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(kIsWeb ? '照護報告已產生，開始下載。' : '照護報告已產生，請選擇儲存或分享位置。'),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('照護報告產生失敗：$error')));
    } finally {
      if (mounted) {
        setState(() {
          _generating = false;
        });
      }
    }
  }

  /// 📥 下載本次住宿全部高清照護照片。
  ///
  /// Web：
  /// 每張照片直接由瀏覽器下載。
  ///
  /// Android / iOS：
  /// 先取得圖片 bytes，
  /// 再透過系統分享 / 儲存介面輸出。
  Future<void> _downloadPhotos({
    required BuildContext context,
    required List<DailyCarePhotoDownloadModel> photos,
  }) async {
    if (photos.isEmpty) {
      return;
    }

    try {
      if (kIsWeb) {
        await _downloadPhotosForWeb(photos: photos);
      } else {
        await _downloadPhotosForMobile(photos: photos);
      }

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(kIsWeb ? '高清照護照片已開始下載。' : '高清照護照片已準備完成，請選擇儲存或分享位置。'),
        ),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('高清照片下載失敗：$error')));
    }
  }

  /// 🌐 Web 高清照片下載。
  Future<void> _downloadPhotosForWeb({
    required List<DailyCarePhotoDownloadModel> photos,
  }) async {
    for (int index = 0; index < photos.length; index++) {
      final DailyCarePhotoDownloadModel photo = photos[index];

      final Uint8List bytes = await DailyCarePhotoDownloadService.instance
          .downloadPhotoBytes(downloadStoragePath: photo.downloadStoragePath);

      final String fileName = _buildPhotoFileName(photo: photo, index: index);

      final html.Blob blob = html.Blob(<dynamic>[bytes], 'image/jpeg');

      final String objectUrl = html.Url.createObjectUrlFromBlob(blob);

      final html.AnchorElement anchor = html.AnchorElement(href: objectUrl);

      anchor.download = fileName;

      anchor.style.display = 'none';

      html.document.body?.children.add(anchor);

      anchor.click();

      anchor.remove();

      html.Url.revokeObjectUrl(objectUrl);
    }
  }

  /// 📱 Android / iOS 高清照片下載。
  ///
  /// 不寫入永久公開 URL，
  /// 直接將 Firebase Storage 下載到的 bytes
  /// 交給系統分享 / 儲存介面。
  Future<void> _downloadPhotosForMobile({
    required List<DailyCarePhotoDownloadModel> photos,
  }) async {
    final List<XFile> files = <XFile>[];

    for (int index = 0; index < photos.length; index++) {
      final DailyCarePhotoDownloadModel photo = photos[index];

      final Uint8List bytes = await DailyCarePhotoDownloadService.instance
          .downloadPhotoBytes(downloadStoragePath: photo.downloadStoragePath);

      final String fileName = _buildPhotoFileName(photo: photo, index: index);

      files.add(XFile.fromData(bytes, mimeType: 'image/jpeg', name: fileName));
    }

    if (files.isEmpty) {
      return;
    }

    await Share.shareXFiles(files, text: 'PetNest 每日照護高清照片');
  }

  String _buildPhotoFileName({
    required DailyCarePhotoDownloadModel photo,
    required int index,
  }) {
    final String safePhotoId = photo.id.trim().replaceAll(
      RegExp(r'[^a-zA-Z0-9_-]'),
      '_',
    );

    return 'PetNest_daily_care_'
        '${(index + 1).toString().padLeft(2, '0')}_'
        '$safePhotoId.jpg';
  }

  String _formatDateTime(DateTime value) {
    String twoDigits(int number) {
      return number.toString().padLeft(2, '0');
    }

    return '${value.year}/'
        '${twoDigits(value.month)}/'
        '${twoDigits(value.day)} '
        '${twoDigits(value.hour)}:'
        '${twoDigits(value.minute)}';
  }
}

class _DownloadItemCard extends StatelessWidget {
  const _DownloadItemCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.enabled,
    required this.onPressed,
    this.buttonLabel = '下載',
    this.busy = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool enabled;
  final VoidCallback? onPressed;
  final String buttonLabel;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, size: 30),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: enabled ? onPressed : null,
              child: busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(buttonLabel),
            ),
          ],
        ),
      ),
    );
  }
}
