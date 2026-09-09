import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/policy_applicable_service.dart';
import 'package:petnest_saas/core/models/special_date_surcharge_model.dart';
import 'package:petnest_saas/core/services/special_date_surcharge_calculator.dart';

void main() {
  final DateTime now = DateTime(2026, 9, 8);
  SpecialDateSurchargeModel item({
    required List<String> services,
    List<String> rooms = const <String>[],
  }) {
    return SpecialDateSurchargeModel(
      id: 's1',
      shopId: 'shop',
      name: '連假',
      startDate: now,
      endDate: now,
      amountPerNight: 200,
      enabled: true,
      createdAt: now,
      updatedAt: now,
      applicableServices: services,
      roomTypeIds: rooms,
    );
  }

  test('舊資料僅住宿，不安親', () {
    final SpecialDateSurchargeCalculationResult stay =
        SpecialDateSurchargeCalculator.calculate(
          checkInDate: now,
          checkOutDate: now.add(const Duration(days: 1)),
          roomTypeId: 'deluxe',
          surcharges: <SpecialDateSurchargeModel>[
            item(services: PolicyApplicableService.accommodationOnly),
          ],
        );
    final SpecialDateSurchargeCalculationResult daycare =
        SpecialDateSurchargeCalculator.calculateDaycare(
          serviceDate: now,
          isRoomBased: true,
          roomTypeId: 'deluxe',
          surcharges: <SpecialDateSurchargeModel>[
            item(services: PolicyApplicableService.accommodationOnly),
          ],
        );
    expect(stay.totalAmount, 200);
    expect(daycare.totalAmount, 0);
  });

  test('安親每次只加一次', () {
    final SpecialDateSurchargeCalculationResult daycare =
        SpecialDateSurchargeCalculator.calculateDaycare(
          serviceDate: now,
          isRoomBased: false,
          surcharges: <SpecialDateSurchargeModel>[
            item(services: PolicyApplicableService.shared),
          ],
        );
    expect(daycare.totalAmount, 200);
    expect(daycare.totalStayNights, 1);
  });
}
