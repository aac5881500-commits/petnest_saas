// 檔案名稱：lib/features/shop/pages/shop_device_page.dart
// 功能說明：以房間為主的攝影機設定表。同房多筆設備只顯示一筆主設定。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/camera_access_policy.dart';
import 'package:petnest_saas/core/models/camera_brand.dart';
import 'package:petnest_saas/core/services/shop_device_service.dart';
import 'package:petnest_saas/core/services/shop_room_service.dart';
import 'package:petnest_saas/core/utils/natural_sort.dart';
import 'package:petnest_saas/core/widgets/shop_task_center_button.dart';
import 'package:petnest_saas/features/booking/widgets/camera_brand_launch.dart';
import 'package:petnest_saas/features/shop/widgets/camera/shop_camera_access_panel.dart';
import 'package:url_launcher/url_launcher.dart';

const String _httpsUrlError = '請輸入可直接開啟的 HTTPS 攝影機網址';
const String _disabledSwitchTip = '請先填寫可從外網直接開啟的 HTTPS 網址';

class ShopDevicePage extends StatelessWidget {
  const ShopDevicePage({super.key, required this.shopId});

  final String shopId;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('攝影機設定'),
          actions: <Widget>[ShopTaskCenterButton(shopId: shopId)],
          bottom: const TabBar(
            tabs: <Widget>[
              Tab(text: '房間設備'),
              Tab(text: '分享申請'),
            ],
          ),
        ),
        body: TabBarView(
          children: <Widget>[
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: ShopRoomService.instance.roomsRef(shopId).snapshots(),
              builder:
                  (
                    BuildContext context,
                    AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>>
                    roomsSnap,
                  ) {
                    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: ShopRoomService.instance
                          .roomTypesRef(shopId)
                          .snapshots(),
                      builder:
                          (
                            BuildContext context,
                            AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>>
                            typesSnap,
                          ) {
                            return StreamBuilder<
                              QuerySnapshot<Map<String, dynamic>>
                            >(
                              stream: ShopDeviceService.instance.watchDevices(
                                shopId,
                              ),
                              builder:
                                  (
                                    BuildContext context,
                                    AsyncSnapshot<
                                      QuerySnapshot<Map<String, dynamic>>
                                    >
                                    devicesSnap,
                                  ) {
                                    return StreamBuilder<
                                      DocumentSnapshot<Map<String, dynamic>>
                                    >(
                                      stream: FirebaseFirestore.instance
                                          .collection('shops')
                                          .doc(shopId)
                                          .snapshots(),
                                      builder:
                                          (
                                            BuildContext context,
                                            AsyncSnapshot<
                                              DocumentSnapshot<
                                                Map<String, dynamic>
                                              >
                                            >
                                            shopSnap,
                                          ) {
                                            final Object? failure =
                                                roomsSnap.error ??
                                                typesSnap.error ??
                                                devicesSnap.error;
                                            if (failure != null) {
                                              debugPrint(failure.toString());
                                              return const _CameraMessage(
                                                icon: Icons.cloud_off_outlined,
                                                title: '攝影機資料讀取失敗，請重新整理後再試。',
                                              );
                                            }
                                            if (!roomsSnap.hasData ||
                                                !typesSnap.hasData ||
                                                !devicesSnap.hasData) {
                                              return const Center(
                                                child:
                                                    CircularProgressIndicator(),
                                              );
                                            }
                                            final bool showCameraSection =
                                                shopSnap.data
                                                    ?.data()?['showCameraSection'] !=
                                                false;
                                            final List<_RoomCameraLine>
                                            lines = _roomCameraLines(
                                              rooms: roomsSnap.data!.docs,
                                              roomTypes: typesSnap.data!.docs,
                                              devices: devicesSnap.data!.docs,
                                            );
                                            return LayoutBuilder(
                                              builder:
                                                  (
                                                    BuildContext context,
                                                    BoxConstraints constraints,
                                                  ) {
                                                    final bool desktop =
                                                        constraints.maxWidth >=
                                                        900;
                                                    final double pad = desktop
                                                        ? 24
                                                        : 16;
                                                    return ListView(
                                                      padding:
                                                          EdgeInsets.fromLTRB(
                                                            pad,
                                                            16,
                                                            pad,
                                                            24,
                                                          ),
                                                      children: <Widget>[
                                                        _ServiceBar(
                                                          showCameraSection:
                                                              showCameraSection,
                                                          lines: lines,
                                                          onChanged: (bool value) {
                                                            _updateShowCameraSection(
                                                              context,
                                                              shopId: shopId,
                                                              value: value,
                                                              liveCount: lines
                                                                  .where(
                                                                    (
                                                                      _RoomCameraLine
                                                                      line,
                                                                    ) =>
                                                                        line.status ==
                                                                        _CameraRowStatus
                                                                            .live,
                                                                  )
                                                                  .length,
                                                            );
                                                          },
                                                        ),
                                                        const SizedBox(
                                                          height: 8,
                                                        ),
                                                        const _CompatibilityStrip(),
                                                        const SizedBox(
                                                          height: 12,
                                                        ),
                                                        if (lines.isEmpty)
                                                          const _CameraMessage(
                                                            icon: Icons
                                                                .videocam_off_outlined,
                                                            title: '尚未建立房間',
                                                            message:
                                                                '新增房間後，這裡會出現對應的攝影機設定。',
                                                          )
                                                        else if (desktop)
                                                          _CameraTable(
                                                            shopId: shopId,
                                                            lines: lines,
                                                          )
                                                        else
                                                          _CameraPhoneList(
                                                            shopId: shopId,
                                                            lines: lines,
                                                          ),
                                                      ],
                                                    );
                                                  },
                                            );
                                          },
                                    );
                                  },
                            );
                          },
                    );
                  },
            ),
            ShopCameraAccessPanel(shopId: shopId),
          ],
        ),
      ),
    );
  }
}

