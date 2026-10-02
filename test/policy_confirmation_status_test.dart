import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/policy_confirmation_status.dart';
import 'package:petnest_saas/core/services/platform_policy_service.dart';
import 'package:petnest_saas/core/services/shop_policy_service.dart';

void main() {
  test('平台條款 v1 同意後為已確認最新版', () {
    expect(
      resolvePolicyConfirmation(publishedVersion: 1, acceptedVersion: 1),
      PolicyConfirmationState.current,
    );
    expect(policyConfirmationLabel(PolicyConfirmationState.current), '已確認最新版');
    expect(policyVersionLabel(1), 'v1');
  });

  test('平台條款升到 v2 後，已同意 v1 的帳號為待確認更新', () {
    expect(
      resolvePolicyConfirmation(publishedVersion: 2, acceptedVersion: 1),
      PolicyConfirmationState.needsUpdate,
    );
    expect(
      resolvePolicyConfirmation(publishedVersion: 2, acceptedVersion: 2),
      PolicyConfirmationState.current,
    );
  });

  test('沒有同意紀錄是尚未確認，沒有已發布版本不要求確認', () {
    expect(
      resolvePolicyConfirmation(publishedVersion: 1, acceptedVersion: 0),
      PolicyConfirmationState.notAccepted,
    );
    expect(
      resolvePolicyConfirmation(publishedVersion: 0, acceptedVersion: null),
      PolicyConfirmationState.noPublished,
    );
    expect(policyVersionLabel(0), '尚未確認');
  });

  test('平台同意紀錄與店家同意紀錄路徑分開', () {
    expect(
      PlatformPolicyService.acceptancePath('uid-a'),
      'users/uid-a/platform_policy_acceptances/platform_user_policy',
    );
    expect(
      ShopPolicyService.acceptanceRecordPath(
        userId: 'uid-a',
        shopId: 'SHOP0001',
      ),
      'users/uid-a/policy_acceptances/SHOP0001',
    );
  });

  test('發布平台條款只前進版本號，不重用舊版本文件', () {
    expect(nextPlatformPolicyVersion(1), 2);
    expect(platformPolicyVersionDocId(1), 'v1');
    expect(platformPolicyVersionDocId(2), 'v2');
    expect(
      platformPolicyVersionDocId(1) == platformPolicyVersionDocId(2),
      isFalse,
    );
  });
}
