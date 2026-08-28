//lib/features/shop/pages/shop_permission_settings_page.dart
//實際操作權限的畫面

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:petnest_saas/core/constants/shop_roles.dart';
import 'package:petnest_saas/core/services/action_log_service.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/features/shop/widgets/permissions/permission_category_tile.dart';
import 'package:petnest_saas/features/shop/pages/permissions/basic_info_permission_page.dart';
import 'package:petnest_saas/features/shop/pages/permissions/cat_hotel_permission_page.dart';
import 'package:petnest_saas/features/shop/pages/permissions/inventory_permission_page.dart';
import 'package:petnest_saas/features/shop/pages/permissions/store_permission_page.dart';
import 'package:petnest_saas/features/shop/widgets/permissions/permission_member_list_card.dart';
import 'package:petnest_saas/features/shop/widgets/permissions/permission_invite_list_card.dart';
import 'package:petnest_saas/features/shop/pages/permissions/member_permission_detail_page.dart';

class ShopPermissionSettingsPage extends StatefulWidget {
  const ShopPermissionSettingsPage({
    super.key,
    required this.shopId,
    required this.currentUserRole,
  });

  final String shopId;
  final String? currentUserRole;

  @override
  State<ShopPermissionSettingsPage> createState() =>
      _ShopPermissionSettingsPageState();
}