enum _CameraRowStatus { locked, unset, pending, live }

class _RoomCameraLine {
  const _RoomCameraLine({
    required this.roomId,
    required this.roomName,
    required this.roomTypeName,
    required this.roomTypeMissing,
    required this.primary,
    required this.siblingIds,
    required this.cameraCount,
    required this.status,
  });

  final String roomId;
  final String roomName;
  final String roomTypeName;
  final bool roomTypeMissing;
  final QueryDocumentSnapshot<Map<String, dynamic>>? primary;
  final List<String> siblingIds;
  final int cameraCount;
  final _CameraRowStatus status;

  String get url => (primary?.data()['url'] ?? '').toString();

  String get note => (primary?.data()['note'] ?? '').toString();

  String get viewMode => cameraViewModeOf(primary?.data());

  String get provider => (primary?.data()['provider'] ?? '').toString();

  String get watchLabel {
    if (viewMode != cameraViewExternalApp) {
      return url.trim().isEmpty ? '網址觀看' : _urlLabel(url);
    }
    final String label = cameraBrandLabel(provider);
    return label.isEmpty ? '外部 App・未開放品牌' : '外部 App・$label';
  }

  String get externalDeviceName =>
      (primary?.data()['externalDeviceName'] ?? '').toString();

  String get customerShareNote =>
      (primary?.data()['customerShareNote'] ?? '').toString();

  bool get enabled => primary?.data()['enabled'] == true;

  bool get platformLocked => primary?.data()['platformLocked'] == true;

  bool get hasValidUrl =>
      viewMode == cameraViewWebUrl && cameraIsDirectHttps(url);

  bool get setupComplete => cameraSetupComplete(primary?.data());

  bool get switchEnabled => setupComplete && !platformLocked;

  String get disabledSwitchTip => viewMode == cameraViewExternalApp
      ? '請先完成外部 App 品牌設定後再啟用'
      : _disabledSwitchTip;
}

List<_RoomCameraLine> _roomCameraLines({
  required List<QueryDocumentSnapshot<Map<String, dynamic>>> rooms,
  required List<QueryDocumentSnapshot<Map<String, dynamic>>> roomTypes,
  required List<QueryDocumentSnapshot<Map<String, dynamic>>> devices,
}) {
  final Map<String, String> typeNames = <String, String>{
    for (final QueryDocumentSnapshot<Map<String, dynamic>> type in roomTypes)
      type.id: (type.data()['name'] ?? '').toString().trim(),
  };
  final Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>> cameras =
      <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
  for (final QueryDocumentSnapshot<Map<String, dynamic>> device in devices) {
    final Map<String, dynamic> data = device.data();
    if ((data['type'] ?? '').toString() != 'camera') {
      continue;
    }
    final String roomId = (data['roomId'] ?? '').toString().trim();
    if (roomId.isEmpty) {
      continue;
    }
    cameras
        .putIfAbsent(
          roomId,
          () => <QueryDocumentSnapshot<Map<String, dynamic>>>[],
        )
        .add(device);
  }

  final List<_RoomCameraLine> lines = <_RoomCameraLine>[];
  for (final QueryDocumentSnapshot<Map<String, dynamic>> room in rooms) {
    final Map<String, dynamic> data = room.data();
    final String roomName = (data['name'] ?? '').toString().trim();
    final String roomTypeId = (data['roomTypeId'] ?? '').toString().trim();
    final String? typeName = roomTypeId.isEmpty ? null : typeNames[roomTypeId];
    final bool typeMissing = roomTypeId.isEmpty || (typeName ?? '').isEmpty;
    final List<QueryDocumentSnapshot<Map<String, dynamic>>> group =
        List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
          cameras[room.id] ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[],
        )..sort(_compareCameras);
    final QueryDocumentSnapshot<Map<String, dynamic>>? primary = group.isEmpty
        ? null
        : group.first;
    lines.add(
      _RoomCameraLine(
        roomId: room.id,
        roomName: roomName.isEmpty ? '未命名房間' : roomName,
        roomTypeName: typeMissing ? '未設定房型' : typeName!,
        roomTypeMissing: typeMissing,
        primary: primary,
        siblingIds: group
            .skip(1)
            .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) => doc.id)
            .toList(),
        cameraCount: group.length,
        status: _statusOf(primary?.data()),
      ),
    );
  }
  lines.sort((_RoomCameraLine a, _RoomCameraLine b) {
    return _compareRoomCodeByDigitGroup(a.roomName, b.roomName);
  });
  return lines;
}

_CameraRowStatus _statusOf(Map<String, dynamic>? data) {
  if (data == null) {
    return _CameraRowStatus.unset;
  }
  if (data['platformLocked'] == true) {
    return _CameraRowStatus.locked;
  }
  if (!cameraSetupComplete(data)) {
    return _CameraRowStatus.unset;
  }
  if (data['enabled'] != true) {
    return _CameraRowStatus.pending;
  }
  return _CameraRowStatus.live;
}

