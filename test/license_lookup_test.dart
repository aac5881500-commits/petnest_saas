import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/legal_pet/license_lookup.dart';
import 'package:petnest_saas/features/shop/widgets/legal_pet_license_input.dart';

void main() {
  test('一般前綴得到同一個查核鍵，尾碼不可混同', () {
    const samples = [
      'W1070485',
      'w1070485',
      'Ｗ１０７０４８５',
      'W1070485號',
      '特寵業字第Ｗ1070485號',
    ];
    for (final sample in samples) {
      final parsed = parseLicenseLookup(sample);
      expect(parsed.ok, isTrue, reason: sample);
      expect(parsed.key, 'W1070485', reason: sample);
    }
    expect(parseLicenseLookup('V1140460-00').key, 'V1140460-00');
    expect(parseLicenseLookup('V1140460-01').key, 'V1140460-01');
    expect(
      parseLicenseLookup('V1140460-00').key,
      isNot(parseLicenseLookup('V1140460-01').key),
    );
  });

  test('不完整字號、任意文字與不明前綴不能通過', () {
    for (final sample in ['W107', '1070485', '你好', '特寵業其他字第W1070485號']) {
      final parsed = parseLicenseLookup(sample);
      expect(parsed.ok, isFalse, reason: sample);
      expect(parsed.key, isEmpty, reason: sample);
    }
    expect(parseLicenseLookup('特寵業繁字第A1100892號').key, '繁字:A1100892');
  });

  test('查核鍵相同時保留原儲存字號', () {
    expect(
      licenseValueToStore(
        persisted: '特寵業字第W1070485號',
        current: 'W1070485',
      ),
      '特寵業字第W1070485號',
    );
    expect(
      licenseValueToStore(persisted: '', current: 'w1070485'),
      'W1070485',
    );
  });

  testWidgets('輸入框顯示固定前後綴，貼上完整字號後只留核心', (tester) async {
    final controller = TextEditingController();
    var changes = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 280,
            child: LegalPetLicenseInput(
              controller: controller,
              locked: false,
              firstSetup: true,
              onChanged: () => changes += 1,
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('特寵業字第'), findsOneWidget);
    expect(find.text('號'), findsOneWidget);
    expect(find.textContaining('不需輸入前方中文'), findsOneWidget);

    controller.text = '特寵業字第Ｗ1070485號';
    await tester.pump();
    expect(controller.text, 'W1070485');
    expect(changes, 1);
    controller.selection = const TextSelection.collapsed(offset: 2);
    await tester.pump();
    expect(changes, 1);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            child: LegalPetLicenseInput(
              controller: controller,
              locked: true,
              firstSetup: false,
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