class _ShopPermissionSettingsPageState
    extends State<ShopPermissionSettingsPage> {
  final _emailController = TextEditingController();

  String _selectedRole = ShopRoles.staff;
  bool _saving = false;

  late Map<String, bool> _permissions;

  bool get _isOwner => widget.currentUserRole == ShopRoles.owner;

  String _roleLabel(String role) {
    switch (role) {
      case ShopRoles.owner:
        return '老闆';
      case ShopRoles.staff:
        return '員工';
      default:
        return role;
    }
  }

  String _actionLabel(String action) {
    switch (action) {
      case 'create_invite':
        return '建立員工邀請';
      case 'invite_accepted':
        return '員工接受邀請';
      case 'update_member_permission':
        return '更新成員權限';
      case 'update_permission':
        return '更新權限設定';
      case 'remove_member_invite':
        return '刪除待綁定邀請';
      case 'remove_member':
        return '刪除成員';
      case 'block_date':
        return '關閉預約日期';
      case 'unblock_date':
        return '恢復預約日期';
      case 'update_booking_settings':
        return '更新預約設定';
      default:
        return action == '-' ? '未記錄動作' : action;
    }
  }

  String _targetTypeLabel(String targetType) {
    switch (targetType) {
      case 'shop_member':
        return '店家成員';
      case 'shop_member_invite':
        return '員工邀請';
      case 'shop_permission_settings':
        return '權限設定';
      case 'shop_booking_settings':
        return '預約設定';
      case 'shop_calendar_date':
        return '預約日期';
      default:
        return targetType == '-' ? '未記錄目標' : targetType;
    }
  }

  String _buildLogSubtitle(Map<String, dynamic> log) {
    final targetType = log['targetType']?.toString() ?? '-';
    final operatorEmail = log['operatorEmail']?.toString() ?? '-';
    final operatorRole = log['operatorRole']?.toString() ?? '-';
    final createdAt = log['createdAt'];

    final timeText = createdAt is Timestamp
        ? DateFormat('yyyy-MM-dd HH:mm').format(createdAt.toDate())
        : '-';

    final payload = Map<String, dynamic>.from(log['payload'] ?? {});
    final memberEmail = payload['memberEmail']?.toString() ?? '';
    final changedPermissions = payload['changedPermissions'];

    if (log['action'] == 'update_member_permission' &&
        memberEmail.isNotEmpty &&
        changedPermissions is List &&
        changedPermissions.isNotEmpty) {
      final changes = changedPermissions
          .map((item) {
            final data = Map<String, dynamic>.from(item);
            final key = data['key']?.toString() ?? '';
            final newValue = data['newValue'] == true;

            return '${_permissionLabel(key)}：${newValue ? '開啟' : '關閉'}';
          })
          .join('、');

      return '$timeText\n'
          '對象：$memberEmail｜變更：$changes｜操作者：$operatorEmail｜角色：${_roleLabel(operatorRole)}';
    }

    return '$timeText\n'
        '目標：${_targetTypeLabel(targetType)}｜操作者：$operatorEmail｜角色：${_roleLabel(operatorRole)}';
  }

  String _permissionLabel(String key) {
    switch (key) {
      case 'manage_members':
        return '會員管理';
      case 'edit_basic_info':
        return '店家基本資料';
      case 'edit_business_info':
        return '營業資訊';
      case 'edit_media':
        return '店家封面';
      case 'manage_environment':
        return '環境介紹';
      case 'manage_about':
        return '關於我們';
      case 'manage_modules':
        return '模組設定';
      case 'manage_bookings':
        return '訂單管理';
      case 'manage_booking_settings':
        return '預約管理';
      case 'manage_room_dashboard':
        return '房務管理';
      case 'manage_room_types':
        return '房型管理';
      case 'manage_rooms':
        return '房間管理';
      case 'manage_payment_settings':
        return '付款 / 訂金設定';
      case 'manage_point_redemptions':
        return '實體商品核銷';
      case 'view_inventory':
        return '查看庫存';
      case 'manage_inventory':
        return '管理庫存品項';
      case 'receive_inventory':
        return '進貨';
      case 'adjust_inventory':
        return '出庫與盤點';
      case 'view_inventory_cost':
        return '查看成本';
      case 'view_store_orders':
        return '查看商城訂單';
      case 'manage_store_products':
        return '管理商品與分類';
      case 'manage_store_orders':
        return '管理商城訂單';
      case 'manage_store_settings':
        return '管理賣場設定';
      case 'manage_policy':
        return '入住規則';
      case 'view_reports':
        return '營運報表';
      case 'view_action_logs':
        return '動作紀錄';
      default:
        return key;
    }
  }

  @override
  void initState() {
    super.initState();
    _permissions = ShopService.instance.staffDefaultPermissions();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _applyRoleTemplate(String role) {
    setState(() {
      _selectedRole = role;
      _permissions = Map<String, bool>.from(
        ShopService.instance.defaultPermissionsByRole(role),
      );
    });
  }

  Future<void> _save() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final email = _emailController.text.trim().toLowerCase();
    if (email.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請輸入 Email')));
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      await ShopService.instance.upsertMemberPermissionByEmail(
        shopId: widget.shopId,
        email: email,
        role: _selectedRole,
        permissions: _permissions,
        operatorUid: user.uid,
        operatorRole: widget.currentUserRole ?? ShopRoles.owner,
      );

      _emailController.clear();

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('權限設定已儲存')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('儲存失敗：$e')));
    } finally {
      if (!mounted) return;
      setState(() {
        _saving = false;
      });
    }
  }

  Widget _buildRoleSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: _selectedRole,
              decoration: const InputDecoration(
                labelText: '角色',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: ShopRoles.staff, child: Text('員工')),
              ],
              onChanged: !_isOwner
                  ? null
                  : (value) {
                      if (value == null) return;
                      _applyRoleTemplate(value);
                    },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailController,
              enabled: _isOwner,
              decoration: const InputDecoration(
                labelText: '員工 Email',
                hintText: 'example@gmail.com',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: (!_isOwner || _saving) ? null : _save,
        icon: _saving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.save),
        label: Text(_isOwner ? '儲存權限設定' : '目前只有老闆可修改'),
      ),
    );
  }

  Widget _buildActionLogs() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: ActionLogService.instance.streamShopLogs(widget.shopId),
      builder: (context, snapshot) {
        final logs = (snapshot.data ?? [])
            .where((log) {
              final action = log['action']?.toString() ?? '';

              return [
                'create_invite',
                'invite_accepted',
                'update_member_permission',
                'update_permission',
                'remove_member_invite',
                'remove_member',
              ].contains(action);
            })
            .take(20)
            .toList();
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '動作記錄',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),
                if (logs.isEmpty) const ListTile(title: Text('目前沒有動作記錄')),
                ...logs.map((log) {
                  final action = log['action']?.toString() ?? '-';
                  final targetType = log['targetType']?.toString() ?? '-';
                  final operatorRole = log['operatorRole']?.toString() ?? '-';
                  final operatorEmail = log['operatorEmail']?.toString() ?? '-';

                  final currentUserEmail =
                      FirebaseAuth.instance.currentUser?.email?.toLowerCase() ??
                      '';

                  final displayRole =
                      operatorEmail.toLowerCase() == currentUserEmail
                      ? (widget.currentUserRole ?? operatorRole)
                      : operatorRole;
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.history),
                    title: Text(_actionLabel(action)),
                    subtitle: Text(_buildLogSubtitle(log)),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('權限設定')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              '老闆可用 Email 指定主管或員工。\n'
              '對方先註冊 / 登入，只要 Email 有被指定，就會自動看到該店後台入口。',
            ),
          ),
          const SizedBox(height: 16),
          _buildRoleSelector(),
          const SizedBox(height: 12),
          PermissionCategoryTile(
            title: '基本資訊權限',
            subtitle: '營業資訊、店家封面、前台內容、評價管理',
            icon: Icons.store,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BasicInfoPermissionPage(
                    permissions: _permissions,
                    isOwner: _isOwner,
                    onChanged: (key, value) {
                      setState(() {
                        _permissions[key] = value;
                      });
                    },
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),

          PermissionCategoryTile(
            title: '貓咪旅店權限',
            subtitle: '訂單、預約、房務、房型、房間、設備、收款優惠、住宿加購、入住規則',
            icon: Icons.pets,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CatHotelPermissionPage(
                    permissions: _permissions,
                    isOwner: _isOwner,
                    onChanged: (key, value) {
                      setState(() {
                        _permissions[key] = value;
                      });
                    },
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 12),

          PermissionCategoryTile(
            title: '庫存管理權限',
            subtitle: '查看庫存、品項管理、進貨、盤點與成本',
            icon: Icons.inventory_2_outlined,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => InventoryPermissionPage(
                    permissions: _permissions,
                    isOwner: _isOwner,
                    onChanged: (key, value) {
                      setState(() {
                        _permissions[key] = value;
                      });
                    },
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),

          PermissionCategoryTile(
            title: '賣場權限',
            subtitle: '商城訂單、商品、分類與賣場設定',
            icon: Icons.storefront_outlined,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StorePermissionPage(
                    permissions: _permissions,
                    isOwner: _isOwner,
                    onChanged: (key, value) {
                      setState(() {
                        _permissions[key] = value;
                      });
                    },
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),

          PermissionCategoryTile(
            title: '未來模板權限',
            subtitle: '狗狗旅店、美容、醫院功能',
            icon: Icons.extension,
            onTap: () {},
          ),
          const SizedBox(height: 12),
          _buildSaveButton(),
          const SizedBox(height: 20),
          PermissionMemberListCard(
            shopId: widget.shopId,
            roleLabelBuilder: _roleLabel,
            onTapMember: (member) {
              final role = member['role']?.toString() ?? '-';

              final permissions = ShopService.instance.normalizePermissions(
                member['permissions'],
                role: role,
              );

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MemberPermissionDetailPage(
                    shopId: widget.shopId,
                    memberDocId: member['id']?.toString() ?? '',
                    email: member['email']?.toString() ?? '-',
                    role: role,
                    roleLabel: _roleLabel(role),
                    permissions: permissions,
                    currentUserRole: widget.currentUserRole,
                    permissionLabelBuilder: _permissionLabel,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          PermissionInviteListCard(
            shopId: widget.shopId,
            currentUserRole: widget.currentUserRole,
            isOwner: _isOwner,
            roleLabelBuilder: _roleLabel,
          ),
          const SizedBox(height: 12),
          _buildActionLogs(),
        ],
      ),
    );
  }
}