int _compareCameras(
  QueryDocumentSnapshot<Map<String, dynamic>> a,
  QueryDocumentSnapshot<Map<String, dynamic>> b,
) {
  final Map<String, dynamic> aData = a.data();
  final Map<String, dynamic> bData = b.data();
  final int urlRank = _preferTrue(
    cameraSetupComplete(aData),
    cameraSetupComplete(bData),
  );
  if (urlRank != 0) {
    return urlRank;
  }
  final int enabledRank = _preferTrue(
    aData['enabled'] == true,
    bData['enabled'] == true,
  );
  if (enabledRank != 0) {
    return enabledRank;
  }
  final int updatedRank = _newerFirst(
    _readTime(aData['updatedAt']),
    _readTime(bData['updatedAt']),
  );
  if (updatedRank != 0) {
    return updatedRank;
  }
  final int createdRank = _newerFirst(
    _readTime(aData['createdAt']),
    _readTime(bData['createdAt']),
  );
  if (createdRank != 0) {
    return createdRank;
  }
  return a.id.compareTo(b.id);
}

int _preferTrue(bool a, bool b) {
  if (a == b) {
    return 0;
  }
  return a ? -1 : 1;
}

int _newerFirst(DateTime? a, DateTime? b) {
  if (a == null && b == null) {
    return 0;
  }
  if (a == null) {
    return 1;
  }
  if (b == null) {
    return -1;
  }
  return b.compareTo(a);
}

DateTime? _readTime(Object? value) {
  if (value is Timestamp) {
    return value.toDate();
  }
  if (value is DateTime) {
    return value;
  }
  return null;
}

bool _isDirectHttpsCameraUrl(String raw) => cameraIsDirectHttps(raw);

String _urlLabel(String raw) {
  final String url = raw.trim();
  if (url.isEmpty) {
    return '';
  }
  final Uri? uri = Uri.tryParse(url);
  if (uri == null || uri.host.trim().isEmpty) {
    return '網址格式不正確';
  }
  return uri.host;
}

class _ServiceBar extends StatelessWidget {
  const _ServiceBar({
    required this.showCameraSection,
    required this.lines,
    required this.onChanged,
  });

  final bool showCameraSection;
  final List<_RoomCameraLine> lines;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final Color brand = Theme.of(context).colorScheme.primary;
    final int liveCount = lines
        .where((_RoomCameraLine line) => line.status == _CameraRowStatus.live)
        .length;
    final int unsetCount = lines
        .where((_RoomCameraLine line) => !line.setupComplete)
        .length;
    final int duplicateRooms = lines
        .where((_RoomCameraLine line) => line.cameraCount >= 2)
        .length;
    return Container(
      constraints: const BoxConstraints(minHeight: 76),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: brand.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.videocam_rounded, size: 18, color: brand),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  '客戶攝影機服務',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
                Text(
                  showCameraSection
                      ? '入住或安親中的會員只會看見自己房間已啟用的攝影機。'
                      : '會員前台目前不顯示攝影機入口。',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: <Widget>[
                    _MiniChip('房間 ${lines.length} 間'),
                    _MiniChip('使用中 $liveCount 間'),
                    _MiniChip('待設定 $unsetCount 間'),
                    if (duplicateRooms > 0) _MiniChip('重複設定 $duplicateRooms 間'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            '前台顯示',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
          Switch(value: showCameraSection, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F6FA),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFF374151),
        ),
      ),
    );
  }
}

class _CompatibilityStrip extends StatelessWidget {
  const _CompatibilityStrip();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Row(
        children: <Widget>[
          Icon(
            Icons.info_outline,
            size: 16,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 6),
          const Expanded(
            child: Text(
              '網址觀看使用 HTTPS。外部 App 由店家在原廠 App 手動分享，請打開相容性說明。',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, color: Color(0xFF6B7280)),
            ),
          ),
          TextButton(
            onPressed: () => _showCameraCompatibilitySheet(context),
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('相容性與測試方式'),
          ),
        ],
      ),
    );
  }
}

class _CameraTable extends StatelessWidget {
  const _CameraTable({required this.shopId, required this.lines});

  final String shopId;
  final List<_RoomCameraLine> lines;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: <Widget>[
          const _TableHeader(),
          for (int i = 0; i < lines.length; i++) ...<Widget>[
            if (i > 0) const Divider(height: 1, color: Color(0xFFE5E7EB)),
            _CameraTableRow(shopId: shopId, line: lines[i]),
          ],
        ],
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    const TextStyle style = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w800,
      color: Color(0xFF6B7280),
    );
    return Container(
      height: 36,
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: const Row(
        children: <Widget>[
          SizedBox(width: 132, child: Text('房間', style: style)),
          SizedBox(width: 176, child: Text('房型', style: style)),
          Expanded(child: Text('觀看方式', style: style)),
          SizedBox(width: 118, child: Text('狀態', style: style)),
          SizedBox(width: 72, child: Text('啟用', style: style)),
          SizedBox(width: 84, child: Text('操作', style: style)),
        ],
      ),
    );
  }
}

class _CameraTableRow extends StatelessWidget {
  const _CameraTableRow({required this.shopId, required this.line});

