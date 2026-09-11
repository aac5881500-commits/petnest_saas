// 檔案名稱：test/custom_form_templates_modules_test.dart
// 功能說明：三種推薦初版模組與只加入尚未有模組。

import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/custom_form_default_templates.dart';
import 'package:petnest_saas/core/models/custom_form_model.dart';

void main() {
  test('手動訂單表單推薦初版含現場交接、物品、內部備註', () {
    final CustomFormModel form = CustomFormDefaultTemplates.create(
      shopId: 's1',
      formType: CustomFormType.adminCreate,
    );
    expect(
      form.sections.map((CustomFormSection item) => item.id).toList(),
      <String>['admin_handover_check', 'admin_items', 'admin_staff_note'],
    );
  });

  test('只加入尚未有的模組，不重複塞入', () {
    CustomFormModel form = CustomFormModel.empty(
      shopId: 's1',
      formType: CustomFormType.petProfile,
    );
    form = CustomFormDefaultTemplates.mergeMissingModules(
      current: form,
      moduleIds: const <String>['pet_diet'],
    );
    expect(form.sections.length, 1);
    form = CustomFormDefaultTemplates.mergeMissingModules(
      current: form,
      moduleIds: const <String>['pet_diet', 'pet_health_care'],
    );
    expect(form.sections.map((CustomFormSection item) => item.id).toList(), <String>[
      'pet_diet',
      'pet_health_care',
    ]);
  });

  test('題型有簡短說明', () {
    expect(CustomFormQuestionType.singleChoice.labelWithHint, contains('只能選一個'));
    expect(CustomFormQuestionType.multipleChoice.labelWithHint, contains('可選多個'));
  });
}
