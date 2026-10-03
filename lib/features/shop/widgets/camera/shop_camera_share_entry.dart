// 檔案名稱：lib/features/shop/widgets/camera/shop_camera_share_entry.dart
// 功能說明：攝影機分享申請入口。只統計待邀請與待取消，失敗時不顯示 0。

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:petnest_saas/core/models/camera_access_policy.dart';
import 'package:petnest_saas/core/services/camera_access_service.dart';
import 'package:petnest_saas/core/services/shop_task_center_service.dart';
import 'package:petnest_saas/features/shop/pages/shop_camera_access_page.dart';

class ShopCameraShareEntryView {
  const ShopCameraShareEntryView({
    required this.loading,
    required this.pendingCount,
    required this.revokeCount,
    this.errorMessage = '',
  });

  final bool loading;
  final int pendingCount;
  final int revokeCount;
  final String errorMessage;

  bool get failed => errorMessage.isNotEmpty;

  String get subtitle {
    if (loading) {
      return '讀取分享申請數量';
    }
    if (failed) {
      return errorMessage;
    }
    return '待邀請 $pendingCount　待取消 $revokeCount';
  }

  int get badgeCount => failed || loading ? 0 : pendingCount + revokeCount;
}

class ShopCameraShareEntry extends StatefulWidget {
  const ShopCameraShareEntry({
    super.key,
    required this.shopId,
    required this.builder,
    this.enabled = true,
  });

  final String shopId;
  final bool enabled;
  final Widget Function(BuildContext context, ShopCameraShareEntryView view)
  builder;

  @override
  State<ShopCameraShareEntry> createState() => _ShopCameraShareEntryState();
}

class _ShopCameraShareEntryState extends State<ShopCameraShareEntry> {
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  ShopCameraShareEntryView _view = const ShopCameraShareEntryView(
    loading: true,
    pendingCount: 0,
    revokeCount: 0,
  );
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void didUpdateWidget(ShopCameraShareEntry oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shopId != widget.shopId) {
      _listen();
    }
  }

  @override
  void dispose() {
    _generation++;
    _sub?.cancel();
    super.dispose();
  }

  void _listen() {
    final int generation = ++_generation;
    _sub?.cancel();
    _view = const ShopCameraShareEntryView(
      loading: true,
      pendingCount: 0,
      revokeCount: 0,
    );
    _sub = CameraAccessService.instance
        .watchShopActiveRequests(widget.shopId)
        .listen(
          (QuerySnapshot<Map<String, dynamic>> snapshot) {
            if (!mounted || generation != _generation) {
              return;
            }
            int pending = 0;
            int revoke = 0;
            for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
                in snapshot.docs) {
              final String status = (doc.data()['status'] ?? '').toString();
              if (status == cameraRequestPending) {
                pending++;
              } else if (status == cameraRequestRevocationPending) {
                revoke++;
              }
            }
            setState(() {
              _view = ShopCameraShareEntryView(
                loading: false,
                pendingCount: pending,
                revokeCount: revoke,
              );
            });
          },
          onError: (Object error) {
            if (!mounted || generation != _generation) {
              return;
            }
            final String code = firebaseFailureCode(error);
            debugPrint(
              'cameraShareEntry source=camera_access_requests.active '
              'code=$code shopId=${widget.shopId}',
            );
            setState(() {
              _view = ShopCameraShareEntryView(
                loading: false,
                pendingCount: 0,
                revokeCount: 0,
                errorMessage: cameraAccessQueryErrorMessage(
                  code: code,
                  source: '進行中的分享申請',
                ),
              );
            });
          },
        );
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _view);
  }
}

void openShopCameraAccessPage(BuildContext context, String shopId) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ShopCameraAccessPage(shopId: shopId),
    ),
  );
}