  final String shopId;
  final _RoomCameraLine line;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 62,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 132,
              child: _NameCell(
                icon: Icons.videocam_outlined,
                text: line.roomName,
                muted: false,
              ),
            ),
            SizedBox(
              width: 176,
              child: _NameCell(
                icon: Icons.bed_outlined,
                text: line.roomTypeName,
                muted: line.roomTypeMissing,
              ),
            ),
            Expanded(
              child: _UrlCell(shopId: shopId, line: line),
            ),
            SizedBox(width: 118, child: _StatusCell(line: line)),
            SizedBox(
              width: 72,
              child: _EnableSwitch(shopId: shopId, line: line),
            ),
            SizedBox(
              width: 84,
              child: _RowActions(shopId: shopId, line: line),
            ),
          ],
        ),
      ),
    );
  }
}

class _CameraPhoneList extends StatelessWidget {
  const _CameraPhoneList({required this.shopId, required this.lines});

  final String shopId;
  final List<_RoomCameraLine> lines;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        for (final _RoomCameraLine line in lines) ...<Widget>[
          _CameraPhoneCard(shopId: shopId, line: line),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _CameraPhoneCard extends StatelessWidget {
  const _CameraPhoneCard({required this.shopId, required this.line});

  final String shopId;
  final _RoomCameraLine line;

  @override
  Widget build(BuildContext context) {
    final String host = line.watchLabel;
    return Container(
      height: 84,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.videocam_outlined,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        line.roomName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _StatusChip(status: line.status),
                    if (line.cameraCount >= 2) ...<Widget>[
                      const SizedBox(width: 2),
                      _DuplicateWarning(count: line.cameraCount),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.bed_outlined,
                      size: 14,
                      color: line.roomTypeMissing
                          ? const Color(0xFF9CA3AF)
                          : const Color(0xFF6B7280),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        line.roomTypeName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: line.roomTypeMissing
                              ? const Color(0xFF9CA3AF)
                              : const Color(0xFF4B5563),
                        ),
                      ),
                    ),
                    const Text(
                      ' · ',
                      style: TextStyle(color: Color(0xFFD1D5DB)),
                    ),
                    Flexible(
                      child: Text(
                        host,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              line.viewMode == cameraViewExternalApp ||
                                  line.url.trim().isNotEmpty
                              ? const Color(0xFF374151)
                              : const Color(0xFF9CA3AF),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _EnableSwitch(shopId: shopId, line: line),
          _RowActions(shopId: shopId, line: line),
        ],
      ),
    );
  }
}

class _NameCell extends StatelessWidget {
  const _NameCell({
    required this.icon,
    required this.text,
    required this.muted,
  });

  final IconData icon;
  final String text;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(
          icon,
          size: 16,
          color: muted ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: muted ? FontWeight.w500 : FontWeight.w700,
              color: muted ? const Color(0xFF9CA3AF) : const Color(0xFF1F2937),
            ),
          ),
        ),
      ],
    );
  }
}

class _UrlCell extends StatelessWidget {
  const _UrlCell({required this.shopId, required this.line});

  final String shopId;
  final _RoomCameraLine line;

  @override
  Widget build(BuildContext context) {
    if (line.viewMode == cameraViewExternalApp) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Text(
          line.watchLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );
    }
    if (line.url.trim().isEmpty) {
      return Row(
        children: <Widget>[
          const Text('尚未設定', style: TextStyle(color: Color(0xFF9CA3AF))),
          TextButton(
            onPressed: () => _showEditDeviceDialog(context, shopId, line),
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('填寫網址'),
          ),
        ],
      );
    }
    final String label = _urlLabel(line.url);
    return Align(
      alignment: Alignment.centerLeft,
      child: InkWell(
        onTap: () => _showEditDeviceDialog(context, shopId, line),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: label == '網址格式不正確'
                ? const Color(0xFF9F1239)
                : const Color(0xFF1F2937),
          ),
        ),
      ),
    );
  }
}

class _StatusCell extends StatelessWidget {
  const _StatusCell({required this.line});

  final _RoomCameraLine line;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        _StatusChip(status: line.status),
        if (line.cameraCount >= 2) ...<Widget>[
          const SizedBox(width: 2),
          _DuplicateWarning(count: line.cameraCount),
        ],
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final _CameraRowStatus status;

  @override
  Widget build(BuildContext context) {
    final (String label, Color fg, Color bg) = switch (status) {
      _CameraRowStatus.locked => (
        '平台鎖定',
        const Color(0xFF9F1239),
        const Color(0xFFFEE2E2),
      ),
      _CameraRowStatus.unset => (
        '待設定',
        const Color(0xFFE65100),
        const Color(0xFFFFF3E0),
      ),
      _CameraRowStatus.pending => (
        '待啟用',
        const Color(0xFF475569),
        const Color(0xFFF1F5F9),
      ),
      _CameraRowStatus.live => (
        '使用中',
        const Color(0xFF2E7D32),
        const Color(0xFFE8F5E9),
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: fg),
      ),
    );
  }
}

class _DuplicateWarning extends StatelessWidget {
  const _DuplicateWarning({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '此房間偵測到 $count 筆攝影機設定，目前只使用一筆主要設定。',
      child: const Icon(
        Icons.warning_amber_rounded,
        size: 16,
        color: Color(0xFFD97706),
      ),
    );
  }
}

class _EnableSwitch extends StatelessWidget {
  const _EnableSwitch({required this.shopId, required this.line});

  final String shopId;
  final _RoomCameraLine line;

