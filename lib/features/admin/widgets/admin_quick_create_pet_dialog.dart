import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/pet_profile_catalog.dart';
import 'package:petnest_saas/core/models/shop_frontend_theme.dart';
import 'package:petnest_saas/features/pet/widgets/pet_profile_form.dart';

/// Manual bookings use the same species-specific profile inputs as members.
class AdminQuickCreatePetDialog extends StatefulWidget {
  const AdminQuickCreatePetDialog({super.key});
  @override
  State<AdminQuickCreatePetDialog> createState() =>
      _AdminQuickCreatePetDialogState();
}

class _AdminQuickCreatePetDialogState extends State<AdminQuickCreatePetDialog> {
  final key = GlobalKey<FormState>();
  final name = TextEditingController(),
      breed = TextEditingController(),
      vaccine = TextEditingController(),
      medicalOther = TextEditingController(),
      litterOther = TextEditingController(),
      note = TextEditingController();
  String species = 'cat';
  String? gender, age, neuter, medical, litter;
  final Map<String, String> habits = {};
  @override
  void dispose() {
    for (final c in [name, breed, vaccine, medicalOther, litterOther, note]) {
      c.dispose();
    }
    super.dispose();
  }

  void submit() {
    final missing = PetProfileCatalog.missingRequired(
      species: species,
      name: name.text,
      gender: gender,
      age: age,
      neuter: neuter,
      medical: medical,
      litter: litter,
    );
    if (key.currentState?.validate() != true || missing.isNotEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('請完成：${missing.join('、')}')));
      return;
    }
    Navigator.pop(context, <String, dynamic>{
      'name': name.text.trim(),
      'type': species,
      'species': species,
      'gender': gender,
      'breed': breed.text.trim(),
      'age': age,
      'isNeutered': neuter == '有結紮',
      'medicalStatus': medical,
      'vaccineTypes': vaccine.text.trim(),
      'vaccine': '',
      'litterType': species == 'cat' ? litter : '',
      'careHabits': PetProfileCatalog.cleanHabits(habits, species),
      'note': note.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShopFrontendTheme.of(context).home;
    return Dialog(
      child: SizedBox(
        width: 560,
        height: MediaQuery.sizeOf(context).height * 0.84,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '快速建立寵物',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PetProfileForm(
                theme: theme,
                formKey: key,
                nameController: name,
                breedController: breed,
                otherMedicalController: medicalOther,
                otherLitterController: litterOther,
                noteController: note,
                vaccineController: vaccine,
                showPhoto: false,
                species: species,
                gender: gender,
                ageRange: age,
                neuterStatus: neuter,
                medicalStatus: medical,
                litterType: litter,
                careHabits: habits,
                onSpeciesChanged: (v) => setState(() {
                  if (v != null && v != species) {
                    species = v;
                    breed.clear();
                    vaccine.clear();
                    medicalOther.clear();
                    litterOther.clear();
                    medical = null;
                    litter = null;
                    habits.clear();
                  }
                }),
                onGenderChanged: (v) => setState(() => gender = v),
                onAgeChanged: (v) => setState(() => age = v),
                onNeuterChanged: (v) => setState(() => neuter = v),
                onMedicalChanged: (v) => setState(() => medical = v),
                onLitterChanged: (v) => setState(() => litter = v),
                onCareHabitChanged: (k, v) => setState(() => habits[k] = v),
                onPickPhoto: () {},
                onChanged: () {},
              ),
            ),
            PetFormStickyBar(
              theme: theme,
              primaryLabel: '建立寵物',
              secondaryLabel: '取消',
              onPrimary: submit,
              onSecondary: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}
