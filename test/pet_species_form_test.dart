import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/features/pet/widgets/pet_profile_form.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader('NotoSansTC')..addFont(
          rootBundle.load('assets/fonts/NotoSansTC-VariableFont_wght.ttf'),
        ))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  for (final species in ['cat', 'dog']) {
    testWidgets(
      '$species form validates and shows species-specific care fields',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(440, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final controllers = List.generate(6, (_) => TextEditingController());
        addTearDown(() {
          for (final c in controllers) {
            c.dispose();
          }
        });
        controllers[0].text = species == 'cat' ? '麻糬' : '雪球';
        controllers[5].text = '依接種手冊紀錄';
        final key = GlobalKey<FormState>();
        final capture = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: capture,
            child: MaterialApp(
              theme: ThemeData(fontFamily: 'NotoSansTC'),
              home: Scaffold(
                backgroundColor: HomeThemeModel.modernDefault.backgroundColor,
                appBar: AppBar(title: const Text('新增寵物')),
                body: PetProfileForm(
                  theme: HomeThemeModel.modernDefault,
                  formKey: key,
                  nameController: controllers[0],
                  breedController: controllers[1],
                  otherMedicalController: controllers[2],
                  otherLitterController: controllers[3],
                  noteController: controllers[4],
                  vaccineController: controllers[5],
                  species: species,
                  onSpeciesChanged: (_) {},
                  gender: species == 'cat' ? '母貓' : '公狗',
                  ageRange: '1~10歲',
                  neuterStatus: '有結紮',
                  medicalStatus: '無',
                  litterType: species == 'cat' ? '豆腐砂' : null,
                  onGenderChanged: (_) {},
                  onAgeChanged: (_) {},
                  onNeuterChanged: (_) {},
                  onMedicalChanged: (_) {},
                  onLitterChanged: (_) {},
                  onPickPhoto: () {},
                  onChanged: () {},
                ),
                bottomNavigationBar: PetFormStickyBar(
                  theme: HomeThemeModel.modernDefault,
                  primaryLabel: '新增寵物',
                  onPrimary: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('疫苗類型（可複選）'), findsOneWidget);
        if (species == 'cat') {
          await tester.scrollUntilVisible(
            find.text('貓砂種類'),
            300,
            scrollable: find
                .descendant(
                  of: find.byType(ListView).first,
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          expect(find.text('貓砂種類'), findsOneWidget);
        } else {
          expect(find.text('貓砂種類'), findsNothing);
        }
        expect(key.currentState!.validate(), isTrue);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        // Optional review images, never golden baselines or test comparisons.
        if (Platform.environment['PET_REVIEW_IMAGES'] != null) {
          await tester.runAsync(() async {
            final boundary =
                capture.currentContext!.findRenderObject()
                    as RenderRepaintBoundary;
            final image = await boundary.toImage(pixelRatio: 1);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              '${Platform.environment['PET_REVIEW_IMAGES']}/pet_profile_$species.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
      },
    );
  }
}
