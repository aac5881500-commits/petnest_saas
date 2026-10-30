import 'package:petnest_saas/core/models/custom_form_model.dart';
import 'package:petnest_saas/core/models/custom_form_pet_condition.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/pet_profile_catalog.dart';
import 'package:petnest_saas/core/models/pet_species.dart';
import 'package:petnest_saas/core/models/pet_snapshot.dart';

void main() {
  test('each selected disease still triggers its own follow-up questions', () {
    const q = CustomFormQuestion(
      id: 'q',
      label: '心臟用藥',
      answerScope: CustomFormAnswerScope.pet,
      displayCondition: CustomFormDisplayCondition(
        field: 'medicalStatus',
        value: '心臟病',
      ),
    );
    expect(
      CustomFormPetCondition.questionVisibleForPet(
        question: q,
        pet: {'medicalStatus': '慢性腎臟病、心臟病'},
      ),
      isTrue,
    );
    expect(
      CustomFormPetCondition.questionVisibleForPet(
        question: q,
        pet: {'medicalStatus': '無'},
      ),
      isFalse,
    );
  });
  test('breed, vaccine, disease and care options respect species', () {
    expect(PetProfileCatalog.breeds('cat'), contains('英國短毛貓'));
    expect(PetProfileCatalog.breeds('cat'), isNot(contains('柴犬')));
    expect(PetProfileCatalog.breeds('dog'), contains('柴犬'));
    expect(PetProfileCatalog.breeds(null), isEmpty);
    expect(PetProfileCatalog.vaccines('cat'), contains('貓三合一'));
    expect(PetProfileCatalog.vaccines('cat'), isNot(contains('犬八合一')));
    expect(PetProfileCatalog.medical('cat'), contains('貓白血病（FeLV）'));
    expect(PetProfileCatalog.medical('dog'), isNot(contains('貓白血病（FeLV）')));
    expect(
      PetProfileCatalog.habits('cat').map((f) => f.key),
      isNot(contains('dogWalk')),
    );
    expect(
      PetProfileCatalog.habits('dog').map((f) => f.key),
      isNot(contains('catToilet')),
    );
  });
  test('historical gender is normalized without losing species inference', () {
    expect(PetSpecies.genderLabel('公狗'), '公');
    expect(PetSpecies.genderLabel('母貓'), '母');
    final pet = PetSnapshot.fromPet({'gender': '公狗'});
    expect(pet['gender'], '公');
    expect(pet['species'], 'dog');
  });
  test(
    'stay habits survive order snapshots, species changes discard inapplicable keys',
    () {
      final pet = PetSnapshot.fromPet({
        'species': 'dog',
        'careHabits': {
          'dogWalk': '每日 2 次',
          'catToilet': '不該保留',
          'feedingMethod': '鮮食',
        },
      });
      expect(pet['careHabits'], {'dogWalk': '每日 2 次', 'feedingMethod': '鮮食'});
      expect(PetSnapshot.careRows(pet).map((r) => r.value), contains('每日 2 次'));
      expect(
        PetSnapshot.merge(
          snapshot: pet,
          fallback: {
            'species': 'dog',
            'careHabits': {'dogWalk': '每日 1 次'},
          },
        )['careHabits'],
        pet['careHabits'],
      );
    },
  );
  test(
    'required validation does not depend on lazy form fields being mounted',
    () {
      expect(
        PetProfileCatalog.missingRequired(
          species: 'cat',
          name: '麻糬',
          gender: '公',
          age: '1~10歲',
          neuter: '有結紮',
          medical: null,
          litter: null,
        ),
        ['醫療狀況', '貓砂種類'],
      );
      expect(
        PetProfileCatalog.missingRequired(
          species: 'dog',
          name: '雪球',
          gender: '母',
          age: '1~10歲',
          neuter: '有結紮',
          medical: '無',
          litter: null,
        ),
        isEmpty,
      );
    },
  );
}
