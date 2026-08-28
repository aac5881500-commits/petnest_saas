// lib/features/shop/pages/permissions/member_permission_detail_page.dart
// 👤 成員權限編輯頁
//
// 用途：
// - 從權限設定頁的「目前成員」點進來
// - 查看指定成員角色與已開啟權限
// - 可直接修改該成員權限並儲存
//
// 權限規則：
// - 店家基本資料：固定只有 owner 可修改
// - 模組設定：固定只有 owner 可操作
// - 權限設定：固定只有 owner 可操作
// - 條款同意紀錄：固定可查看，不列入權限

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/core/constants/shop_permission_keys.dart';
import 'package:petnest_saas/core/constants/shop_roles.dart';

class MemberPermissionDetailPage extends StatefulWidget {
  const MemberPermissionDetailPage({
    super.key,
    required this.shopId,
    required this.memberDocId,
    required this.email,
    required this.role,
    required this.roleLabel,
    required this.permissions,
    required this.currentUserRole,
    required this.permissionLabelBuilder,
  });

  final String shopId;
  final String memberDocId;
  final String email;
  final String role;
  final String roleLabel;
  final Map<String, bool> permissions;
  final String? currentUserRole;
  final String Function(String key) permissionLabelBuilder;

  @override
  State<MemberPermissionDetailPage> createState() =>
      _MemberPermissionDetailPageState();
}

