import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/pet_species.dart';
import 'package:petnest_saas/core/models/pet_snapshot.dart';
import 'package:petnest_saas/core/models/pet_service_module.dart';

void main() {
  test(
    'explicit species wins over legacy type; unknown does not default to cat',
    () {
      expect(PetSpecies.of({'species': 'dog', 'type': 'cat'}), 'dog');
      expect(PetSpecies.of({'gender': '母貓'}), 'cat');
      expect(PetSpecies.of({'gender': '公狗'}), 'dog');
      expect(PetSpecies.of({'type': '柴犬'}), '');
    },
  );
  test('dog hotel always accepts dogs; grooming follows configuration', () {
    expect(
      PetServiceConfig(PetServiceModule.byId('dog_hotel'), {
        'acceptedSpecies': ['cat'],
      }).acceptedSpecies,
      ['dog'],
    );
    expect(
      PetServiceConfig(PetServiceModule.byId('grooming'), {
        'acceptedSpecies': ['cat'],
      }).acceptedSpecies,
      ['cat'],
    );
  });
  test(
    'vaccine type survives order snapshot and remains separate from medical information',
    () {
      final pet = PetSnapshot.fromPet({
        'petId': 'p',
        'species': 'dog',
        'vaccineTypes': '紀錄A、紀錄B',
        'medicalStatus': '心臟病',
        'vaccine': '定期施打',
      });
      expect(pet['vaccineTypes'], '紀錄A、紀錄B');
      expect(PetSnapshot.medicalStatusText(pet), '心臟病');
      expect(PetSnapshot.safetyRows(pet).any((row) => row.key == '疫苗類型' && row.value == '紀錄A、紀錄B'), isTrue);
      expect(
        PetSnapshot.merge(
          snapshot: pet,
          fallback: {'vaccineTypes': '新資料'},
        )['vaccineTypes'],
        '紀錄A、紀錄B',
      );
    },
  );
}
