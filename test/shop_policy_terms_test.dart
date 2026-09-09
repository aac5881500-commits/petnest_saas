// 檔案名稱：test/shop_policy_terms_test.dart
// 功能說明：店家條款的單元測試

import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/policy_applicable_service.dart';
import 'package:petnest_saas/core/services/shop_policy_service.dart';

void main() {
  test('no policy content means submit allowed', () {
    const TermsStatus status = TermsStatus(
      required: false,
      accepted: true,
      versionUpdated: false,
      version: 0,
      title: '入住須知',
    );
    expect(status.canSubmit, isTrue);
  });

  test('accommodation and daycare terms are separate types', () {
    const TermsStatus stayPending = TermsStatus(
      required: true,
      accepted: false,
      versionUpdated: false,
      version: 2,
      title: '入住須知',
    );
    const TermsStatus daycareAccepted = TermsStatus(
      required: true,
      accepted: true,
      versionUpdated: false,
      version: 2,
      title: '安親須知',
    );
    expect(stayPending.canSubmit, isFalse);
    expect(daycareAccepted.canSubmit, isTrue);
    expect(
      PolicyApplicableService.accommodation,
      isNot(PolicyApplicableService.daycare),
    );
  });

  test('accommodation version change does not move daycare version', () {
    const Map<String, dynamic> policy = <String, dynamic>{
      'version': 5,
      'accommodationVersion': 5,
      'daycareVersion': 1,
      'serviceVersions': <String, int>{'accommodation': 5, 'daycare': 1},
    };
    expect(
      ShopPolicyService.servicePolicyVersion(
        policy: policy,
        serviceType: PolicyApplicableService.accommodation,
      ),
      5,
    );
    expect(
      ShopPolicyService.servicePolicyVersion(
        policy: policy,
        serviceType: PolicyApplicableService.daycare,
      ),
      1,
    );
  });

  test('legacy daycare without daycareVersion uses global version', () {
    const Map<String, dynamic> policy = <String, dynamic>{'version': 1};
    expect(
      ShopPolicyService.servicePolicyVersion(
        policy: policy,
        serviceType: PolicyApplicableService.daycare,
      ),
      1,
    );
  });

  test('refund policy version is independent of stay and daycare versions', () {
    const Map<String, dynamic> policy = <String, dynamic>{
      'version': 2,
      'accommodationVersion': 2,
      'daycareVersion': 1,
    };
    expect(
      ShopPolicyService.servicePolicyVersion(
        policy: policy,
        serviceType: PolicyApplicableService.daycare,
      ),
      1,
    );
  });

  test('daycare terms updated error is recognized', () {
    expect(
      ShopPolicyService.isTermsUpdatedError(Exception('安親條款已更新，請重新閱讀並同意。')),
      isTrue,
    );
  });

  test('version update requires re-confirm', () {
    const TermsStatus status = TermsStatus(
      required: true,
      accepted: false,
      versionUpdated: true,
      version: 3,
      title: '入住須知',
    );
    expect(status.canSubmit, isFalse);
  });
}
