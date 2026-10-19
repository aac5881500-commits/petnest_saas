// 檔案名稱：test/shop_contact_setup_guide_test.dart
// 功能說明：首次電話與地址完成條件，以及引導區塊在窄螢幕不溢出。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/legal_pet/shop_profile_lock.dart';
import 'package:petnest_saas/features/shop/widgets/shop_contact_setup_guide.dart';

void main() {
  test('只有縣市區域不算地址完成，電話與詳細地址要同時有效', () {
    expect(
      isAddressSetupCompleted({
        'city': '台北市',
        'district': '大安區',
        'address': '',
      }),
      isFalse,
    );
    expect(
      shopContactStepReady(
        phone: '02-12345678',
        city: '台北市',
        district: '大安區',
        address: '',
        cityKnown: true,
        districtKnown: true,
      ),
      isFalse,
    );
    expect(validateShopContactPhone('   '), '請填寫店家聯絡電話');
    expect(validateShopContactPhone('abc'), isNotNull);
    expect(validateShopContactPhone('0912345678'), isNull);
    expect(validateShopContactPhone('+886912345678'), isNull);
    expect(
      shopContactStepReady(
        phone: '0912-345-678',
        city: '台北市',
        district: '大安區',
        address: '復興南路一段1號',
        cityKnown: true,
        districtKnown: true,
      ),
      isTrue,
    );
    expect(isPhoneSetupCompleted({'phone': '0912345678'}), isTrue);
    expect(isPhoneSetupCompleted({'phone': ''}), isFalse);
  });

  testWidgets('首次引導在手機與桌機寬度不溢出', (tester) async {
    for (final width in <double>[320, 390, 1440]) {
      tester.view.resetPhysicalSize();
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: width,
              child: ListView(
                children: [
                  ShopContactSetupHeader(
                    shopName: '喵星人貓咪旅館',
                    showActivationProgress: true,
                  ),
                  SizedBox(height: 12),
                  ShopContactSafetyNote(),
                  ShopLocationInfoCard(
                    city: '新竹縣',
                    district: '湖口鄉',
                    complete: true,
                    onRequestChange: () {},
                  ),
                  ShopLocationInfoCard(
                    city: '',
                    district: '',
                    complete: false,
                    onRequestChange: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('新竹縣・湖口鄉'), findsOneWidget);
      expect(find.byType(DropdownButtonFormField<String>), findsNothing);
      expect(find.text('目前店家所在地資料不完整，請透過既有資料修正流程處理。'), findsOneWidget);
      expect(find.text('先完成旅社的基本聯絡資訊'), findsOneWidget);
      expect(find.text('步驟 1／3'), findsOneWidget);
      expect(find.textContaining('啟用碼驗證'), findsOneWidget);
      expect(find.textContaining('完善基本資料'), findsOneWidget);
      expect(find.textContaining('開始設定旅社'), findsOneWidget);
      expect(find.text('請確認資料正確'), findsOneWidget);
    }
  });
}
