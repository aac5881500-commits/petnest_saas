// 檔案名稱：test/pet_snapshot_test.dart
// 功能說明：寵物快照欄位映射與合併

import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/pet_snapshot.dart';
import 'package:petnest_saas/core/navigation/admin_booking_route.dart';
import 'package:petnest_saas/core/services/pet_shop_form_answers.dart';
import 'package:petnest_saas/core/utils/natural_sort.dart';

void main() {
  test('species/type 不誤用 breed，isNeutered=false 會保留', () {
    final Map<String, dynamic> snap = PetSnapshot.fromPet(<String, dynamic>{
      'petId': 'p1',
      'name': '咪',
      'type': 'cat',
      'species': 'cat',
      'breed': '英國短毛',
      'isNeutered': false,
    });
    expect(snap['species'], 'cat');
    expect(snap['type'], 'cat');
    expect(snap['breed'], '英國短毛');
    expect(snap['isNeutered'], isFalse);
    expect(PetSnapshot.isNeuteredFalse(snap), isTrue);
    expect(
      PetSnapshot.visibleRows(
        snap,
      ).any((MapEntry<String, String> e) => e.value == '未結紮'),
      isTrue,
    );
  });

  test('訂單快照優先，缺欄位才用會員寵物補', () {
    final Map<String, dynamic> merged = PetSnapshot.merge(
      snapshot: <String, dynamic>{'petId': 'p1', 'name': '訂單名', 'gender': '公'},
      fallback: <String, dynamic>{
        'petId': 'p1',
        'name': '會員名',
        'gender': '母',
        'litterType': '豆腐砂',
        'vaccine': '定期',
      },
    );
    expect(merged['name'], '訂單名');
    expect(merged['gender'], '公');
    expect(merged['litterType'], '豆腐砂');
  });

  test('疫苗不單獨當成疾病醫療，也不觸發疾病提醒', () {
    final Map<String, dynamic> pet = PetSnapshot.fromPet(<String, dynamic>{
      'name': '咪',
      'vaccine': '定期施打',
    });
    expect(
      PetSnapshot.safetyRows(
        pet,
      ).any((MapEntry<String, String> e) => e.key == '疾病／醫療'),
      isFalse,
    );
    expect(PetSnapshot.hasDiseaseAlert(pet), isFalse);
  });

  test('可餵藥不顯示疾病提醒', () {
    final Map<String, dynamic> pet = PetSnapshot.fromPet(<String, dynamic>{
      'name': '咪',
      'canMedicate': true,
    });
    expect(PetSnapshot.hasDiseaseAlert(pet), isFalse);
    expect(
      PetSnapshot.safetyRows(pet).any((MapEntry<String, String> e) => e.key == '餵藥'),
      isFalse,
    );
  });

  test('找不到寵物時仍可顯示空摘要', () {
    final Map<String, dynamic> merged = PetSnapshot.merge(
      snapshot: <String, dynamic>{'petId': 'gone', 'name': ''},
    );
    expect(PetSnapshot.visibleRows(merged), isEmpty);
  });

  test('自訂表單只解析目前 shopId', () {
    final Map<String, dynamic>? a = PetShopFormAnswers.resolve(
      shopId: 'shop-a',
      petData: <String, dynamic>{
        'customFormAnswersByShop': <String, dynamic>{
          'shop-a': <String, dynamic>{'formId': 'a'},
          'shop-b': <String, dynamic>{'formId': 'b'},
        },
      },
    );
    expect(a?['formId'], 'a');
  });

  test('自然排序 A2、A3、A10', () {
    final List<String> rooms = <String>['A10', 'A2', 'A3']
      ..sort(NaturalSort.compare);
    expect(rooms, <String>['A2', 'A3', 'A10']);
  });

  test('安親路由分類：bookingKind / serviceType / 舊欄位', () {
    expect(
      AdminBookingRoute.isDaycareBooking(<String, dynamic>{
        'bookingKind': 'daycare',
      }),
      isTrue,
    );
    expect(
      AdminBookingRoute.isDaycareBooking(<String, dynamic>{
        'serviceType': 'daycare',
      }),
      isTrue,
    );
    expect(
      AdminBookingRoute.isDaycareBooking(<String, dynamic>{
        'pricingMode': 'room_based',
      }),
      isTrue,
    );
    expect(
      AdminBookingRoute.isDaycareBooking(<String, dynamic>{
        'daycarePlanId': 'plan-1',
      }),
      isTrue,
    );
    expect(
      AdminBookingRoute.isDaycareBooking(<String, dynamic>{
        'bookingKind': 'accommodation',
      }),
      isFalse,
    );
  });
}