  @override
  Widget build(BuildContext context) {
    final Switch control = Switch(
      value: line.switchEnabled && line.enabled,
      onChanged: line.switchEnabled
          ? (bool value) => _setEnabled(context, shopId, line, value)
          : null,
    );
    if (line.switchEnabled) {
      return control;
    }
    return Tooltip(message: line.disabledSwitchTip, child: control);
  }
}

class _RowActions extends StatelessWidget {
  const _RowActions({required this.shopId, required this.line});

  final String shopId;
  final _RoomCameraLine line;

  @override
  Widget build(BuildContext context) {
    final ButtonStyle style = IconButton.styleFrom(
      visualDensity: VisualDensity.compact,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      minimumSize: const Size(32, 32),
      padding: EdgeInsets.zero,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        IconButton(
          tooltip: '編輯攝影機設定',
          style: style,
          onPressed: () => _showEditDeviceDialog(context, shopId, line),
          icon: const Icon(Icons.edit_outlined, size: 18),
        ),
        IconButton(
          tooltip: line.viewMode == cameraViewExternalApp ? '原廠 App' : '測試網址',
          style: style,
          onPressed: line.platformLocked
              ? null
              : () {
                  if (line.viewMode == cameraViewExternalApp) {
                    final CameraBrand? brand = cameraBrandById(line.provider);
                    if (brand == null) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(const SnackBar(content: Text('此品牌尚未開放')));
                      return;
                    }
                    showDialog<void>(
                      context: context,
                      builder: (BuildContext dialogContext) {
                        return AlertDialog(
                          title: Text(brand.appName),
                          content: CameraBrandActions(providerId: brand.id),
                          actions: <Widget>[
                            TextButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              child: const Text('關閉'),
                            ),
                          ],
                        );
                      },
                    );
                    return;
                  }
                  if (line.hasValidUrl) {
                    _openExternalCameraUrl(context, line.url);
                  }
                },
          icon: Icon(
            line.viewMode == cameraViewExternalApp
                ? Icons.phone_android_outlined
                : Icons.open_in_new,
            size: 18,
          ),
        ),
      ],
    );
  }
}

class _CameraMessage extends StatelessWidget {
  const _CameraMessage({required this.icon, required this.title, this.message});

  final IconData icon;
  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 36, color: const Color(0xFF9CA3AF)),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            if (message != null) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Future<void> _updateShowCameraSection(
  BuildContext context, {
  required String shopId,
  required bool value,
  required int liveCount,
}) async {
  try {
    await FirebaseFirestore.instance.collection('shops').doc(shopId).update(
      <String, dynamic>{
        'showCameraSection': value,
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
    if (!context.mounted || !value || liveCount > 0) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('前台已開啟，但目前沒有可供會員觀看的房間攝影機。')));
  } on FirebaseException catch (error) {
    debugPrint('更新 showCameraSection 失敗：${error.code}｜${error.message}');
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('攝影機開關儲存失敗')));
  } catch (error) {
    debugPrint('更新 showCameraSection 失敗：$error');
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('攝影機開關儲存失敗')));
  }
}

Future<void> _setEnabled(
  BuildContext context,
  String shopId,
  _RoomCameraLine line,
  bool enabled,
) async {
  if (enabled && !line.setupComplete) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(line.disabledSwitchTip)));
    return;
  }
  final String? primaryId = line.primary?.id;
  if (primaryId == null) {
    return;
  }
  try {
    await ShopDeviceService.instance.writePrimaryRoomCamera(
      shopId: shopId,
      roomId: line.roomId,
      roomName: line.roomName,
      primaryDeviceId: primaryId,
      url: line.url,
      note: line.note,
      enabled: enabled,
      persistSettings: false,
      siblingDeviceIds: enabled ? line.siblingIds : const <String>[],
    );
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          enabled
              ? (line.viewMode == cameraViewExternalApp
                    ? '${line.roomName} 已啟用。顧客可提出分享申請，請到${cameraBrandById(line.provider)?.appName ?? '原廠 App'}手動分享。'
                    : '${line.roomName} 已啟用')
              : '${line.roomName} 已停用。PetNest 關閉入口不會自動移除原廠 App 的觀看權限，請至原廠 App 取消分享。',
        ),
      ),
    );
  } catch (error) {
    debugPrint('更新攝影機啟用狀態失敗：$error');
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('攝影機狀態更新失敗')));
  }
}

Future<void> _openExternalCameraUrl(BuildContext context, String url) async {
  if (!_isDirectHttpsCameraUrl(url)) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text(_httpsUrlError)));
    return;
  }
  try {
    final bool launched = await launchUrl(
      Uri.parse(url.trim()),
      mode: LaunchMode.externalApplication,
    );
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('無法開啟此網址，請確認網址與外網存取設定')));
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('無法開啟此網址，請確認網址與外網存取設定')));
    }
  }
}

void _showCameraCompatibilitySheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext sheetContext) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.88,
        minChildSize: 0.55,
        maxChildSize: 0.96,
        builder: (BuildContext context, ScrollController controller) {
          return _CameraCompatibilityGuide(controller: controller);
        },
      );
    },
  );
}

class _CameraCompatibilityGuide extends StatelessWidget {
  const _CameraCompatibilityGuide({required this.controller});

  final ScrollController controller;

