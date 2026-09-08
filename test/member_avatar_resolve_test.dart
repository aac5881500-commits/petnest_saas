// 檔案名稱：test/member_avatar_resolve_test.dart
// 功能說明：會員頭像解析優先順序與舊訂單快照不相剋

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/widgets/member_avatar.dart';
import 'package:petnest_saas/features/admin/pages/admin_member_list_page.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_customer_section.dart';

void main() {
  test('優先使用會員上傳的 avatarUrl，其次 profile，再才是訂單快照', () {
    expect(
      MemberAvatarSource.resolveUrl(
        customAvatarUrl: 'https://a/custom.jpg',
        profile: <String, dynamic>{'avatarUrl': 'https://a/profile.jpg'},
        member: <String, dynamic>{'avatarUrl': 'https://a/member.jpg'},
        booking: <String, dynamic>{'avatarUrl': 'https://a/old.jpg'},
      ),
      'https://a/custom.jpg',
    );
    expect(
      MemberAvatarSource.resolveUrl(
        profile: <String, dynamic>{'avatarUrl': 'https://a/profile.jpg'},
        member: <String, dynamic>{'avatarUrl': 'https://a/member.jpg'},
        booking: <String, dynamic>{'avatarUrl': 'https://a/old.jpg'},
      ),
      'https://a/profile.jpg',
    );
    expect(
      MemberAvatarSource.resolveUrl(
        member: <String, dynamic>{'avatarUrl': 'https://a/member.jpg'},
        booking: <String, dynamic>{'avatarUrl': 'https://a/old.jpg'},
      ),
      'https://a/member.jpg',
    );
  });

  test('會員已有 avatarUrl 鍵時不可回落到訂單舊圖，空字串顯示預設', () {
    expect(
      MemberAvatarSource.resolveUrl(
        member: <String, dynamic>{'avatarUrl': 'https://a/new.jpg'},
        booking: <String, dynamic>{'avatarUrl': 'https://a/old.jpg'},
      ),
      'https://a/new.jpg',
    );
    expect(
      MemberAvatarSource.resolveUrl(
        member: <String, dynamic>{'avatarUrl': ''},
        booking: <String, dynamic>{'customerAvatarUrl': 'https://a/old.jpg'},
      ),
      isNull,
    );
  });

  test('舊會員沒有 avatarUrl 時可用訂單快照相容', () {
    expect(
      MemberAvatarSource.resolveUrl(
        member: <String, dynamic>{'name': '王小明'},
        booking: <String, dynamic>{'customerAvatarUrl': 'https://a/snap.jpg'},
      ),
      'https://a/snap.jpg',
    );
  });

  test('姓名首字與柔和色不因空名崩潰', () {
    expect(MemberAvatarSource.initialOf('王小明'), '王');
    expect(MemberAvatarSource.initialOf(''), '?');
    expect(
      MemberAvatarSource.colorFor('甲'),
      isNot(MemberAvatarSource.colorFor('乙')),
    );
  });

  testWidgets('無照片頭像顯示首字且 390 不 overflow', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: MemberAvatar(name: '林小花', size: 48)),
      ),
    );
    expect(find.text('林'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('會員卡與顧客區 390/500 不 overflow', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: <Widget>[
                AdminMemberListCard(
                  shopId: 'shop-a',
                  data: <String, dynamic>{
                    'userId': '',
                    'name': '王小明',
                    'phone': '0911111111',
                    'petCount': 2,
                    'bookingCount': 3,
                    'tags': <String>['vip'],
                    'avatarUrl': '',
                  },
                ),
                AdminBookingCustomerSection(
                  data: <String, dynamic>{
                    'customerName': '王小明',
                    'customerPhone': '0911111111',
                  },
                  emergency: <String, dynamic>{},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    tester.view.physicalSize = const Size(500, 900);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
