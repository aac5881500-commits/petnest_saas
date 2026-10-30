import 'package:petnest_saas/core/models/pet_species.dart';
import 'package:petnest_saas/core/models/pet_profile_catalog.dart';
// 檔案名稱：lib/features/pet/pages/add_pet_page.dart
// 功能說明：新增寵物（與編輯寵物共用表單視覺），僅填寫跨店共用基本資料。

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/fixed_image_spec.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/services/pet_service.dart';
import 'package:petnest_saas/features/pet/widgets/pet_profile_form.dart';
import 'package:petnest_saas/features/shop/widgets/media/fixed_image_pick_flow.dart';

class AddPetPage extends StatefulWidget {
  const AddPetPage({
    super.key,
    required this.shopId,
    this.theme = HomeThemeModel.modernDefault,
  });

  final String shopId;
  final HomeThemeModel theme;

  @override
  State<AddPetPage> createState() => _AddPetPageState();
}

class _AddPetPageState extends State<AddPetPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _breedController = TextEditingController();
  final TextEditingController _otherMedicalController = TextEditingController();
  final TextEditingController _otherLitterController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  String? _ageRange;
  String? _neuterStatus;
  String? _medicalStatus;
  String? _litterType;
  final Map<String, String> _careHabits = {};
  String? _species;
  final _vaccineController = TextEditingController();
  String? _gender;
  Uint8List? _imageBytes;
  bool _loading = false;

  HomeThemeModel get _theme => widget.theme;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _submit() async {
    final bool valid = _formKey.currentState?.validate() == true;
    final missing = PetProfileCatalog.missingRequired(
      species: _species,
      name: _nameController.text,
      gender: _gender,
      age: _ageRange,
      neuter: _neuterStatus,
      medical: _medicalStatus == '其他'
          ? _otherMedicalController.text
          : _medicalStatus,
      litter: _litterType == '其他' ? _otherLitterController.text : _litterType,
    );
    if (!valid || missing.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            missing.isEmpty ? '請完成必填欄位' : '請填寫：${missing.join('、')}',
          ),
        ),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final String petId = await PetService.instance.createPet(
        name: _nameController.text.trim(),
        age: _ageRange ?? '',
        breed: _breedController.text.trim(),
        note: _noteController.text.trim(),
        gender: PetSpecies.genderLabel(_gender),
        litterType: _species == 'dog'
            ? ''
            : _litterType == '其他'
            ? _otherLitterController.text.trim()
            : (_litterType ?? ''),
        species: _species!,
        careHabits: PetProfileCatalog.cleanHabits(_careHabits, _species),
        vaccineTypes: _vaccineController.text.trim(),
        medicalStatus: _medicalStatus == '其他'
            ? _otherMedicalController.text.trim()
            : (_medicalStatus ?? ''),
        isNeutered: _neuterStatus?.contains('未結紮') == false,
        canSocial: _careHabits['dogSocial'] == '可與其他狗互動',
        canMedicate: _medicalStatus != '無',
        shopId: widget.shopId,
      );
      if (_imageBytes != null) {
        await PetService.instance.uploadPetPhoto(
          petId: petId,
          bytes: _imageBytes!,
          alreadyProcessed: true,
        );
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('新增成功')));
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('錯誤：$error')));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _vaccineController.dispose();
    _nameController.dispose();
    _breedController.dispose();
    _otherMedicalController.dispose();
    _otherLitterController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _theme.backgroundColor,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: _theme.cardColor,
        foregroundColor: _theme.textColor,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          '新增寵物',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: PetProfileForm(
              theme: _theme,
              formKey: _formKey,
              scrollController: _scrollController,
              nameController: _nameController,
              breedController: _breedController,
              otherMedicalController: _otherMedicalController,
              otherLitterController: _otherLitterController,
              noteController: _noteController,
              careHabits: _careHabits,
              onCareHabitChanged: (key, value) => setState(() {
                _careHabits[key] = value;
              }),
              species: _species,
              vaccineController: _vaccineController,
              onSpeciesChanged: (v) => setState(() {
                if (_species != v) {
                  _species = v;
                  _breedController.clear();
                  _vaccineController.clear();
                  _medicalStatus = null;
                  _litterType = null;
                  _otherMedicalController.clear();
                  _otherLitterController.clear();
                  _careHabits.clear();
                }
              }),
              gender: _gender,
              ageRange: _ageRange,
              neuterStatus: _neuterStatus,
              medicalStatus: _medicalStatus,
              litterType: _litterType,
              imageBytes: _imageBytes,
              extraChildren: const <Widget>[],
              onGenderChanged: (String? value) =>
                  setState(() => _gender = value),
              onAgeChanged: (String? value) =>
                  setState(() => _ageRange = value),
              onNeuterChanged: (String? value) =>
                  setState(() => _neuterStatus = value),
              onMedicalChanged: (String? value) =>
                  setState(() => _medicalStatus = value),
              onLitterChanged: (String? value) =>
                  setState(() => _litterType = value),
              onPickPhoto: _pickImage,
              onChanged: () {},
              bottomPadding: 24,
            ),
          ),
          PetFormStickyBar(
            theme: _theme,
            primaryLabel: '新增寵物',
            loading: _loading,
            primaryEnabled: !_loading,
            onPrimary: _submit,
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      final Uint8List? cropped = await FixedImagePickFlow.pickAndCrop(
        context: context,
        spec: FixedImageSpec.memberAvatar,
        title: '裁切寵物頭像',
      );
      if (cropped == null) {
        return;
      }
      setState(() => _imageBytes = cropped);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('選擇圖片失敗：$error')));
    }
  }
}