  static const List<String> _usable = <String>[
    '有 https:// 開頭的觀看網址',
    '在店外、用手機行動網路也能開啟',
    'Chrome、Safari 可直接看到即時畫面',
    '會員不需要下載原廠 App',
    '會員不需要登入店家的攝影機帳號',
  ];

  static const List<String> _unusable = <String>[
    '只能在原廠 App 內觀看',
    '網址是 192.168.x.x、10.x.x.x 或其他店內 IP',
    '網址是 rtsp://、rtmp:// 等串流協定',
    '離開店內 Wi-Fi 就無法觀看',
    '客人必須使用你的帳號密碼登入',
    '只提供攝影機後台管理網址',
  ];

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      child: ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '攝影機相容性與設定教學',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'PetNest 不直接連接攝影機；會員會開啟店家提供的外部觀看網址。',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: '關閉',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const _GuideCallout(
            icon: Icons.videocam_outlined,
            title: '先確認：你的攝影機有「外網瀏覽器觀看網址」嗎？',
            body: '店主需提供一個可由店外直接開啟的 HTTPS 網址。入住會員點擊後會在瀏覽器開啟，不會安裝或登入你的攝影機 App。',
          ),
          const SizedBox(height: 10),
          const _GuideNotice('請提供「僅供觀看」的分享連結，不要提供攝影機管理員帳號、密碼或後台網址。'),
          const SizedBox(height: 22),
          const _GuideHeading('1. 先判斷能不能使用'),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool sideBySide = constraints.maxWidth >= 720;
              final Widget usable = _GuideCompareCard(
                usable: true,
                title: '可以使用',
                icon: Icons.check_circle_outline,
                points: _usable,
              );
              final Widget blocked = _GuideCompareCard(
                usable: false,
                title: '目前不能直接使用',
                icon: Icons.cancel_outlined,
                points: _unusable,
              );
              if (!sideBySide) {
                return Column(
                  children: <Widget>[
                    usable,
                    const SizedBox(height: 10),
                    blocked,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(child: usable),
                  const SizedBox(width: 12),
                  Expanded(child: blocked),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          const Text(
            '如果設備只有原廠 App，PetNest 目前無法直接把畫面提供給會員。',
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 22),
          const _GuideHeading('2. 設定前，照這三步測試'),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              const List<_GuideStepData> steps = <_GuideStepData>[
                _GuideStepData(
                  step: 1,
                  title: '先在瀏覽器開啟網址',
                  body: '把攝影機提供的分享網址貼到 Chrome、Safari 或 Edge。',
                  note: '必須是 https:// 網頁網址，不是 RTSP 或店內 IP。',
                  icons: <IconData>[Icons.language_rounded],
                ),
                _GuideStepData(
                  step: 2,
                  title: '關閉店內 Wi-Fi',
                  body: '用手機行動網路再次開啟同一網址。',
                  note: '這一步是在模擬入住會員不在店內網路時的狀況。',
                  icons: <IconData>[
                    Icons.wifi_off_rounded,
                    Icons.signal_cellular_alt_rounded,
                  ],
                ),
                _GuideStepData(
                  step: 3,
                  title: '確認能直接看到畫面',
                  body: '不安裝 App、不登入帳號，也能直接看到攝影機畫面。',
                  note: '三步都成功，這個網址才適合貼到 PetNest。',
                  icons: <IconData>[Icons.visibility_outlined],
                ),
              ];
              if (constraints.maxWidth < 840) {
                return Column(
                  children: <Widget>[
                    _GuideStepCard(data: steps[0]),
                    const SizedBox(height: 10),
                    _GuideStepCard(data: steps[1]),
                    const SizedBox(height: 10),
                    _GuideStepCard(data: steps[2]),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(child: _GuideStepCard(data: steps[0])),
                  const _GuideArrow(),
                  Expanded(child: _GuideStepCard(data: steps[1])),
                  const _GuideArrow(),
                  Expanded(child: _GuideStepCard(data: steps[2])),
                ],
              );
            },
          ),
          const SizedBox(height: 22),
          const _GuideHeading('3. 常見情況怎麼判斷'),
          const SizedBox(height: 10),
          const _GuideQaCard(
            question: '我有小米、Tapo、Eufy、Google 等家用攝影機，可以用嗎？',
            answer:
                '小米／米家可改用「外部設備」模式，由店家在米家手動分享給顧客。Tapo、Eufy、Google 等仍要有可從外網直接開啟的 HTTPS 觀看網址。',
          ),
          const SizedBox(height: 8),
          const _GuideQaCard(
            question: '我可以貼店內 NVR 或路由器網址嗎？',
            answer: '不可以。192.168.x.x、10.x.x.x 或只能在店內 Wi-Fi 使用的網址，會員在店外無法開啟。',
          ),
          const SizedBox(height: 8),
          const _GuideQaCard(
            question: '網址需要登入帳號怎麼辦？',
            answer: '不適合提供給會員。請改用設備支援的「僅供觀看分享連結」；不要把店家管理帳號、密碼或管理後台交給客人。',
          ),
          const SizedBox(height: 8),
          const _GuideQaCard(
            question: '我測試時可以看，客人還是看不到？',
            answer: '通常是因為測試時仍連著店內 Wi-Fi，或網址需要你的登入狀態。請務必用手機行動網路、無登入狀態重新測試。',
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F6EE),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFB7E0C8)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(
                      Icons.verified_outlined,
                      color: const Color(0xFF1B7A45),
                      size: 26,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            '符合以上條件後，再回到房間設定網址',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              height: 1.35,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            '請先確認：外網可開啟、直接看得到畫面、不需 App、不需登入店家帳號。',
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.45,
                              color: Color(0xFF3F4A44),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('我已完成測試，回到設定'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideHeading extends StatelessWidget {
  const _GuideHeading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
    );
  }
}

class _GuideCallout extends StatelessWidget {
  const _GuideCallout({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final Color primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: primary.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: primary, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: Color(0xFF3F4A57),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideNotice extends StatelessWidget {
  const _GuideNotice(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Icon(
          Icons.privacy_tip_outlined,
          size: 18,
          color: Color(0xFFB45309),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              height: 1.4,
              color: Color(0xFF92400E),
            ),
          ),
        ),
      ],
    );
  }
}

class _GuideCompareCard extends StatelessWidget {
  const _GuideCompareCard({
    required this.usable,
    required this.title,
    required this.icon,
    required this.points,
  });

