import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/features/pet/pages/add_pet_page.dart';
import 'package:petnest_saas/features/pet/widgets/pet_profile_form.dart';
import 'package:petnest_saas/features/pet/widgets/pet_catalog_field.dart';

Finder catalog(String label) =>
    find.byWidgetPredicate((w) => w is PetCatalogField && w.label == label);
Future<void> open(WidgetTester t, Finder f) async {
  await t.scrollUntilVisible(
    f,
    300,
    scrollable: find
        .descendant(
          of: find.byType(ListView).last,
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
  await t.pumpAndSettle();
}

Future<void> chooseSpecies(WidgetTester t, String label) async {
  final f = catalog('寵物種類');
  for (var i = 0; i < 10 && f.evaluate().isEmpty; i++) {
    await t.drag(find.byType(ListView).first, const Offset(0, 600));
    await t.pumpAndSettle();
  }
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
  await t.pumpAndSettle();
  await t.tap(find.text(label).last);
  await t.pumpAndSettle();
  await t.tap(find.text('確認選擇'));
  await t.pumpAndSettle();
}

Future<void> option(WidgetTester t, String value) async {
  final f = find.text(value);
  await t.scrollUntilVisible(
    f,
    160,
    scrollable: find
        .descendant(
          of: find.byType(ListView).last,
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
  await t.pumpAndSettle();
}

void main() {
  testWidgets(
    'submit catches required fields even before scrolling to health and stay sections',
    (t) async {
      await t.binding.setSurfaceSize(const Size(390, 650));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(const MaterialApp(home: AddPetPage(shopId: 'test')));
      await t.pumpAndSettle();
      await chooseSpecies(t, '貓咪');
      await t.tap(find.widgetWithText(FilledButton, '新增寵物'));
      await t.pumpAndSettle();
      expect(find.textContaining('請填寫：'), findsOneWidget);
      final snack = t.widget<Text>(find.textContaining('請填寫：')).data!;
      expect(snack, contains('醫療狀況'));
      expect(snack, contains('貓砂種類'));
      await t.pumpWidget(const SizedBox());
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'two gender choices, breed can stay blank, cat and dog choices never mix',
    (t) async {
      await t.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(const MaterialApp(home: AddPetPage(shopId: 'test')));
      await t.pumpAndSettle();
      await chooseSpecies(t, '貓咪');
      expect(find.text('請輸入寵物名字'), findsNothing);
      expect(find.text('請選擇醫療狀況'), findsNothing);
      final gender = catalog('性別');
      await open(t, gender);
      expect(find.text('公'), findsOneWidget);
      expect(find.text('母'), findsOneWidget);
      expect(find.text('公貓'), findsNothing);
      expect(find.text('母狗'), findsNothing);
      await t.tap(find.text('母').last);
      await t.pumpAndSettle();
      await t.tap(find.text('確認選擇'));
      await t.pumpAndSettle();
      expect(
        t
            .widget<PetProfileForm>(find.byType(PetProfileForm))
            .breedController
            .text,
        isEmpty,
      );
      await open(t, catalog('品種'));
      await t.enterText(find.byType(TextField).last, '英國短毛');
      await t.pumpAndSettle();
      expect(find.text('柴犬'), findsNothing);
      await t.tap(find.text('英國短毛貓'));
      await t.tap(find.text('確認選擇'));
      await t.pumpAndSettle();
      expect(
        t
            .widget<PetProfileForm>(find.byType(PetProfileForm))
            .breedController
            .text,
        '英國短毛貓',
      );
      await chooseSpecies(t, '狗狗');
      expect(
        t
            .widget<PetProfileForm>(find.byType(PetProfileForm))
            .breedController
            .text,
        isEmpty,
      );
      await open(t, catalog('品種'));
      await t.enterText(find.byType(TextField).last, '柴犬');
      await t.pumpAndSettle();
      expect(find.text('英國短毛貓'), findsNothing);
      await t.tap(find.text('柴犬').last);
      await t.tap(find.text('確認選擇'));
      await t.pumpAndSettle();
      expect(
        t
            .widget<PetProfileForm>(find.byType(PetProfileForm))
            .breedController
            .text,
        '柴犬',
      );
      await t.pumpWidget(const SizedBox());
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'vaccine supports multiple and other; contradictory status clears selections',
    (t) async {
      await t.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(const MaterialApp(home: AddPetPage(shopId: 'test')));
      await t.pumpAndSettle();
      await chooseSpecies(t, '狗狗');
      await open(t, catalog('疫苗類型'));
      await option(t, '犬八合一');
      await option(t, '狂犬病疫苗');
      await t.tap(find.text('確認選擇'));
      await t.pumpAndSettle();
      expect(
        t
            .widget<PetProfileForm>(find.byType(PetProfileForm))
            .vaccineController!
            .text,
        '犬八合一、狂犬病疫苗',
      );
      await open(t, catalog('疫苗類型'));
      await t.scrollUntilVisible(
        find.text('未接種'),
        200,
        scrollable: find
            .descendant(
              of: find.byType(ListView).last,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await t.pumpAndSettle();
      await option(t, '未接種');
      await t.tap(find.text('確認選擇'));
      await t.pumpAndSettle();
      expect(
        t
            .widget<PetProfileForm>(find.byType(PetProfileForm))
            .vaccineController!
            .text,
        '未接種',
      );
      await open(t, catalog('疫苗類型'));
      await t.scrollUntilVisible(
        find.text('其他（自行填寫）'),
        200,
        scrollable: find
            .descendant(
              of: find.byType(ListView).last,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await t.pumpAndSettle();
      await option(t, '其他（自行填寫）');
      await t.pumpAndSettle();
      final custom = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == '其他疫苗類型',
      );
      await t.scrollUntilVisible(
        custom,
        160,
        scrollable: find
            .descendant(
              of: find.byType(ListView).last,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await t.ensureVisible(custom);
      await t.pumpAndSettle();
      await t.enterText(custom, '自訂接種紀錄');
      await t.tap(find.text('確認選擇'));
      await t.pumpAndSettle();
      expect(
        t
            .widget<PetProfileForm>(find.byType(PetProfileForm))
            .vaccineController!
            .text,
        '自訂接種紀錄',
      );
      await chooseSpecies(t, '貓咪');
      expect(
        t
            .widget<PetProfileForm>(find.byType(PetProfileForm))
            .vaccineController!
            .text,
        isEmpty,
      );
      expect(
        t.widget<PetProfileForm>(find.byType(PetProfileForm)).medicalStatus,
        isNull,
      );
      await t.pumpWidget(const SizedBox());
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('dog habits saved separately and reset when switching species', (
    t,
  ) async {
    await t.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(const MaterialApp(home: AddPetPage(shopId: 'test')));
    await t.pumpAndSettle();
    await chooseSpecies(t, '狗狗');
    await open(t, catalog('散步需求'));
    await option(t, '每日 2 次');
    await t.tap(find.text('確認選擇'));
    await t.pumpAndSettle();
    expect(
      t
          .widget<PetProfileForm>(find.byType(PetProfileForm))
          .careHabits['dogWalk'],
      '每日 2 次',
    );
    await chooseSpecies(t, '貓咪');
    expect(
      t.widget<PetProfileForm>(find.byType(PetProfileForm)).careHabits,
      isEmpty,
    );
    await open(t, catalog('貓砂種類'));
    await t.tap(find.text('豆腐砂'));
    await t.tap(find.text('確認選擇'));
    await t.pumpAndSettle();
    expect(
      t.widget<PetProfileForm>(find.byType(PetProfileForm)).litterType,
      '豆腐砂',
    );
    await chooseSpecies(t, '狗狗');
    expect(
      t.widget<PetProfileForm>(find.byType(PetProfileForm)).litterType,
      isNull,
    );
    await t.pumpWidget(const SizedBox());
    expect(t.takeException(), isNull);
  });
}
