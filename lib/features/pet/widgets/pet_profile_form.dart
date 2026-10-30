import 'package:petnest_saas/core/models/pet_profile_catalog.dart';
import 'package:petnest_saas/core/models/pet_species.dart';
import 'package:petnest_saas/features/pet/widgets/pet_catalog_field.dart';
// 檔案名稱：lib/features/pet/widgets/pet_profile_form.dart
// 功能說明：新增／編輯寵物共用表單視覺與欄位。

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';

InputDecoration petProfileInputDecoration({
  required HomeThemeModel theme,
  required String label,
  String? hint,
}) {
  final Color fill = Color.alphaBlend(
    theme.primaryColor.withValues(alpha: 0.025),
    theme.cardColor,
  );
  return InputDecoration(
    labelText: label,
    floatingLabelBehavior: FloatingLabelBehavior.always,
    alignLabelWithHint: true,
    hintText: hint,
    filled: true,
    fillColor: fill,
    labelStyle: TextStyle(
      fontSize: 13,
      color: theme.textColor.withValues(alpha: 0.7),
    ),
    hintStyle: TextStyle(
      fontSize: 13,
      color: theme.textColor.withValues(alpha: 0.4),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: theme.cardBorderColor),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: theme.cardBorderColor),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: theme.primaryColor, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: Colors.red.shade300),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
    ),
  );
}

class PetFormSectionCard extends StatelessWidget {
  const PetFormSectionCard({
    super.key,
    required this.theme,
    required this.icon,
    required this.title,
    required this.children,
  });

  final HomeThemeModel theme;
  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.cardBorderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: theme.primaryColor.withValues(alpha: 0.08),
            child: Row(
              children: <Widget>[
                Icon(icon, size: 18, color: theme.primaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: theme.textColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

class PetPhotoPicker extends StatelessWidget {
  const PetPhotoPicker({
    super.key,
    required this.theme,
    required this.onTap,
    this.imageBytes,
    this.networkUrl,
    this.emptyLabel = '新增照片',
  });

  final HomeThemeModel theme;
  final VoidCallback onTap;
  final Uint8List? imageBytes;
  final String? networkUrl;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final bool hasPhoto =
        imageBytes != null ||
        (networkUrl != null && networkUrl!.trim().isNotEmpty);

    return Center(
      child: SizedBox(
        width: 118,
        height: 118,
        child: GestureDetector(
          onTap: onTap,
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.primaryColor.withValues(alpha: 0.1),
                  border: Border.all(color: theme.cardBorderColor, width: 1.5),
                ),
                clipBehavior: Clip.antiAlias,
                child: hasPhoto
                    ? (imageBytes != null
                          ? Image.memory(imageBytes!, fit: BoxFit.cover)
                          : Image.network(
                              networkUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  _empty(theme, emptyLabel),
                            ))
                    : _empty(theme, emptyLabel),
              ),
              Positioned(
                right: 0,
                bottom: 4,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: theme.primaryColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: theme.cardColor, width: 2),
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _empty(HomeThemeModel theme, String emptyLabel) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Icon(
          Icons.pets,
          size: 32,
          color: theme.primaryColor.withValues(alpha: 0.75),
        ),
        const SizedBox(height: 4),
        Text(
          emptyLabel,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: theme.primaryColor,
          ),
        ),
      ],
    );
  }
}

class PetFormStickyBar extends StatelessWidget {
  const PetFormStickyBar({
    super.key,
    required this.theme,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.loading = false,
    this.primaryEnabled = true,
  });

  final HomeThemeModel theme;
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final bool loading;
  final bool primaryEnabled;

