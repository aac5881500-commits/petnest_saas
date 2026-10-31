import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:petnest_saas/core/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:petnest_saas/features/platform/pages/inspection_owner_bootstrap.dart';
import 'package:petnest_saas/core/services/inspection_owner_context.dart';
import 'package:petnest_saas/core/services/shop_plan_service.dart';
import 'package:petnest_saas/features/shop/widgets/chat/shop_chat_composer.dart';

const options = FirebaseOptions(
  apiKey: 'test',
  appId: 'test',
  messagingSenderId: 'test',
  projectId: 'demo-inspection',
);

class CoreFixture extends FirebasePlatform {
  CoreFixture(List<String> names)
    : values = {
        for (final name in names) name: FirebaseAppPlatform(name, options),
      };
  final Map<String, FirebaseAppPlatform> values;
  @override
  List<FirebaseAppPlatform> get apps => values.values.toList();
  @override
  FirebaseAppPlatform app([String name = defaultFirebaseAppName]) =>
      values[name]!;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();
  setUpAll(() async => Firebase.initializeApp());
  tearDown(InspectionOwnerContext.clear);
  test('default lookup aliases only the separate named preview app', () async {
    final source = CoreFixture(['readonly_nonce', 'another']);
    final alias = InspectionFirebaseAlias(source, 'readonly_nonce');
    expect(alias.app().name, 'readonly_nonce');
    expect(alias.app('another').name, 'another');
    expect((await alias.initializeApp()).name, 'readonly_nonce');
    expect(source.apps.map((app) => app.name), ['readonly_nonce', 'another']);
  });
  test(
    'cannot activate alias in a runtime containing normal default login',
    () {
      final source = CoreFixture([defaultFirebaseAppName, 'readonly_nonce']);
      expect(
        () => InspectionFirebaseAlias(source, 'readonly_nonce'),
        throwsStateError,
      );
      expect(source.app().name, defaultFirebaseAppName);
    },
  );
  test('display permission is constrained to the selected shop and clears', () {
    InspectionOwnerContext.active = true;
    InspectionOwnerContext.shopId = 's1';
    InspectionOwnerContext.ownerUid = 'owner';
    expect(InspectionOwnerContext.readUid('anonymous'), 'owner');
    expect(InspectionOwnerContext.forShop('s1'), isTrue);
    expect(InspectionOwnerContext.forShop('s2'), isFalse);
    expect(ShopPlanService.canUsePublicPage({'plan': 'free'}), isTrue);
    InspectionOwnerContext.clear();
    expect(ShopPlanService.canUsePublicPage({'plan': 'free'}), isFalse);
    expect(InspectionOwnerContext.ownerUid, isEmpty);
    expect(InspectionOwnerContext.readUid('anonymous'), 'anonymous');
  });
  testWidgets(
    'original chat composer disables text, upload and send in inspection',
    (tester) async {
      InspectionOwnerContext.active = true;
      final controller = TextEditingController(text: '不可傳送');
      addTearDown(controller.dispose);
      int sent = 0, uploaded = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShopChatComposer(
              controller: controller,
              enabled: true,
              sending: false,
              onSendText: () => sent++,
              onPickImage: () => uploaded++,
            ),
          ),
        ),
      );
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      for (final button in tester.widgetList<IconButton>(
        find.byType(IconButton),
      )) {
        expect(button.onPressed, isNull);
      }
      expect(sent, 0);
      expect(uploaded, 0);
    },
  );
  test(
    'readonly auth cannot sign in, register, or send account emails',
    () async {
      InspectionOwnerContext.active = true;
      final auth = AuthService.instance;
      final denied = isA<FirebaseAuthException>().having(
        (e) => e.code,
        'code',
        'inspection-read-only',
      );
      await expectLater(
        auth.login(email: 'test@example.com', password: 'unused'),
        throwsA(denied),
      );
      await expectLater(
        auth.register(
          email: 'test@example.com',
          password: 'unused',
          displayName: 'name',
        ),
        throwsA(denied),
      );
      await expectLater(auth.signInWithGoogle(), throwsA(denied));
      await expectLater(auth.signInWithApple(), throwsA(denied));
      await expectLater(auth.sendEmailVerification(), throwsA(denied));
      await expectLater(
        auth.sendPasswordResetEmail('test@example.com'),
        throwsA(denied),
      );
      bool closed = false;
      InspectionOwnerContext.onExit = () => closed = true;
      await auth.logout();
      expect(closed, isTrue);
    },
  );
}
