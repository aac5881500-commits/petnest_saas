import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/services/member_identity.dart';
import 'package:petnest_saas/features/member/pages/member_page.dart';
import 'package:petnest_saas/features/member/widgets/member_sign_in_prompt.dart';
import 'package:petnest_saas/features/platform/widgets/platform_policy_gate.dart';

class TestUser extends Fake implements User {
  TestUser(this.uid, this.isAnonymous);
  @override
  final String uid;
  @override
  final bool isAnonymous;
}

void main() {
  test('anonymous identities are visitors rather than registered members', () {
    expect(isRegisteredMember(null), false);
    expect(isRegisteredMember(TestUser('guest', true)), false);
    expect(isRegisteredMember(TestUser('member', false)), true);
  });
  testWidgets('guest member center shows login without loading member data', (
    tester,
  ) async {
    for (final user in <User?>[null, TestUser('guest', true)]) {
      await tester.pumpWidget(
        MaterialApp(
          home: MemberPage(
            key: UniqueKey(),
            shopId: 'SHOP0018',
            authChanges: const Stream<User?>.empty(),
            initialUser: user,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('登入／註冊'), findsOneWidget);
      expect(find.text('尚未填寫姓名'), findsNothing);
      expect(find.text('申請刪除帳號'), findsNothing);
      expect(find.text('新增寵物'), findsNothing);
    }
  });
  testWidgets('visitor does not read or write member policy acceptance', (
    tester,
  ) async {
    var reads = 0, writes = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: PlatformPolicyGate(
          authChanges: const Stream<User?>.empty(),
          initialUser: TestUser('guest', true),
          checkAcceptance: (_) async {
            reads++;
            return false;
          },
          acceptPolicy: () async {
            writes++;
          },
          child: const Text('店家瀏覽'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('店家瀏覽'), findsOneWidget);
    expect(reads, 0);
    expect(writes, 0);
  });
  testWidgets('formal login starts consent and logout removes it', (
    tester,
  ) async {
    final users = StreamController<User?>();
    addTearDown(users.close);
    var reads = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: PlatformPolicyGate(
          authChanges: users.stream,
          initialUser: TestUser('guest', true),
          checkAcceptance: (_) async {
            reads++;
            return false;
          },
          consentBuilder: (_) => const Text('會員條款確認'),
          child: const Text('店家瀏覽'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(reads, 0);
    users.add(TestUser('member', false));
    await tester.pumpAndSettle();
    expect(reads, 1);
    expect(find.text('會員條款確認'), findsOneWidget);
    users.add(null);
    await tester.pumpAndSettle();
    expect(find.text('店家瀏覽'), findsOneWidget);
    expect(find.text('會員條款確認'), findsNothing);
  });
  testWidgets('late member check cannot force terms onto a guest', (
    tester,
  ) async {
    final users = StreamController<User?>();
    addTearDown(users.close);
    final result = Completer<bool>();
    await tester.pumpWidget(
      MaterialApp(
        home: PlatformPolicyGate(
          authChanges: users.stream,
          initialUser: TestUser('member', false),
          checkAcceptance: (_) => result.future,
          consentBuilder: (_) => const Text('會員條款確認'),
          child: const Text('店家瀏覽'),
        ),
      ),
    );
    await tester.pump();
    users.add(TestUser('guest', true));
    await tester.pumpAndSettle();
    result.complete(false);
    await tester.pumpAndSettle();
    expect(find.text('店家瀏覽'), findsOneWidget);
    expect(find.text('會員條款確認'), findsNothing);
  });
  testWidgets('login action is explicit and does not happen during browsing', (
    tester,
  ) async {
    var logins = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MemberSignInPrompt(shopId: 'SHOP0018', onLogin: () => logins++),
      ),
    );
    await tester.pumpAndSettle();
    expect(logins, 0);
    await tester.tap(find.text('登入／註冊'));
    await tester.pumpAndSettle();
    expect(logins, 1);
  });
}
