// lib/features/pet/widgets/pet_profile_form.dart
// 🐾 新增／編輯寵物共用表單視覺與欄位。

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';

InputDecoration petProfileInputDecoration({
  required HomeThemeModel theme,
  required String label,
  String? hint,
}) {
  final Color fill = Color.alphaBlend(
    theme.primaryColor.withValues(alpha: 0.06),
    theme.cardColor,
  );
  return InputDecoration(
    labelText: label,
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
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
    this.imageBytes,
    this.networkPhotoUrl,
    this.nameEnabled = true,
    this.healthEnabled = true,
    this.adminNoteController,
    this.bottomPadding = 16,
  });

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

  static const List<String> genders = <String>['公貓', '母貓'];
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
      autovalidateMode: AutovalidateMode.onUserInteraction,
      onChanged: onChanged,
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPadding),
        children: <Widget>[
          PetFormSectionCard(
            theme: theme,
            icon: Icons.pets_outlined,
            title: '基本資料',
            children: <Widget>[
              PetPhotoPicker(
                theme: theme,
                onTap: onPickPhoto,
                imageBytes: imageBytes,
                networkUrl: networkPhotoUrl,
              ),
              const SizedBox(height: 14),
              TextFormField(
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
              DropdownButtonFormField<String>(
                key: const ValueKey<String>('pet-gender'),
                initialValue: genders.contains(gender) ? gender : null,
                style: fieldStyle,
                decoration: petProfileInputDecoration(
                  theme: theme,
                  label: '性別',
                ),
                hint: const Text('請選擇性別', style: TextStyle(fontSize: 14)),
                validator: (String? value) => value == null ? '請選擇性別' : null,
                items: genders
                    .map(
                      (String item) => DropdownMenuItem<String>(
                        value: item,
                        child: Text(item, style: fieldStyle),
                      ),
                    )
                    .toList(),
                onChanged: nameEnabled ? onGenderChanged : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: breedController,
                style: fieldStyle,
                decoration: petProfileInputDecoration(
                  theme: theme,
                  label: '品種',
                  hint: '選填',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: const ValueKey<String>('pet-age'),
                initialValue: ages.contains(ageRange) ? ageRange : null,
                style: fieldStyle,
                decoration: petProfileInputDecoration(
                  theme: theme,
                  label: '年齡',
                ),
                hint: const Text('請選擇年齡', style: TextStyle(fontSize: 14)),
                validator: (String? value) => value == null ? '請選擇年齡' : null,
                items: const <DropdownMenuItem<String>>[
                  DropdownMenuItem<String>(
                    value: '6~12個月',
                    child: Text('含6~12個月', style: TextStyle(fontSize: 14)),
                  ),
                  DropdownMenuItem<String>(
                    value: '1~10歲',
                    child: Text('1~10歲', style: TextStyle(fontSize: 14)),
                  ),
                  DropdownMenuItem<String>(
                    value: '10~12歲',
                    child: Text('10~12歲', style: TextStyle(fontSize: 14)),
                  ),
                  DropdownMenuItem<String>(
                    value: '12歲以上',
                    child: Text('12歲以上', style: TextStyle(fontSize: 14)),
                  ),
                ],
                onChanged: nameEnabled ? onAgeChanged : null,
              ),
            ],
          ),
          PetFormSectionCard(
            theme: theme,
            icon: Icons.health_and_safety_outlined,
            title: '健康資訊',
            children: <Widget>[
              if (neuterStatus == '未結紮') ...<Widget>[
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
                    '未結紮公貓可能會有噴尿情況，將會額外收費（詳見入住須知）。',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: Colors.red.shade800,
                    ),
                  ),
                ),
              ],
              DropdownButtonFormField<String>(
                key: const ValueKey<String>('pet-neuter'),
                initialValue: neuterOptions.contains(neuterStatus)
                    ? neuterStatus
                    : null,
                style: fieldStyle,
                decoration: petProfileInputDecoration(
                  theme: theme,
                  label: '結紮狀況',
                ),
                hint: const Text('請選擇結紮狀況', style: TextStyle(fontSize: 14)),
                validator: (String? value) => value == null ? '請選擇結紮狀況' : null,
                items: neuterOptions
                    .map(
                      (String item) => DropdownMenuItem<String>(
                        value: item,
                        child: Text(item, style: fieldStyle),
                      ),
                    )
                    .toList(),
                onChanged: healthEnabled ? onNeuterChanged : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: const ValueKey<String>('pet-medical'),
                initialValue: medicalOptions.contains(medicalStatus)
                    ? medicalStatus
                    : null,
                style: fieldStyle,
                decoration: petProfileInputDecoration(
                  theme: theme,
                  label: '醫療狀況',
                ),
                hint: const Text('請選擇醫療狀況', style: TextStyle(fontSize: 14)),
                validator: (String? value) => value == null ? '請選擇醫療狀況' : null,
                items: const <DropdownMenuItem<String>>[
                  DropdownMenuItem<String>(value: '無', child: Text('無')),
                  DropdownMenuItem<String>(
                    value: '慢性腎臟病',
                    child: Text('慢性腎臟病'),
                  ),
                  DropdownMenuItem<String>(value: '心臟病', child: Text('心臟病')),
                  DropdownMenuItem<String>(value: '糖尿病', child: Text('糖尿病')),
                  DropdownMenuItem<String>(value: '術後照護', child: Text('術後照護')),
                  DropdownMenuItem<String>(value: '皮膚疾病', child: Text('皮膚治療')),
                  DropdownMenuItem<String>(value: '其他', child: Text('其他')),
                ],
                onChanged: healthEnabled ? onMedicalChanged : null,
              ),
              if (medicalStatus == '其他') ...<Widget>[
                const SizedBox(height: 12),
                TextFormField(
                  controller: otherMedicalController,
                  style: fieldStyle,
                  decoration: petProfileInputDecoration(
                    theme: theme,
                    label: '請填寫醫療內容',
                  ),
                  validator: (String? value) {
                    if (value == null || value.trim().isEmpty) {
                      return '請填寫醫療內容';
                    }
                    return null;
                  },
                ),
              ],
            ],
          ),
          PetFormSectionCard(
            theme: theme,
            icon: Icons.home_outlined,
            title: '住宿習慣',
            children: <Widget>[
              DropdownButtonFormField<String>(
                key: const ValueKey<String>('pet-litter'),
                initialValue: litterOptions.contains(litterType)
                    ? litterType
                    : null,
                style: fieldStyle,
                decoration: petProfileInputDecoration(
                  theme: theme,
                  label: '貓砂種類',
                ),
                hint: const Text('請選擇貓砂', style: TextStyle(fontSize: 14)),
                validator: (String? value) => value == null ? '請選擇貓砂' : null,
                items: litterOptions
                    .map(
                      (String item) => DropdownMenuItem<String>(
                        value: item,
                        child: Text(item, style: fieldStyle),
                      ),
                    )
                    .toList(),
                onChanged: healthEnabled ? onLitterChanged : null,
              ),
              if (litterType == '其他') ...<Widget>[
                const SizedBox(height: 12),
                TextFormField(
                  controller: otherLitterController,
                  style: fieldStyle,
                  decoration: petProfileInputDecoration(
                    theme: theme,
                    label: '請填寫貓砂種類',
                  ),
                  validator: (String? value) {
                    if (value == null || value.trim().isEmpty) {
                      return '請填寫貓砂種類';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: noteController,
                minLines: 3,
                maxLines: 5,
                style: fieldStyle,
                decoration: petProfileInputDecoration(
                  theme: theme,
                  label: '其他備註',
                  hint: '選填',
                ),
              ),
              if (adminNoteController != null) ...<Widget>[
                const SizedBox(height: 12),
                TextFormField(
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
        ],
      ),
    );
  }
}
