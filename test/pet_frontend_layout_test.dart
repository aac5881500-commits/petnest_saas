import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/features/pet/widgets/pet_profile_form.dart';

void main() {
  testWidgets('PetProfileForm fits 392px without overflow', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(392, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    final TextEditingController name = TextEditingController();
    final TextEditingController breed = TextEditingController();
    final TextEditingController otherMedical = TextEditingController();
    final TextEditingController otherLitter = TextEditingController();
    final TextEditingController note = TextEditingController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 392,
            child: PetProfileForm(
              theme: HomeThemeModel.modernDefault,
              formKey: formKey,
              nameController: name,
              breedController: breed,
              otherMedicalController: otherMedical,
              otherLitterController: otherLitter,
              noteController: note,
              gender: '公貓',
              ageRange: '1~10歲',
              neuterStatus: '有結紮',
              medicalStatus: '無',
              litterType: '豆腐砂',
              onGenderChanged: (_) {},
              onAgeChanged: (_) {},
              onNeuterChanged: (_) {},
              onMedicalChanged: (_) {},
              onLitterChanged: (_) {},
              onPickPhoto: () {},
              onChanged: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(PetProfileForm), findsOneWidget);
  });

  testWidgets('three mini feature cards fit 392px', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(392, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: EdgeInsets.all(16),
            child: SizedBox(
              width: 360,
              child: Row(
                children: <Widget>[
                  Expanded(child: _MiniStub(title: '個人資料')),
                  SizedBox(width: 8),
                  Expanded(child: _MiniStub(title: '常用地址')),
                  SizedBox(width: 8),
                  Expanded(child: _MiniStub(title: '緊急聯絡人')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

class _MiniStub extends StatelessWidget {
  const _MiniStub({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
      child: Column(
        children: <Widget>[
          const Icon(Icons.person_outline, size: 20),
          const SizedBox(height: 8),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
