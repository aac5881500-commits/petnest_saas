import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/constants/shop_permission_keys.dart';
import 'package:petnest_saas/core/constants/shop_roles.dart';
import 'package:petnest_saas/core/services/shop_permission_catalog.dart';
import 'package:petnest_saas/features/shop/widgets/permissions/shop_permission_v2_editor.dart';

void main() {
  test('模板不會打開老闆專屬權限，也不會立刻視為已儲存', () {
    for (final Map<String, bool> template in <Map<String, bool>>[
      ShopPermissionCatalog.templateBasicStaff(),
      ShopPermissionCatalog.templateAdvancedStaff(),
      ShopPermissionCatalog.templateManager(),
    ]) {
      expect(template[ShopPermissionKeys.managePaymentSettings], isNot(true));
      expect(ShopPermissionCatalog.sameGrantable(template, template), isTrue);
    }
    expect(
      ShopPermissionCatalog.templateManager()[ShopPermissionKeys
          .manageMemberPoints],
      isNot(true),
    );
    expect(
      ShopPermissionCatalog.templateBasicStaff()[ShopPermissionKeys
          .manageBookings],
      isTrue,
    );
  });

  test('店長與員工不能提升成老闆或任命店長', () {
    expect(
      ShopPermissionCatalog.roleChangeBlock(
        operatorRole: ShopRoles.manager,
        targetCurrentRole: ShopRoles.staff,
        nextRole: ShopRoles.manager,
        editingSelf: false,
      ),
      isNotNull,
    );
    expect(
      ShopPermissionCatalog.roleChangeBlock(
        operatorRole: ShopRoles.staff,
        targetCurrentRole: ShopRoles.staff,
        nextRole: ShopRoles.staff,
        editingSelf: true,
      ),
      isNotNull,
    );
    expect(
      ShopPermissionCatalog.roleChangeBlock(
        operatorRole: ShopRoles.owner,
        targetCurrentRole: ShopRoles.staff,
        nextRole: ShopRoles.owner,
        editingSelf: false,
      ),
      isNotNull,
    );
    expect(
      ShopPermissionCatalog.roleChangeBlock(
        operatorRole: ShopRoles.manager,
        targetCurrentRole: ShopRoles.staff,
        nextRole: ShopRoles.staff,
        editingSelf: false,
      ),
      isNull,
    );
  });

  test('店長不能授予自己沒有的權限', () {
    final Map<String, bool> requested = ShopPermissionCatalog.templateManager();
    requested[ShopPermissionKeys.manageMemberPoints] = true;
    requested[ShopPermissionKeys.managePaymentSettings] = true;
    final Map<String, bool> clamped = ShopPermissionCatalog.clampForOperator(
      operatorRole: ShopRoles.manager,
      operatorPermissions: <String, bool>{
        ShopPermissionKeys.manageBookings: true,
      },
      requested: requested,
    );
    expect(clamped[ShopPermissionKeys.managePaymentSettings], isNot(true));
    expect(clamped[ShopPermissionKeys.manageMemberPoints], isNot(true));
    expect(clamped[ShopPermissionKeys.manageStaff], isNot(true));
    expect(clamped[ShopPermissionKeys.manageBookings], isTrue);
  });

  test('敏感通知不會給未授權角色', () {
    expect(ShopPermissionCatalog.audienceForType('payment_failed'), 'owner');
    expect(ShopPermissionCatalog.audienceForType('plan'), 'owner');
    expect(ShopPermissionCatalog.audienceForType('system'), 'everyone');
    expect(
      ShopPermissionCatalog.canReadNotice(
        role: ShopRoles.manager,
        canViewAnnouncements: true,
        type: 'payment_failed',
        audience: 'owner',
      ),
      isFalse,
    );
    expect(
      ShopPermissionCatalog.canReadNotice(
        role: ShopRoles.staff,
        canViewAnnouncements: false,
        type: 'update',
        audience: 'announcement',
      ),
      isFalse,
    );
    expect(
      ShopPermissionCatalog.canReadNotice(
        role: ShopRoles.staff,
        canViewAnnouncements: true,
        type: 'system',
        audience: 'everyone',
      ),
      isTrue,
    );
  });

  test('畫面不再提供一鍵模板，角色切換也不會自動打開權限', () {
    expect(ShopPermissionCatalog.quickTemplatesEnabled, isFalse);
    final Map<String, bool> current = ShopPermissionCatalog.emptyGrantable();
    current[ShopPermissionKeys.manageBookings] = true;
    final List<ShopPermissionChange> lost =
        ShopPermissionCatalog.permissionsLostOnRole(
          nextRole: ShopRoles.manager,
          permissions: current,
        );
    expect(lost, isEmpty);
    expect(current[ShopPermissionKeys.manageBookings], isTrue);
    expect(current[ShopPermissionKeys.managePaymentSettings], isNot(true));
  });

  test('已有店長時不能再任命第二名，撤任現任店長不受這條限制', () {
    final List<Map<String, dynamic>> members = <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'shop_manager',
        'role': ShopRoles.manager,
        'email': 'lead@example.com',
        'status': 'active',
      },
      <String, dynamic>{
        'id': 'shop_staff',
        'role': ShopRoles.staff,
        'email': 'staff@example.com',
        'status': 'active',
      },
    ];
    expect(
      ShopPermissionCatalog.secondManagerBlock(
        nextRole: ShopRoles.manager,
        editingMemberId: 'shop_staff',
        members: members,
        invites: const <Map<String, dynamic>>[],
      ),
      '此店已有店長（lead@example.com），請先撤換現任店長後再任命',
    );
    expect(
      ShopPermissionCatalog.secondManagerBlock(
        nextRole: ShopRoles.staff,
        editingMemberId: 'shop_manager',
        members: members,
        invites: const <Map<String, dynamic>>[],
      ),
      isNull,
    );
    expect(
      ShopPermissionCatalog.secondManagerBlock(
        nextRole: ShopRoles.manager,
        editingMemberId: null,
        members: const <Map<String, dynamic>>[],
        invites: <Map<String, dynamic>>[
          <String, dynamic>{'role': ShopRoles.manager},
        ],
      ),
      '已有待接受的店長邀請，請先取消後再任命',
    );
  });

  test('改為員工時只關閉員工不能使用的權限', () {
    final Map<String, bool> current = ShopPermissionCatalog.emptyGrantable();
    current[ShopPermissionKeys.manageStaff] = true;
    current[ShopPermissionKeys.manageBookings] = true;
    final List<ShopPermissionChange> lost =
        ShopPermissionCatalog.permissionsLostOnRole(
          nextRole: ShopRoles.staff,
          permissions: current,
        );
    expect(lost, hasLength(1));
    expect(lost.single.key, ShopPermissionKeys.manageStaff);
    expect(current[ShopPermissionKeys.manageBookings], isTrue);
  });

  test('操作紀錄用摘要，不輸出原始權限鍵', () {
    final ShopPermissionLogText text = ShopPermissionCatalog.describeActionLog(
      action: 'update_member_permission',
      operatorRole: ShopRoles.owner,
      timeText: '10/09 14:30',
      payload: <String, dynamic>{
        'memberEmail': 'staff@example.com',
        'previousRole': ShopRoles.staff,
        'memberRole': ShopRoles.staff,
        'changedPermissions': <Map<String, dynamic>>[
          <String, dynamic>{
            'key': ShopPermissionKeys.manageBookings,
            'oldValue': false,
            'newValue': true,
          },
          <String, dynamic>{
            'key': ShopPermissionKeys.manageMembers,
            'oldValue': true,
            'newValue': false,
          },
          <String, dynamic>{
            'key': 'not_a_real_permission_key',
            'oldValue': false,
            'newValue': true,
          },
        ],
      },
    );
    expect(text.headline, '10/09 14:30｜老闆修改員工權限｜新增 2 項、移除 1 項');
    expect(text.headline.contains('not_a_real_permission_key'), isFalse);
    expect(
      text.details.join('\n').contains('not_a_real_permission_key'),
      isFalse,
    );
    expect(text.details, contains('對象：staff@example.com'));
  });

  testWidgets('權限頁在手機與桌機寬度不溢出', (WidgetTester tester) async {
    Future<void> pump(Size size) async {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShopPermissionV2Editor(
              role: ShopRoles.staff,
              permissions: ShopPermissionCatalog.emptyGrantable(),
              canEdit: true,
              canPickManager: true,
              onRoleChanged: (_) {},
              onToggle: (_, _) {},
              onToggleCategory: (_, _) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(ShopPermissionV2Editor), findsOneWidget);
      expect(find.text('基本員工', skipOffstage: false), findsNothing);
      final Finder vertical = find.byWidgetPredicate(
        (Widget widget) => widget is Scrollable && widget.axis == Axis.vertical,
      );
      await tester.drag(vertical, const Offset(0, -600));
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.drag(vertical, const Offset(0, -1200));
      await tester.pump();
      expect(tester.takeException(), isNull);
    }

    await pump(const Size(390, 844));
    await pump(const Size(1280, 800));
    await tester.binding.setSurfaceSize(null);
  });
}
