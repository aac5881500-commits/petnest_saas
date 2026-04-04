// lib/features/pet/pages/add_pet_page.dart
// 🐱 新增寵物（完整版🔥 UI升級＋性別＋品種＋圖片）

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/pet_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';

class AddPetPage extends StatefulWidget {
  const AddPetPage({super.key});

  @override
  State<AddPetPage> createState() => _AddPetPageState();
}

class _AddPetPageState extends State<AddPetPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _breedController = TextEditingController();
  final _otherMedicalController = TextEditingController();
  final _otherLitterController = TextEditingController();
  final _noteController = TextEditingController();

  String? _ageRange;
  String? _neuterStatus;
  String? _medicalStatus;
  String? _litterType;
  String? _gender;

  Uint8List? _imageBytes;
  bool _loading = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);

    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _imageBytes = bytes;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final petId = await PetService.instance.createPet(
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
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('新增成功')),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('錯誤：$e')),
      );
    } finally {
      setState(() => _loading = false);
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
      appBar: AppBar(title: const Text('新增寵物')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [

              /// 🖼️ 照片
              GestureDetector(
                onTap: _pickImage,
                child: Center(
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey[200],
                      border: Border.all(color: Colors.grey.shade400),
                    ),
                    child: _imageBytes != null
                        ? ClipOval(
                            child: Image.memory(
                              _imageBytes!,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.camera_alt, size: 40),
                              SizedBox(height: 6),
                              Text('上傳照片'),
                            ],
                          ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              /// 名字
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: '寵物名字'),
                validator: (v) =>
                    v == null || v.isEmpty ? '請輸入寵物名字' : null,
              ),

              const SizedBox(height: 16),

              /// 性別
              DropdownButtonFormField<String>(
                value: _gender,
                hint: const Text('請選擇性別'),
                decoration: const InputDecoration(labelText: '性別'),
                validator: (v) => v == null ? '請選擇性別' : null,
                items: ['公貓', '母貓']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => setState(() => _gender = v),
              ),

              const SizedBox(height: 16),

              /// 品種（可空）
              TextField(
                controller: _breedController,
                decoration: const InputDecoration(labelText: '品種'),
              ),

              const SizedBox(height: 24),

              const Text('住宿貓咪年齡 *'),

              DropdownButtonFormField<String>(
                value: _ageRange,
                hint: const Text('請選擇年齡'),
                validator: (v) => v == null ? '請選擇年齡' : null,
                items: const [
                  DropdownMenuItem(value: '6~12個月', child: Text('含6~12個月')),
                  DropdownMenuItem(value: '1~10歲', child: Text('1~10歲')),
                  DropdownMenuItem(value: '10~12歲', child: Text('10~12歲')),
                  DropdownMenuItem(value: '12歲以上', child: Text('12歲以上')),
                ],
                onChanged: (v) => setState(() => _ageRange = v),
              ),

              const SizedBox(height: 24),

              /// 🔥 未結紮提示（保留）
              const Text('是否有未結紮的貓咪 *'),
              const Text(
                '※ 未結紮公貓可能會有噴尿情況，將會額外收費（詳見入住須知）',
                style: TextStyle(color: Colors.red),
              ),

              DropdownButtonFormField<String>(
                value: _neuterStatus,
                hint: const Text('請選擇結紮狀況'),
                validator: (v) => v == null ? '請選擇結紮狀況' : null,
                items: const [
                  DropdownMenuItem(value: '有結紮公貓', child: Text('有結紮公貓')),
                  DropdownMenuItem(value: '有結紮母貓', child: Text('有結紮母貓')),
                  DropdownMenuItem(value: '未結紮公貓', child: Text('未結紮公貓')),
                  DropdownMenuItem(value: '未結紮母貓', child: Text('未結紮母貓')),
                ],
                onChanged: (v) => setState(() => _neuterStatus = v),
              ),

              const SizedBox(height: 24),

              const Text('是否正在接受藥物治療 *'),

              DropdownButtonFormField<String>(
                value: _medicalStatus,
                hint: const Text('請選擇醫療狀況'),
                validator: (v) => v == null ? '請選擇醫療狀況' : null,
                items: const [
                  DropdownMenuItem(value: '無', child: Text('無')),
                  DropdownMenuItem(value: '慢性腎臟病', child: Text('慢性腎臟病')),
                  DropdownMenuItem(value: '心臟病', child: Text('心臟病')),
                  DropdownMenuItem(value: '糖尿病', child: Text('糖尿病')),
                  DropdownMenuItem(value: '術後照護', child: Text('術後照護')),
                  DropdownMenuItem(value: '皮膚疾病', child: Text('皮膚治療')),
                  DropdownMenuItem(value: '其他', child: Text('其他')),
                ],
                onChanged: (v) => setState(() => _medicalStatus = v),
              ),

              if (_medicalStatus == '其他')
                TextFormField(
                  controller: _otherMedicalController,
                  decoration: const InputDecoration(labelText: '請填寫'),
                  validator: (v) =>
                      v == null || v.isEmpty ? '請填寫醫療內容' : null,
                ),

              const SizedBox(height: 24),

              const Text('使用貓砂種類 *'),

              DropdownButtonFormField<String>(
                value: _litterType,
                hint: const Text('請選擇貓砂'),
                validator: (v) => v == null ? '請選擇貓砂' : null,
                items: const [
                  DropdownMenuItem(value: '豆腐砂', child: Text('豆腐砂')),
                  DropdownMenuItem(value: '礦砂', child: Text('礦砂')),
                  DropdownMenuItem(value: '其他', child: Text('其他')),
                ],
                onChanged: (v) => setState(() => _litterType = v),
              ),

              if (_litterType == '其他')
                TextFormField(
                  controller: _otherLitterController,
                  decoration: const InputDecoration(labelText: '請填寫'),
                  validator: (v) =>
                      v == null || v.isEmpty ? '請填寫貓砂種類' : null,
                ),

              const SizedBox(height: 24),

              const Text('其他需求 & 注意事項'),

              TextField(
                controller: _noteController,
                maxLines: 3,
              ),

              const SizedBox(height: 32),

              ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const CircularProgressIndicator()
                    : const Text('送出'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}