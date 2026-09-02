import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_addons_helper.dart';

void main() {
  group('BookingAddonsHelper.parseBool', () {
    test('bool 維持原值', () {
      expect(BookingAddonsHelper.parseBool(true), isTrue);
      expect(BookingAddonsHelper.parseBool(false), isFalse);
    });

    test('num 0 為 false、非 0 為 true', () {
      expect(BookingAddonsHelper.parseBool(0), isFalse);
      expect(BookingAddonsHelper.parseBool(1), isTrue);
      expect(BookingAddonsHelper.parseBool(2), isTrue);
    });

    test('字串 true/1 與 false/0', () {
      expect(BookingAddonsHelper.parseBool('true'), isTrue);
      expect(BookingAddonsHelper.parseBool('1'), isTrue);
      expect(BookingAddonsHelper.parseBool('false'), isFalse);
      expect(BookingAddonsHelper.parseBool('0'), isFalse);
    });

    test('欄位不存在或型別無法辨識時用 fallback', () {
      expect(BookingAddonsHelper.parseBool(null), isFalse);
      expect(BookingAddonsHelper.parseBool(null, fallback: true), isTrue);
      expect(BookingAddonsHelper.parseBool(<String, dynamic>{}), isFalse);
    });
  });

  group('BookingAddonsHelper.selectedItemCount', () {
    test('沒有任何加值服務為 0', () {
      expect(
        BookingAddonsHelper.selectedItemCount(
          selectedTimeAddon: null,
          selectedValueServices: const <Map<String, dynamic>>[],
          selectedCustomServices: const <String, List<String>>{},
          selectedDailyTimedServices:
              const <String, Map<String, Map<String, List<String>>>>{},
        ),
        0,
      );
    });

    test('時間加購、客製服務、每日分時段各算一項', () {
      expect(
        BookingAddonsHelper.selectedItemCount(
          selectedTimeAddon: const <String, dynamic>{'label': '提早入住'},
          selectedValueServices: const <Map<String, dynamic>>[],
          selectedCustomServices: const <String, List<String>>{
            '剪指甲': <String>['pet1'],
          },
          selectedDailyTimedServices:
              <String, Map<String, Map<String, List<String>>>>{
                'feed': <String, Map<String, List<String>>>{
                  'pet1': <String, List<String>>{
                    '2026-09-02': <String>['am'],
                  },
                },
              },
        ),
        3,
      );
    });
  });

  test('enabled 為 0 時不加值時間選項不算開啟', () {
    expect(BookingAddonsHelper.parseBool(0), isFalse);
    expect(BookingAddonsHelper.parseBool(1), isTrue);
  });
}