  final bool usable;
  final String title;
  final IconData icon;
  final List<String> points;

  @override
  Widget build(BuildContext context) {
    final Color tone = usable
        ? const Color(0xFF1B7A45)
        : const Color(0xFFC2410C);
    final Color background = usable
        ? const Color(0xFFF1F8F2)
        : const Color(0xFFFFF6F0);
    final Color border = usable
        ? const Color(0xFFC8E6C9)
        : const Color(0xFFF3D6C4);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: tone, size: 36),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: tone,
            ),
          ),
          const SizedBox(height: 8),
          for (final String point in points) ...<Widget>[
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    usable ? Icons.check : Icons.close,
                    size: 16,
                    color: tone,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      point,
                      style: const TextStyle(fontSize: 13, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GuideStepData {
  const _GuideStepData({
    required this.step,
    required this.title,
    required this.body,
    required this.note,
    required this.icons,
  });

  final int step;
  final String title;
  final String body;
  final String note;
  final List<IconData> icons;
}

class _GuideStepCard extends StatelessWidget {
  const _GuideStepCard({required this.data});

  final _GuideStepData data;

  @override
  Widget build(BuildContext context) {
    final Color primary = Theme.of(context).colorScheme.primary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              for (final IconData icon in data.icons) ...<Widget>[
                Icon(icon, size: 32, color: primary),
                const SizedBox(width: 6),
              ],
              const Spacer(),
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: primary,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${data.step}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            data.title,
            style: const TextStyle(fontWeight: FontWeight.w800, height: 1.3),
          ),
          const SizedBox(height: 6),
          Text(data.body, style: const TextStyle(fontSize: 13, height: 1.4)),
          const SizedBox(height: 8),
          Text(
            data.note,
            style: const TextStyle(
              fontSize: 12,
              height: 1.4,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideArrow extends StatelessWidget {
  const _GuideArrow();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 28),
      child: Icon(Icons.arrow_forward_rounded, color: Color(0xFF9CA3AF)),
    );
  }
}

class _GuideQaCard extends StatelessWidget {
  const _GuideQaCard({required this.question, required this.answer});

  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            question,
            style: const TextStyle(fontWeight: FontWeight.w800, height: 1.35),
          ),
          const SizedBox(height: 6),
          Text(
            answer,
            style: const TextStyle(
              fontSize: 13,
              height: 1.45,
              color: Color(0xFF4B5563),
            ),
          ),
        ],
      ),
    );
  }
}

void _showEditDeviceDialog(
  BuildContext context,
  String shopId,
  _RoomCameraLine line,
) {
  showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) {
      return _CameraSettingsDialog(
        shopId: shopId,
        line: line,
        hostContext: context,
      );
    },
  );
}

class _CameraSettingsDialog extends StatefulWidget {
  const _CameraSettingsDialog({
    required this.shopId,
    required this.line,
    required this.hostContext,
  });

  final String shopId;
  final _RoomCameraLine line;
  final BuildContext hostContext;

  @override
  State<_CameraSettingsDialog> createState() => _CameraSettingsDialogState();
}

