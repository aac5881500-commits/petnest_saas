// 檔案名稱：lib/features/admin/widgets/admin_shop_identity_debug_card.dart
// 功能說明：僅 debug 顯示目前 UID 與店主／成員規則對照，避免再猜權限

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/shop_staff_identity_snapshot.dart';
import 'package:petnest_saas/core/services/shop_member_permission_service.dart';

class AdminShopIdentityDebugCard extends StatefulWidget {
  const AdminShopIdentityDebugCard({
    super.key,
    required this.shopId,
    required this.bookingShopId,
    required this.settlementLocked,
  });

  final String shopId;
  final String bookingShopId;
  final bool settlementLocked;

  @override
  State<AdminShopIdentityDebugCard> createState() =>
      _AdminShopIdentityDebugCardState();
}

class _AdminShopIdentityDebugCardState
    extends State<AdminShopIdentityDebugCard> {
  ShopStaffIdentitySnapshot? _snapshot;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant AdminShopIdentityDebugCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shopId != widget.shopId ||
        oldWidget.bookingShopId != widget.bookingShopId ||
        oldWidget.settlementLocked != widget.settlementLocked) {
      _load();
    }
  }

  Future<void> _load() async {
    try {
      await ShopMemberPermissionService.instance.syncOwnerMembershipForShop(
        widget.shopId,
      );
      if (!kDebugMode) return;
      final ShopStaffIdentitySnapshot snapshot =
          await ShopMemberPermissionService.instance.inspectShopIdentity(
            shopId: widget.shopId,
            bookingShopId: widget.bookingShopId,
            settlementLocked: widget.settlementLocked,
          );
      debugPrint(ShopOwnerIdentity.debugText(snapshot));
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _error = null;
      });
    } catch (error) {
      debugPrint('SHOP_IDENTITY inspect failed: $error');
      if (!mounted) return;
      setState(() => _error = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) {
      return const SizedBox.shrink();
    }
    final ShopStaffIdentitySnapshot? snapshot = _snapshot;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(12),
        ),
        child: SelectableText(
          _error ??
              (snapshot == null
                  ? 'SHOP_IDENTITY loading...'
                  : ShopOwnerIdentity.debugText(snapshot)),
          style: const TextStyle(
            color: Color(0xFFD1FAE5),
            fontSize: 11,
            height: 1.45,
            fontFamily: 'monospace',
          ),
        ),
      ),
    );
  }
}