class _MemberPermissionDetailPageState
    extends State<MemberPermissionDetailPage> {
  late Map<String, bool> _permissions;

  bool _saving = false;

  bool get _isOwnerMember => widget.role == ShopRoles.owner;

  bool get _canEdit => !_isOwnerMember;

  @override
  void initState() {
    super.initState();

    _permissions = Map<String, bool>.from(widget.permissions);
  }

  Future<void> _deleteMember() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('刪除成員'),
          content: Text(
            '確定要刪除 ${widget.email} 嗎？\n'
            '刪除後對方將無法進入此店家後台。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('刪除'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await ShopService.instance.removeMember(
        memberDocId: widget.memberDocId,
        shopId: widget.shopId,
        operatorUid: user.uid,
        operatorRole: widget.currentUserRole ?? 'owner',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('成員已刪除')));

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('刪除失敗：$e')));
    }
  }

  Future<void> _save() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _saving = true;
    });

    try {
      await ShopService.instance.updateMemberPermission(
        memberDocId: widget.memberDocId,
        shopId: widget.shopId,
        role: widget.role,
        permissions: _permissions,
        operatorUid: user.uid,
        operatorRole: widget.currentUserRole ?? 'owner',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('權限更新成功')));

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('更新失敗：$e')));
    } finally {
      if (!mounted) return;

      setState(() {
        _saving = false;
      });
    }
  }

  Widget _buildPermissionSwitch(String key, {String? title, String? subtitle}) {
    final value = _isOwnerMember ? true : (_permissions[key] ?? false);

    return SwitchListTile(
      value: value,
      title: Text(title ?? widget.permissionLabelBuilder(key)),
      subtitle: subtitle == null ? null : Text(subtitle),
      onChanged: _canEdit
          ? (value) {
              setState(() {
                _permissions[key] = value;
              });
            }
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('成員權限'),
        actions: [
          if (!_isOwnerMember)
            IconButton(
              onPressed: _deleteMember,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.person),
              title: Text(widget.email),
              subtitle: Text('角色：${widget.roleLabel}'),
            ),
          ),

          const SizedBox(height: 12),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '權限開關',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  /// ===== 基本資訊 =====
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '基本資訊',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  ...[
                    _buildPermissionSwitch(
                      ShopPermissionKeys.manageMembers,
                      title: '會員管理',
                      subtitle: '可查看與管理會員資料',
                    ),
                    _buildPermissionSwitch(
                      ShopPermissionKeys.editBusinessInfo,
                      title: '營業資訊',
                      subtitle: '可修改營業時間與服務項目',
                    ),
                    _buildPermissionSwitch(
                      ShopPermissionKeys.editMedia,
                      title: '店家封面',
                      subtitle: '可修改 Logo 與封面圖片',
                    ),
                    _buildPermissionSwitch(
                      ShopPermissionKeys.manageFrontendContent,
                      title: '前台內容',
                      subtitle: '可管理環境介紹、關於我們、公告管理、常見問題',
                    ),
                    _buildPermissionSwitch(
                      ShopPermissionKeys.manageReviews,
                      title: '評價管理',
                      subtitle: '可查看、回覆、隱藏店家評價',
                    ),
                  ],

                  const Divider(height: 28),

                  /// ===== 貓咪旅店 =====
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '貓咪旅店',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  ...[
                    _buildPermissionSwitch(
                      ShopPermissionKeys.manageBookings,
                      title: '訂單管理',
                      subtitle: '可查看與管理住宿訂單',
                    ),
                    _buildPermissionSwitch(
                      ShopPermissionKeys.manageBookingSettings,
                      title: '預約管理',
                      subtitle: '可開關前台預約、管理可預約日期',
                    ),
                    _buildPermissionSwitch(
                      ShopPermissionKeys.manageRoomDashboard,
                      title: '房務管理',
                      subtitle: '可操作入住、退房、房間狀態',
                    ),
                    _buildPermissionSwitch(
                      ShopPermissionKeys.manageRoomTypes,
                      title: '房型管理',
                      subtitle: '可新增與修改房型',
                    ),
                    _buildPermissionSwitch(
                      ShopPermissionKeys.manageRooms,
                      title: '房間管理',
                      subtitle: '可新增與修改實際房間',
                    ),
                    _buildPermissionSwitch(
                      ShopPermissionKeys.manageDevices,
                      title: '設備管理',
                      subtitle: '可管理攝影機、溫度監控與房間設備',
                    ),
                    _buildPermissionSwitch(
                      ShopPermissionKeys.managePaymentSettings,
                      title: '營運設定',
                      subtitle: '設定訂金、優惠與點數制度',
                    ),
                    _buildPermissionSwitch(
                      ShopPermissionKeys.manageAddons,
                      title: '住宿加購 / 附加服務',
                      subtitle: '可管理住宿加購與額外服務',
                    ),
                    _buildPermissionSwitch(
                      ShopPermissionKeys.managePolicy,
                      title: '入住規則',
                      subtitle: '可修改入住條款與規則',
                    ),
                  ],

                  const Divider(height: 28),

                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '庫存管理',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  ...[
                    _buildPermissionSwitch(
                      ShopPermissionKeys.viewInventory,
                      title: '查看庫存',
                      subtitle: '可查看庫存品項、數量與異動流水',
                    ),
                    _buildPermissionSwitch(
                      ShopPermissionKeys.manageInventory,
                      title: '管理庫存品項',
                      subtitle: '可新增、編輯庫存品項與住宿耗材設定',
                    ),
                    _buildPermissionSwitch(
                      ShopPermissionKeys.receiveInventory,
                      title: '進貨',
                      subtitle: '可執行進貨並建立進貨批次',
                    ),
                    _buildPermissionSwitch(
                      ShopPermissionKeys.adjustInventory,
                      title: '出庫與盤點',
                      subtitle: '可執行手動出庫與盤點調整',
                    ),
                    _buildPermissionSwitch(
                      ShopPermissionKeys.viewInventoryCost,
                      title: '查看成本',
                      subtitle: '可查看進貨單價與估計庫存成本',
                    ),
                  ],

                  const Divider(height: 28),

                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '賣場',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  ...[
                    _buildPermissionSwitch(
                      ShopPermissionKeys.viewStoreOrders,
                      title: '查看商城訂單',
                      subtitle: '可查看商城訂單列表與詳情',
                    ),
                    _buildPermissionSwitch(
                      ShopPermissionKeys.manageStoreProducts,
                      title: '管理商品與分類',
                      subtitle: '可新增、編輯商品與分類',
                    ),
                    _buildPermissionSwitch(
                      ShopPermissionKeys.manageStoreOrders,
                      title: '管理商城訂單',
                      subtitle: '可備貨、標記可取貨、完成與取消',
                    ),
                    _buildPermissionSwitch(
                      ShopPermissionKeys.manageStoreSettings,
                      title: '管理賣場設定',
                      subtitle: '可修改自取說明與前台開關',
                    ),
                  ],

                  const SizedBox(height: 8),

                  Text(
                    '店家基本資料、模組設定、權限設定固定只有老闆可操作，不開放給員工。',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (_saving || !_canEdit) ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: Text(_saving ? '儲存中...' : '儲存權限'),
            ),
          ),
        ],
      ),
    );
  }
}