class _CameraSettingsDialogState extends State<_CameraSettingsDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _url;
  late final TextEditingController _note;
  late final TextEditingController _deviceName;
  late final TextEditingController _customerNote;
  late String _mode;
  late String _provider;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _mode = widget.line.viewMode;
    _provider = cameraBrandById(widget.line.provider)?.id ?? '';
    _url = TextEditingController(text: widget.line.url);
    _note = TextEditingController(text: widget.line.note);
    _deviceName = TextEditingController(text: widget.line.externalDeviceName);
    _customerNote = TextEditingController(text: widget.line.customerShareNote);
  }

  @override
  void dispose() {
    _url.dispose();
    _note.dispose();
    _deviceName.dispose();
    _customerNote.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool external = _mode == cameraViewExternalApp;
    final double width = (MediaQuery.sizeOf(context).width - 96).clamp(0, 460);
    return AlertDialog(
      title: Text('${widget.line.roomName} 攝影機設定'),
      content: SizedBox(
        width: width.toDouble(),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SegmentedButton<String>(
                  segments: const <ButtonSegment<String>>[
                    ButtonSegment<String>(
                      value: cameraViewWebUrl,
                      label: Text('網址觀看'),
                    ),
                    ButtonSegment<String>(
                      value: cameraViewExternalApp,
                      label: Text('外部 App'),
                    ),
                  ],
                  selected: <String>{_mode},
                  onSelectionChanged: (Set<String> value) {
                    setState(() => _mode = value.first);
                  },
                ),
                const SizedBox(height: 12),
                if (!external) ...<Widget>[
                  const Text(
                    '請貼上可由店外直接以瀏覽器觀看的 HTTPS 連結。',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _url,
                    keyboardType: TextInputType.url,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    decoration: const InputDecoration(
                      labelText: '外網觀看網址',
                      hintText: 'https://...',
                      helperText: '請先以手機行動網路測試，確認不需使用原廠 App。',
                    ),
                    validator: (String? value) {
                      if (cameraIsDirectHttps(value ?? '')) {
                        return null;
                      }
                      return _httpsUrlError;
                    },
                  ),
                ] else ...<Widget>[
                  if (widget.line.provider.trim().isNotEmpty &&
                      cameraBrandById(widget.line.provider) == null)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text(
                        '目前儲存的品牌尚未開放，請改選已開放品牌。不會自動改成小米。',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF9F1239),
                        ),
                      ),
                    ),
                  DropdownButtonFormField<String>(
                    initialValue: _provider.isEmpty ? null : _provider,
                    decoration: const InputDecoration(labelText: '外部品牌'),
                    items: <DropdownMenuItem<String>>[
                      for (final CameraBrand brand in cameraReleasedBrands)
                        DropdownMenuItem<String>(
                          value: brand.id,
                          child: Text(brand.label),
                        ),
                    ],
                    onChanged: (String? value) {
                      setState(() => _provider = value ?? '');
                    },
                    validator: (String? value) {
                      if (cameraBrandSupportsAccountShare(value)) {
                        return null;
                      }
                      return '請選擇已開放的品牌';
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    cameraExternalWatchReminder(_provider),
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: Color(0xFF92400E),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _deviceName,
                    decoration: const InputDecoration(
                      labelText: '設備辨識名稱（選填）',
                      hintText: '方便在原廠 App 找到這台設備',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _customerNote,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: '給顧客的分享說明（選填）',
                      hintText: '例如：請使用指定地區帳號。不會包含店內備註。',
                    ),
                  ),
                  if (cameraBrandById(_provider) != null)
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: const Text('安裝與分享教學'),
                      children: <Widget>[
                        for (final String step in cameraBrandById(
                          _provider,
                        )!.guide)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text(step),
                            ),
                          ),
                      ],
                    ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: _note,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: '店內備註（選填）',
                    hintText: '只給店內查看，不會傳給顧客',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? '儲存中' : '儲存'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final bool external = _mode == cameraViewExternalApp;
    setState(() => _saving = true);
    try {
      await ShopDeviceService.instance.writePrimaryRoomCamera(
        shopId: widget.shopId,
        roomId: widget.line.roomId,
        roomName: widget.line.roomName,
        primaryDeviceId: widget.line.primary?.id,
        url: external ? '' : _url.text.trim(),
        note: _note.text.trim(),
        enabled: false,
        persistSettings: true,
        siblingDeviceIds: widget.line.siblingIds,
        viewMode: _mode,
        provider: external ? _provider : '',
        externalDeviceName: external ? _deviceName.text.trim() : '',
        customerShareNote: external ? _customerNote.text.trim() : '',
      );
      if (mounted) {
        Navigator.pop(context);
      }
      if (!widget.hostContext.mounted) {
        return;
      }
      ScaffoldMessenger.of(widget.hostContext).showSnackBar(
        SnackBar(
          content: Text(
            external
                ? '外部 App 設定已儲存，請確認品牌與說明後再啟用。分享仍需在原廠 App 手動操作。'
                : '網址已儲存，請測試後再啟用',
          ),
        ),
      );
    } catch (error) {
      debugPrint('儲存攝影機設定失敗：$error');
      if (!mounted) {
        return;
      }
      setState(() => _saving = false);
      if (!widget.hostContext.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        widget.hostContext,
      ).showSnackBar(const SnackBar(content: Text('攝影機設定儲存失敗')));
    }
  }
}

int _compareRoomCodeByDigitGroup(String first, String second) {
  final RegExp pattern = RegExp(r'^(.*?)(\d+)$');
  final RegExpMatch? firstMatch = pattern.firstMatch(first.trim());
  final RegExpMatch? secondMatch = pattern.firstMatch(second.trim());
  if (firstMatch == null || secondMatch == null) {
    return naturalCompare(first, second);
  }
  final String firstPrefix = firstMatch.group(1) ?? '';
  final String secondPrefix = secondMatch.group(1) ?? '';
  final int prefixResult = firstPrefix.toLowerCase().compareTo(
    secondPrefix.toLowerCase(),
  );
  if (prefixResult != 0) {
    return prefixResult;
  }
  final String firstDigits = firstMatch.group(2) ?? '';
  final String secondDigits = secondMatch.group(2) ?? '';
  // 先按照數字位數分組：A1、A2 排在 A01、A02 前面
  final int digitLengthResult = firstDigits.length.compareTo(
    secondDigits.length,
  );
  if (digitLengthResult != 0) {
    return digitLengthResult;
  }
  final int firstNumber = int.tryParse(firstDigits) ?? 0;
  final int secondNumber = int.tryParse(secondDigits) ?? 0;
  return firstNumber.compareTo(secondNumber);
}