  @override
  Widget build(BuildContext context) {
    final bool canSubmit = primaryEnabled && !loading && onPrimary != null;
    return Material(
      color: theme.cardColor,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: <Widget>[
              if (secondaryLabel != null) ...<Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: loading ? null : onSecondary,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(46),
                      foregroundColor: theme.textColor,
                      side: BorderSide(color: theme.cardBorderColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      secondaryLabel!,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                flex: secondaryLabel == null ? 1 : 1,
                child: FilledButton(
                  onPressed: canSubmit ? onPrimary : null,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                    backgroundColor: theme.primaryColor,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: theme.cardBorderColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          primaryLabel,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PetProfileForm extends StatelessWidget {
  const PetProfileForm({
    super.key,
    required this.theme,
    required this.formKey,
    required this.nameController,
    required this.breedController,
    required this.otherMedicalController,
    required this.otherLitterController,
    required this.noteController,
    required this.gender,
    required this.ageRange,
    required this.neuterStatus,
    required this.medicalStatus,
    required this.litterType,
    required this.onGenderChanged,
    required this.onAgeChanged,
    required this.onNeuterChanged,
    required this.onMedicalChanged,
    required this.onLitterChanged,
    required this.onPickPhoto,
    required this.onChanged,
    this.careHabits = const {},
    this.onCareHabitChanged,
    this.showPhoto = true,
    this.species,
    this.onSpeciesChanged,
    this.vaccineController,
    this.imageBytes,
    this.networkPhotoUrl,
    this.nameEnabled = true,
    this.healthEnabled = true,
    this.adminNoteController,
    this.bottomPadding = 16,
    this.extraChildren = const <Widget>[],
    this.scrollController,
  });

  final Map<String, String> careHabits;
  final void Function(String key, String value)? onCareHabitChanged;
  final bool showPhoto;
  final String? species;
  final ValueChanged<String?>? onSpeciesChanged;
  final TextEditingController? vaccineController;
  final HomeThemeModel theme;
  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController breedController;
  final TextEditingController otherMedicalController;
  final TextEditingController otherLitterController;
  final TextEditingController noteController;
  final String? gender;
  final String? ageRange;
  final String? neuterStatus;
  final String? medicalStatus;
  final String? litterType;
  final ValueChanged<String?> onGenderChanged;
  final ValueChanged<String?> onAgeChanged;
  final ValueChanged<String?> onNeuterChanged;
  final ValueChanged<String?> onMedicalChanged;
  final ValueChanged<String?> onLitterChanged;
  final VoidCallback onPickPhoto;
  final VoidCallback onChanged;
  final Uint8List? imageBytes;
  final String? networkPhotoUrl;
  final bool nameEnabled;
  final bool healthEnabled;
  final TextEditingController? adminNoteController;
  final double bottomPadding;
  final List<Widget> extraChildren;
  final ScrollController? scrollController;

  static const List<String> genders = ['公', '母'];
  static const List<String> ages = <String>[
    '6~12個月',
    '1~10歲',
    '10~12歲',
    '12歲以上',
  ];
  static const List<String> neuterOptions = <String>['有結紮', '未結紮'];
  static const List<String> medicalOptions = <String>[
    '無',
    '慢性腎臟病',
    '心臟病',
    '糖尿病',
    '術後照護',
    '皮膚疾病',
    '其他',
  ];
  static const List<String> litterOptions = <String>['豆腐砂', '礦砂', '其他'];

  @override
  Widget build(BuildContext context) {
    final TextStyle fieldStyle = TextStyle(
      fontSize: 14,
      color: theme.textColor,
    );

    return Form(
      key: formKey,
      autovalidateMode: AutovalidateMode.disabled,
      onChanged: onChanged,
      child: ListView(
        controller: scrollController,
        padding: EdgeInsets.fromLTRB(20, 20, 20, bottomPadding),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: <Widget>[
          PetFormSectionCard(
            theme: theme,
            icon: Icons.pets_outlined,
            title: '基本資料',
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: theme.primaryColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '請務必選對寵物種類。貓咪只能訂貓房，狗狗只能訂狗房；選錯種類將無法預訂對應房間。美容依店家接待種類開放。',
                        style: TextStyle(
                          color: theme.textColor.withValues(alpha: 0.9),
                          fontSize: 13,
                          height: 1.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              PetCatalogField(
                theme: theme,
                label: '寵物種類',
                value: species ?? '',
                options: const ['cat', 'dog'],
                optionLabels: const {'cat': '貓咪', 'dog': '狗狗'},
                allowCustom: false,
                searchable: false,
                requiredValue: true,
                enabled: nameEnabled,
                decoration: petProfileInputDecoration(
                  theme: theme,
                  label: '寵物種類 *',
                ),
                hint: '請選擇貓咪或狗狗',
                onChanged: onSpeciesChanged ?? (_) {},
              ),
              const SizedBox(height: 20),
              if (showPhoto)
                PetPhotoPicker(
                  theme: theme,
                  onTap: onPickPhoto,
                  imageBytes: imageBytes,
                  networkUrl: networkPhotoUrl,
                ),
              const SizedBox(height: 14),
              TextFormField(
                autovalidateMode: AutovalidateMode.onUserInteraction,
                controller: nameController,
                enabled: nameEnabled,
                style: fieldStyle,
                decoration: petProfileInputDecoration(
                  theme: theme,
                  label: '寵物名字',
                ),
                validator: (String? value) {
                  if (value == null || value.trim().isEmpty) {
                    return '請輸入寵物名字';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              PetCatalogField(
                theme: theme,
                label: '性別',
                value: PetSpecies.genderLabel(gender),
                options: genders,
                allowCustom: false,
                searchable: false,
                requiredValue: true,
                enabled: nameEnabled,
                decoration: petProfileInputDecoration(
                  theme: theme,
                  label: '性別',
                ),
                hint: '請選擇性別',
                onChanged: onGenderChanged,
              ),
              const SizedBox(height: 12),
              ListenableBuilder(
                listenable: breedController,
                builder: (context, _) => PetCatalogField(
                  theme: theme,
                  label: '品種',
                  value: breedController.text,
                  options: PetProfileCatalog.breeds(species),
                  enabled: nameEnabled && species != null,
                  decoration: petProfileInputDecoration(
                    theme: theme,
                    label: '品種（選填）',
                  ),
                  hint: species == null ? '請先選擇寵物種類' : '可留白，或搜尋／選擇其他',
                  onChanged: (v) {
                    breedController.text = v;
                    onChanged();
                  },
                ),
              ),
              const SizedBox(height: 12),
              PetCatalogField(
                theme: theme,
                label: '年齡',
                value: ageRange ?? '',
                options: ages,
                allowCustom: false,
                searchable: false,
                requiredValue: true,
                enabled: nameEnabled,
                decoration: petProfileInputDecoration(
                  theme: theme,
                  label: '年齡',
                ),
                hint: '請選擇年齡',
                onChanged: onAgeChanged,
              ),
            ],
          ),
          PetFormSectionCard(
            theme: theme,
            icon: Icons.health_and_safety_outlined,
            title: '健康資訊',
            children: <Widget>[
              if (vaccineController != null) ...[
                ListenableBuilder(
                  listenable: vaccineController!,
                  builder: (context, _) => PetCatalogField(
                    theme: theme,
                    label: '疫苗類型',
                    value: vaccineController!.text,
                    options: PetProfileCatalog.vaccines(species),
                    multiple: true,
                    exclusiveValues: const {'未接種', '不確定'},
                    enabled: healthEnabled && species != null,
                    decoration: petProfileInputDecoration(
                      theme: theme,
                      label: '疫苗類型（可複選）',
                    ),
                    hint: species == null ? '請先選擇寵物種類' : '依接種手冊選擇，可填其他',
                    onChanged: (v) {
                      vaccineController!.text = v;
                      onChanged();
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '請依接種手冊與獸醫診斷填寫；未列出的疫苗或病症可選「其他」。',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.textColor.withValues(alpha: 0.65),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (species == 'cat' &&
                  PetSpecies.genderLabel(gender) == '公' &&
                  neuterStatus == '未結紮') ...<Widget>[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F0),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFF5C6C2)),
                  ),
                  child: Text(
                    '未結紮公貓如有噴尿習慣，請提前告知店家照護需求。',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: Colors.red.shade800,
                    ),
                  ),
                ),
              ],
              PetCatalogField(
                theme: theme,
                label: '結紮狀況',
                value: neuterStatus ?? '',
                options: neuterOptions,
                allowCustom: false,
                searchable: false,
                requiredValue: true,
                enabled: healthEnabled,
                decoration: petProfileInputDecoration(
                  theme: theme,
                  label: '結紮狀況',
                ),
                hint: '請選擇結紮狀況',
                onChanged: onNeuterChanged,
              ),
              const SizedBox(height: 12),
              PetCatalogField(
                theme: theme,
                label: '醫療狀況',
                value: medicalStatus == '其他'
                    ? otherMedicalController.text
                    : (medicalStatus ?? ''),
                options: PetProfileCatalog.medical(species),
                multiple: true,
                requiredValue: true,
                exclusiveValues: const {'無', '不確定'},
                enabled: healthEnabled && species != null,
                decoration: petProfileInputDecoration(
                  theme: theme,
                  label: '醫療狀況（可複選）',
                ),
                hint: species == null ? '請先選擇寵物種類' : '無疾病請選「無」，其他可自行填寫',
                onChanged: (v) {
                  otherMedicalController.clear();
                  onMedicalChanged(v);
                },
              ),
            ],
          ),
          PetFormSectionCard(
            theme: theme,
            icon: Icons.home_outlined,
            title: '住宿習慣',
            children: <Widget>[
              if (species == null) const Text('請先選擇寵物種類，再填寫對應的住宿習慣。'),
              if (species == 'cat') ...[
                PetCatalogField(
                  theme: theme,
                  label: '貓砂種類',
                  value: litterType == '其他'
                      ? otherLitterController.text
                      : (litterType ?? ''),
                  options: PetProfileCatalog.litters,
                  requiredValue: true,
                  enabled: healthEnabled,
                  decoration: petProfileInputDecoration(
                    theme: theme,
                    label: '貓砂種類',
                  ),
                  hint: '選擇慣用貓砂，其他可自行填寫',
                  onChanged: (v) {
                    otherLitterController.clear();
                    onLitterChanged(v);
                  },
                ),
                const SizedBox(height: 12),
              ],
              for (final field in PetProfileCatalog.habits(species)) ...[
                PetCatalogField(
                  theme: theme,
                  label: field.label,
                  value: careHabits[field.key] ?? '',
                  options: field.options,
                  enabled: healthEnabled,
                  decoration: petProfileInputDecoration(
                    theme: theme,
                    label: '${field.label}（選填）',
                  ),
                  onChanged: (v) {
                    onCareHabitChanged?.call(field.key, v);
                    onChanged();
                  },
                ),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 12),
              TextFormField(
                autovalidateMode: AutovalidateMode.onUserInteraction,
                controller: noteController,
                minLines: 3,
                maxLines: 5,
                style: fieldStyle,
                decoration: petProfileInputDecoration(
                  theme: theme,
                  label: species == 'dog' ? '狗狗其他照護備註' : '貓咪其他照護備註',
                  hint: species == 'dog'
                      ? '例如：散步時間、牽繩注意事項、安撫方式'
                      : '例如：餵食份量、躲藏偏好、安撫方式',
                ),
              ),
              if (adminNoteController != null) ...<Widget>[
                const SizedBox(height: 12),
                TextFormField(
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  controller: adminNoteController,
                  minLines: 2,
                  maxLines: 4,
                  style: fieldStyle,
                  decoration: petProfileInputDecoration(
                    theme: theme,
                    label: '員工備註（只有後台看得到）',
                  ),
                ),
              ],
            ],
          ),
          ...extraChildren,
        ],
      ),
    );
  }
}
