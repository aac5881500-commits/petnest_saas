// 檔案名稱：lib/features/platform/widgets/platform_transfer_shop_owner_dialog.dart
// 功能說明：平台根管理員轉移唯一店主（ownerUid + shop_members），可切回上一任

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/shop_member_permission_service.dart';

class PlatformTransferShopOwnerDialog extends StatefulWidget {
  const PlatformTransferShopOwnerDialog({
    super.key,
    required this.shopId,
    required this.shopName,
    required this.currentOwnerUid,
    required this.previousOwnerUid,
  });

  final String shopId;
  final String shopName;
  final String currentOwnerUid;
  final String previousOwnerUid;

  @override
  State<PlatformTransferShopOwnerDialog> createState() =>
      _PlatformTransferShopOwnerDialogState();
}

class _PlatformTransferShopOwnerDialogState
    extends State<PlatformTransferShopOwnerDialog> {
  late final TextEditingController _uidController;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _uidController = TextEditingController(text: widget.currentOwnerUid);
  }

  @override
  void dispose() {
    _uidController.dispose();
    super.dispose();
  }

  Future<void> _submit(String uid) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ShopMemberPermissionService.instance.transferShopOwner(
        shopId: widget.shopId,
        newOwnerUid: uid,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final String myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return AlertDialog(
      title: Text('轉移店主｜${widget.shopName}'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('目前 ownerUid：${widget.currentOwnerUid}'),
            Text(
              widget.previousOwnerUid.isEmpty
                  ? '上一任店主：尚未記錄'
                  : '上一任店主：${widget.previousOwnerUid}',
            ),
            const SizedBox(height: 8),
            const Text('轉移後只會有一位 role=owner。舊店主改為員工，之後可用「切回上一任」同步回去。'),
            const SizedBox(height: 12),
            TextField(
              controller: _uidController,
              enabled: !_busy,
              decoration: const InputDecoration(
                labelText: '新店主 Firebase UID',
                border: OutlineInputBorder(),
              ),
            ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        if (widget.previousOwnerUid.isNotEmpty)
          TextButton(
            onPressed: _busy ? null : () => _submit(widget.previousOwnerUid),
            child: const Text('切回上一任'),
          ),
        if (myUid.isNotEmpty)
          TextButton(
            onPressed: _busy ? null : () => _submit(myUid),
            child: const Text('暫時轉給我'),
          ),
        FilledButton(
          onPressed: _busy ? null : () => _submit(_uidController.text),
          child: Text(_busy ? '同步中…' : '確認轉移'),
        ),
      ],
    );
  }
}
