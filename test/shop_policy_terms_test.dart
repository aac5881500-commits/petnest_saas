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
