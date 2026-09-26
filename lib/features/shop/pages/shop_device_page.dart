// 檔案名稱：lib/features/shop/pages/shop_device_page.dart
// 功能說明：以房間為主的攝影機設定表。同房多筆設備只顯示一筆主設定。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/shop_device_service.dart';
import 'package:petnest_saas/core/services/shop_room_service.dart';
import 'package:petnest_saas/core/utils/natural_sort.dart';
import 'package:petnest_saas/core/widgets/shop_task_center_button.dart';
import 'package:url_launcher/url_launcher.dart';

const String _httpsUrlError = '請輸入可直接開啟的 HTTPS 攝影機網址';
const String _disabledSwitchTip = '請先填寫可從外網直接開啟的 HTTPS 網址';

class ShopDevicePage extends StatelessWidget {
  const ShopDevicePage({super.key, required this.shopId});

  final String shopId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('攝影機設定'),
        actions: <Widget>[ShopTaskCenterButton(shopId: shopId)],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: ShopRoomService.instance.roomsRef(shopId).snapshots(),
        builder:
            (
              BuildContext context,
              AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> roomsSnap,
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
                      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: ShopDeviceService.instance.watchDevices(shopId),
                        builder:
                            (
                              BuildContext context,
                              AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>>
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
                                        DocumentSnapshot<Map<String, dynamic>>
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
                                          child: CircularProgressIndicator(),
                                        );
                                      }
                                      final bool showCameraSection =
                                          shopSnap.data
                                              ?.data()?['showCameraSection'] !=
                                          false;
                                      final List<_RoomCameraLine> lines =
                                          _roomCameraLines(
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
                                                  constraints.maxWidth >= 900;
                                              final double pad = desktop
                                                  ? 24
                                                  : 16;
                                              return ListView(
                                                padding: EdgeInsets.fromLTRB(
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
                                                  const SizedBox(height: 8),
                                                  const _CompatibilityStrip(),
                                                  const SizedBox(height: 12),
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

  bool get enabled => primary?.data()['enabled'] == true;

  bool get platformLocked => primary?.data()['platformLocked'] == true;

  bool get hasValidUrl => _isDirectHttpsCameraUrl(url);

  bool get switchEnabled => hasValidUrl && !platformLocked;
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
  if (!_isDirectHttpsCameraUrl((data['url'] ?? '').toString())) {
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
    _isDirectHttpsCameraUrl((aData['url'] ?? '').toString()),
    _isDirectHttpsCameraUrl((bData['url'] ?? '').toString()),
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

bool _isDirectHttpsCameraUrl(String raw) {
  final Uri? uri = Uri.tryParse(raw.trim());
  if (uri == null || !uri.isScheme('https')) {
    return false;
  }
  return uri.host.trim().isNotEmpty;
}

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
        .where((_RoomCameraLine line) => !line.hasValidUrl)
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
                      ? '入住中的會員只會看見自己房間已啟用的攝影機。'
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
              '僅支援可從店外直接開啟的 HTTPS 網頁觀看連結。',
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
          Expanded(child: Text('外網觀看網址', style: style)),
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
    final String host = line.url.trim().isEmpty ? '尚未設定' : _urlLabel(line.url);
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
                          color: line.url.trim().isEmpty
                              ? const Color(0xFF9CA3AF)
                              : const Color(0xFF374151),
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
    return Tooltip(message: _disabledSwitchTip, child: control);
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
          tooltip: '編輯網址與備註',
          style: style,
          onPressed: () => _showEditDeviceDialog(context, shopId, line),
          icon: const Icon(Icons.edit_outlined, size: 18),
        ),
        IconButton(
          tooltip: '測試網址',
          style: style,
          onPressed: line.hasValidUrl && !line.platformLocked
              ? () => _openExternalCameraUrl(context, line.url)
              : null,
          icon: const Icon(Icons.open_in_new, size: 18),
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
  if (enabled && !line.hasValidUrl) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text(_disabledSwitchTip)));
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
      SnackBar(content: Text('${line.roomName} 已${enabled ? '啟用' : '停用'}')),
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
  final bool launched = await launchUrl(
    Uri.parse(url.trim()),
    mode: LaunchMode.externalApplication,
  );
  if (!launched && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('無法開啟此網址，請確認網址與外網存取設定')));
  }
}

