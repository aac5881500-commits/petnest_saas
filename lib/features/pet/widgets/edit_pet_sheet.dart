// 檔案名稱：lib/features/pet/widgets/edit_pet_sheet.dart
// 功能說明：編輯寵物：接近全螢幕的 Modal Bottom Sheet，與新增寵物共用表單。

import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/fixed_image_spec.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/features/pet/widgets/pet_profile_form.dart';
import 'package:petnest_saas/features/shop/widgets/media/fixed_image_pick_flow.dart';

Future<bool> showEditPetSheet({
  required BuildContext context,
  required Map<String, dynamic> pet,
  required HomeThemeModel theme,
  bool isAdminView = false,
}) async {
  final bool? saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext context) {
      return EditPetSheet(pet: pet, theme: theme, isAdminView: isAdminView);
    },
  );
  return saved == true;
}

class EditPetSheet extends StatefulWidget {
  const EditPetSheet({
    super.key,
    required this.pet,
    required this.theme,
    this.isAdminView = false,
  });

  final Map<String, dynamic> pet;
  final HomeThemeModel theme;
  final bool isAdminView;

  @override
  State<EditPetSheet> createState() => _EditPetSheetState();
}

class _EditPetSheetState extends State<EditPetSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _breedController;
  late final TextEditingController _noteController;
  late final TextEditingController _adminNoteController;
  late final TextEditingController _otherMedicalController;
  late final TextEditingController _otherLitterController;

  String? _gender;
  String? _ageRange;
  String? _neuterStatus;
  String? _medicalStatus;
  String? _litterType;
  Uint8List? _imageBytes;
  bool _loading = false;
  bool _valid = true;

  @override
  void initState() {
    super.initState();
    final Map<String, dynamic> pet = widget.pet;
    _nameController = TextEditingController(
      text: (pet['name'] ?? '').toString(),
    );
    _breedController = TextEditingController(
      text: (pet['breed'] ?? '').toString(),
    );
    _noteController = TextEditingController(
      text: (pet['note'] ?? '').toString(),
    );
    _adminNoteController = TextEditingController(
      text: (pet['adminNote'] ?? '').toString(),
    );

    _gender = pet['gender']?.toString();
    _ageRange = pet['age']?.toString();
    _neuterStatus = pet['isNeutered'] == true ? '有結紮' : '未結紮';

    final String vaccine = (pet['vaccine'] ?? '').toString();
    if (PetProfileForm.medicalOptions.contains(vaccine) || vaccine.isEmpty) {
      _medicalStatus = vaccine.isEmpty ? null : vaccine;
      _otherMedicalController = TextEditingController();
    } else {
      _medicalStatus = '其他';
      _otherMedicalController = TextEditingController(text: vaccine);
    }

    final String litter = (pet['litterType'] ?? '').toString();
    if (PetProfileForm.litterOptions.contains(litter) || litter.isEmpty) {
      _litterType = litter.isEmpty ? null : litter;
      _otherLitterController = TextEditingController();
    } else {
      _litterType = '其他';
      _otherLitterController = TextEditingController(text: litter);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _breedController.dispose();
    _noteController.dispose();
    _adminNoteController.dispose();
    _otherMedicalController.dispose();
    _otherLitterController.dispose();
    super.dispose();
  }

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

  Future<void> _save() async {
    if (_formKey.currentState?.validate() != true) {
      setState(() => _valid = false);
      return;
    }
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }
    setState(() => _loading = true);
    try {
      final String uid = (widget.pet['userId'] ?? user.uid).toString();
      final String petId = (widget.pet['petId'] ?? '').toString();

      await FirebaseFirestore.instance
          .collection('user_profiles')
          .doc(uid)
          .collection('pets')
          .doc(petId)
          .update(<String, dynamic>{
            'name': _nameController.text.trim(),
            'age': _ageRange,
            'gender': _gender,
            'breed': _breedController.text.trim(),
            'isNeutered': _neuterStatus == '有結紮',
            'vaccine': _medicalStatus == '其他'
                ? _otherMedicalController.text.trim()
                : _medicalStatus,
            'litterType': _litterType == '其他'
                ? _otherLitterController.text.trim()
                : _litterType,
            'note': _noteController.text.trim(),
            'adminNote': _adminNoteController.text.trim(),
          });

      if (_imageBytes != null) {
        final Reference ref = FirebaseStorage.instance
            .ref()
            .child('pets')
            .child(uid)
            .child('$petId.jpg');
        await ref.putData(
          _imageBytes!,
          SettableMetadata(contentType: 'image/jpeg'),
        );
        final String url = await ref.getDownloadURL();
        await FirebaseFirestore.instance
            .collection('user_profiles')
            .doc(uid)
            .collection('pets')
            .doc(petId)
            .update(<String, dynamic>{'photoUrl': url});
      }

      if (!mounted) {
        return;
      }
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('儲存失敗：$error')));
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final HomeThemeModel theme = widget.theme;
    final MediaQueryData media = MediaQuery.of(context);
    final double height = media.size.height * 0.92;

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 520, maxHeight: height),
        child: Material(
          color: theme.backgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
              child: Column(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            '編輯寵物',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: theme.textColor,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _loading
                              ? null
                              : () => Navigator.pop(context, false),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: PetProfileForm(
                      theme: theme,
                      formKey: _formKey,
                      nameController: _nameController,
                      breedController: _breedController,
                      otherMedicalController: _otherMedicalController,
                      otherLitterController: _otherLitterController,
                      noteController: _noteController,
                      adminNoteController: widget.isAdminView
                          ? _adminNoteController
                          : null,
                      gender: _gender,
                      ageRange: _ageRange,
                      neuterStatus: _neuterStatus,
                      medicalStatus: _medicalStatus,
                      litterType: _litterType,
                      imageBytes: _imageBytes,
                      networkPhotoUrl: (widget.pet['photoUrl'] ?? '')
                          .toString(),
                      nameEnabled: !widget.isAdminView,
                      healthEnabled: !widget.isAdminView,
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
                    ),
                  ),
                  PetFormStickyBar(
                    theme: theme,
                    primaryLabel: '儲存',
                    secondaryLabel: '取消',
                    loading: _loading,
                    primaryEnabled: _valid,
                    onPrimary: _save,
                    onSecondary: () => Navigator.pop(context, false),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
