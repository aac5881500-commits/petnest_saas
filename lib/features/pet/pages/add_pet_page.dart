// 檔案名稱：lib/features/pet/pages/add_pet_page.dart
// 功能說明：新增寵物（與編輯寵物共用表單視覺），並填寫店家新增寵物自訂表單。

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/custom_form_answer_model.dart';
import 'package:petnest_saas/core/models/custom_form_model.dart';
import 'package:petnest_saas/core/models/fixed_image_spec.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/services/custom_form_service.dart';
import 'package:petnest_saas/core/services/pet_service.dart';
import 'package:petnest_saas/features/custom_form/widgets/custom_form_response_fields.dart';
import 'package:petnest_saas/features/pet/widgets/pet_profile_form.dart';
import 'package:petnest_saas/features/shop/widgets/media/fixed_image_pick_flow.dart';

class AddPetPage extends StatefulWidget {
  const AddPetPage({
    super.key,
    required this.shopId,
    this.theme = HomeThemeModel.modernDefault,
    this.skipRemoteLoads = false,
    this.seedCustomForm,
  });

  final String shopId;
  final HomeThemeModel theme;

  @visibleForTesting
  final bool skipRemoteLoads;

  @visibleForTesting
  final CustomFormModel? seedCustomForm;

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
  final Map<String, GlobalKey> _questionKeys = <String, GlobalKey>{};

  String? _ageRange;
  String? _neuterStatus;
  String? _medicalStatus;
  String? _litterType;
  String? _gender;
  Uint8List? _imageBytes;
  bool _loading = false;
  bool _formLoading = false;
  bool _formLoadFailed = false;
  CustomFormModel? _customForm;
  Map<String, dynamic> _customAnswers = <String, dynamic>{};

  HomeThemeModel get _theme => widget.theme;

  bool get _needsCustomForm => _customForm?.shouldCollectAnswers == true;

  @override
  void initState() {
    super.initState();
    if (widget.skipRemoteLoads) {
      _customForm = widget.seedCustomForm;
      return;
    }
    _loadCustomForm();
  }

  Future<void> _loadCustomForm() async {
    setState(() {
      _formLoading = true;
      _formLoadFailed = false;
    });
    final CustomFormFrontLoadResult result = await CustomFormService.instance
        .loadFormForCustomer(
          shopId: widget.shopId,
          formType: CustomFormType.petProfile,
        );
    if (!mounted) {
      return;
    }
    setState(() {
      _formLoading = false;
      _formLoadFailed = result.failed;
      _customForm = result.form;
    });
  }

  Future<void> _submit() async {
    if (_formLoading) {
      return;
    }
    if (_formLoadFailed) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('表單載入失敗，請重試')));
      return;
    }
    final bool valid = _formKey.currentState?.validate() == true;
    if (!valid) {
      _scrollToFirstError();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請完成必填欄位')));
      return;
    }
    if (_needsCustomForm) {
      final CustomFormValidationResult check =
          CustomFormAnswerSnapshot.validate(
            form: _customForm!,
            answersByQuestionId: _customAnswers,
          );
      if (!check.isValid) {
        _scrollToFirstError(questionId: check.firstInvalidQuestionId);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(check.message)));
        return;
      }
    }
    setState(() => _loading = true);
    try {
      Map<String, dynamic>? answersMap;
      if (_needsCustomForm) {
        answersMap = CustomFormAnswerSnapshot.build(
          form: _customForm!,
          answersByQuestionId: _customAnswers,
        ).toFirestoreMap();
      }
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
        shopId: widget.shopId,
        customFormAnswers: answersMap,
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

  void _scrollToFirstError({String questionId = ''}) {
    final GlobalKey? key = questionId.isNotEmpty
        ? _questionKeys[questionId]
        : _questionKeys.values.cast<GlobalKey?>().firstWhere(
            (GlobalKey? item) => item?.currentContext != null,
            orElse: () => null,
          );
    final BuildContext? target = key?.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 280),
        alignment: 0.15,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _nameController.dispose();
    _breedController.dispose();
    _otherMedicalController.dispose();
    _otherLitterController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  List<Widget> _customFormChildren() {
    if (_formLoading) {
      return <Widget>[
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.2),
            ),
          ),
        ),
      ];
    }
    if (_formLoadFailed) {
      return <Widget>[
        PetFormSectionCard(
          theme: _theme,
          icon: Icons.error_outline,
          title: '店家照護資料',
          children: <Widget>[
            Text('表單載入失敗，請重試', style: TextStyle(color: _theme.textColor)),
            TextButton(onPressed: _loadCustomForm, child: const Text('重試')),
          ],
        ),
      ];
    }
    final CustomFormModel? form = _customForm;
    if (form == null || !form.shouldCollectAnswers) {
      return const <Widget>[];
    }
    for (final (CustomFormSection _, CustomFormQuestion question)
        in form.enabledQuestionEntries) {
      _questionKeys.putIfAbsent(question.id, GlobalKey.new);
    }
    return <Widget>[
      CustomFormResponseFields(
        form: form,
        answers: _customAnswers,
        theme: _theme,
        fieldKeys: _questionKeys,
        onChanged: (Map<String, dynamic> next) {
          setState(() => _customAnswers = next);
        },
      ),
    ];
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
              gender: _gender,
              ageRange: _ageRange,
              neuterStatus: _neuterStatus,
              medicalStatus: _medicalStatus,
              litterType: _litterType,
              imageBytes: _imageBytes,
              extraChildren: _customFormChildren(),
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
            primaryEnabled: !_formLoading,
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