void _showCameraCompatibilitySheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    builder: (BuildContext sheetContext) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: const <Widget>[
          Text(
            '相容性與測試方式',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 14),
          Text(
            'PetNest 不直接串流攝影機，只開啟店家提供的 HTTPS 外部網址。',
            style: TextStyle(height: 1.5),
          ),
          SizedBox(height: 16),
          Text('可使用條件', style: TextStyle(fontWeight: FontWeight.w800)),
          SizedBox(height: 6),
          Text(
            '• 店外網路可開啟\n• 瀏覽器可直接觀看\n• 不需要原廠 App',
            style: TextStyle(height: 1.6),
          ),
          SizedBox(height: 16),
          Text('設定前測試', style: TextStyle(fontWeight: FontWeight.w800)),
          SizedBox(height: 6),
          Text(
            '• 關閉店內 Wi-Fi\n• 用手機行動網路開啟網址\n• 確認不需登入原廠 App 就能看到畫面',
            style: TextStyle(height: 1.6),
          ),
        ],
      );
    },
  );
}

void _showEditDeviceDialog(
  BuildContext context,
  String shopId,
  _RoomCameraLine line,
) {
  final TextEditingController urlController = TextEditingController(
    text: line.url,
  );
  final TextEditingController noteController = TextEditingController(
    text: line.note,
  );
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) {
      final double width = (MediaQuery.sizeOf(dialogContext).width - 96).clamp(
        0,
        420,
      );
      return AlertDialog(
        title: Text('${line.roomName} 攝影機設定'),
        content: SizedBox(
          width: width.toDouble(),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
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
                    controller: urlController,
                    keyboardType: TextInputType.url,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    decoration: const InputDecoration(
                      labelText: '外網觀看網址',
                      hintText: 'https://...',
                      helperText: '請先以手機行動網路測試，確認不需使用原廠 App。',
                    ),
                    validator: (String? value) {
                      if (_isDirectHttpsCameraUrl(value ?? '')) {
                        return null;
                      }
                      return _httpsUrlError;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: '店內備註（選填）',
                      hintText: '例如：NVR 分享連結、更新日期',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => _saveCameraUrl(
              context: context,
              dialogContext: dialogContext,
              formKey: formKey,
              shopId: shopId,
              line: line,
              urlController: urlController,
              noteController: noteController,
            ),
            child: const Text('儲存'),
          ),
        ],
      );
    },
  ).whenComplete(() {
    urlController.dispose();
    noteController.dispose();
  });
}

Future<void> _saveCameraUrl({
  required BuildContext context,
  required BuildContext dialogContext,
  required GlobalKey<FormState> formKey,
  required String shopId,
  required _RoomCameraLine line,
  required TextEditingController urlController,
  required TextEditingController noteController,
}) async {
  if (formKey.currentState?.validate() != true) {
    return;
  }
  try {
    await ShopDeviceService.instance.writePrimaryRoomCamera(
      shopId: shopId,
      roomId: line.roomId,
      roomName: line.roomName,
      primaryDeviceId: line.primary?.id,
      url: urlController.text.trim(),
      note: noteController.text.trim(),
      enabled: false,
      persistSettings: true,
      siblingDeviceIds: line.siblingIds,
    );
    if (dialogContext.mounted) {
      Navigator.pop(dialogContext);
    }
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('網址已儲存，請測試後再啟用')));
  } catch (error) {
    debugPrint('儲存攝影機設定失敗：$error');
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('攝影機設定儲存失敗')));
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
