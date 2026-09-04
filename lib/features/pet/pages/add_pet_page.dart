// lib/features/pet/pages/add_pet_page.dart
// 🐱 新增寵物（與編輯寵物共用表單視覺）

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/fixed_image_spec.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/services/pet_service.dart';
import 'package:petnest_saas/features/pet/widgets/pet_profile_form.dart';
import 'package:petnest_saas/features/shop/widgets/media/fixed_image_pick_flow.dart';

class AddPetPage extends StatefulWidget {
  const AddPetPage({super.key, this.theme = HomeThemeModel.modernDefault});

  final HomeThemeModel theme;

  @override
  State<AddPetPage> createState() => _AddPetPageState();
}

class _AddPetPageState extends State<AddPetPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _breedController = TextEditingController();
  final TextEditingController _otherMedicalController = TextEditingController();
  final TextEditingController _otherLitterController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  String? _ageRange;
  String? _neuterStatus;
  String? _medicalStatus;
  String? _litterType;
  String? _gender;
  Uint8List? _imageBytes;
  bool _loading = false;
  bool _valid = false;

  HomeThemeModel get _theme => widget.theme;

  void _refreshValid() {
    final bool ok = _formKey.currentState?.validate() == true;
    if (ok != _valid) {
      setState(() => _valid = ok);
    }
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

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true) {
      setState(() => _valid = false);
      return;
    }
    setState(() => _loading = true);
    try {
      final String petId = await PetService.instance.createPet(
        name: _nameController.text.trim(),
        age: _ageRange ?? '',
        breed: _breedController.text.trim(),
        note: _noteController.text.trim(),
        gender: _gender ?? '',
        litterType: _litterType == '其他'
            ? _otherLitterController.text.trim()
            : (_litterType ?? ''),
        vaccine: _medicalStatus == '其他'
            ? _otherMedicalController.text.trim()
            : (_medicalStatus ?? ''),
        isNeutered: _neuterStatus?.contains('未結紮') == false,
        canSocial: true,
        canMedicate: _medicalStatus != '無',
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
              nameController: _nameController,
              breedController: _breedController,
              otherMedicalController: _otherMedicalController,
              otherLitterController: _otherLitterController,
              noteController: _noteController,
              gender: _gender,
              ageRange: _ageRange,
              neuterStatus: _neuterStatus,
              medicalStatus: _medicalStatus,
              litterType: _litterType,
              imageBytes: _imageBytes,
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
              onChanged: _refreshValid,
              bottomPadding: 24,
            ),
          ),
          PetFormStickyBar(
            theme: _theme,
            primaryLabel: '新增寵物',
            loading: _loading,
            primaryEnabled: _valid,
            onPrimary: _submit,
          ),
        ],
      ),
    );
  }
}
