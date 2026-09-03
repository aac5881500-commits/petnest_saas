// lib/features/pet/pages/pet_detail_page.dart
// 🐱 前台寵物詳細頁

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/features/pet/widgets/edit_pet_sheet.dart';

class PetDetailPage extends StatelessWidget {
  const PetDetailPage({
    super.key,
    required this.pet,
    this.isAdminView = false,
    this.theme = HomeThemeModel.modernDefault,
  });

  final Map<String, dynamic> pet;
  final bool isAdminView;
  final HomeThemeModel theme;

  @override
  Widget build(BuildContext context) {
    final String uid =
        (pet['userId'] ?? FirebaseAuth.instance.currentUser?.uid ?? '')
            .toString();
    final String petId = (pet['petId'] ?? '').toString();

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        backgroundColor: theme.cardColor,
        foregroundColor: theme.textColor,
        surfaceTintColor: Colors.transparent,
        title: Text(
          (pet['name'] ?? '寵物資料').toString(),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: uid.isEmpty || petId.isEmpty
          ? _PetDetailBody(pet: pet, theme: theme, isAdminView: isAdminView)
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('user_profiles')
                  .doc(uid)
                  .collection('pets')
                  .doc(petId)
                  .snapshots(),
              builder:
                  (
                    BuildContext context,
                    AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>>
                    snapshot,
                  ) {
                    final Map<String, dynamic> data =
                        snapshot.data?.data() ?? pet;
                    return _PetDetailBody(
                      pet: data,
                      theme: theme,
                      isAdminView: isAdminView,
                    );
                  },
            ),
    );
  }
}

class _PetDetailBody extends StatelessWidget {
  const _PetDetailBody({
    required this.pet,
    required this.theme,
    required this.isAdminView,
  });

  final Map<String, dynamic> pet;
  final HomeThemeModel theme;
  final bool isAdminView;

  String _text(dynamic value) {
    final String text = (value ?? '').toString().trim();
    return text;
  }

  @override
  Widget build(BuildContext context) {
    final String photoUrl = _text(pet['photoUrl']);
    final String name = _text(pet['name']).isEmpty ? '未命名' : _text(pet['name']);
    final String gender = _text(pet['gender']);
    final String age = _text(pet['age']);
    final String breed = _text(pet['breed']);
    final String note = _text(pet['note']);
    final bool neutered = pet['isNeutered'] == true;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: <Widget>[
        _heroCard(
          context,
          photoUrl: photoUrl,
          name: name,
          gender: gender,
          age: age,
          breed: breed,
        ),
        const SizedBox(height: 12),
        _sectionCard(
          icon: Icons.info_outline,
          title: '基本資料',
          children: <Widget>[
            _infoRow(Icons.badge_outlined, '名稱', name),
            _infoRow(Icons.category_outlined, '品種', breed),
            _infoRow(Icons.wc_outlined, '性別', gender),
            _infoRow(Icons.cake_outlined, '年齡', age),
          ],
        ),
        const SizedBox(height: 12),
        _sectionCard(
          icon: Icons.health_and_safety_outlined,
          title: '健康資訊',
          children: <Widget>[
            _infoRow(
              Icons.content_cut_outlined,
              '結紮狀況',
              neutered ? '已結紮' : '未結紮',
            ),
            if (!neutered) ...<Widget>[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
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
            _infoRow(
              Icons.medical_services_outlined,
              '醫療狀況',
              _text(pet['vaccine']),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _sectionCard(
          icon: Icons.home_outlined,
          title: '住宿習慣',
          children: <Widget>[
            _infoRow(
              Icons.inventory_2_outlined,
              '貓砂種類',
              _text(pet['litterType']),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _notesCard(note),
        const SizedBox(height: 12),
        _sectionCard(
          icon: Icons.assignment_outlined,
          title: '店家自訂資料',
          children: <Widget>[
            Text(
              '尚無自訂資料',
              style: TextStyle(
                fontSize: 12,
                color: theme.textColor.withValues(alpha: 0.45),
              ),
            ),
          ],
        ),
        if (isAdminView) ...<Widget>[
          const SizedBox(height: 12),
          _sectionCard(
            icon: Icons.lock_outline,
            title: '員工備註（內部）',
            children: <Widget>[
              _infoRow(Icons.notes_outlined, '備註', _text(pet['adminNote'])),
            ],
          ),
        ],
      ],
    );
  }

  Widget _heroCard(
    BuildContext context, {
    required String photoUrl,
    required String name,
    required String gender,
    required String age,
    required String breed,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.cardBorderColor),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color.alphaBlend(
              theme.primaryColor.withValues(alpha: 0.12),
              theme.cardColor,
            ),
            theme.cardColor,
          ],
        ),
      ),
      child: Stack(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 10, 6, 4),
            child: Column(
              children: <Widget>[
                GestureDetector(
                  onTap: photoUrl.isEmpty
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  _FullImagePage(imageUrl: photoUrl),
                            ),
                          );
                        },
                  child: Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.primaryColor.withValues(alpha: 0.12),
                      border: Border.all(
                        color: theme.cardBorderColor,
                        width: 1.5,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: photoUrl.isEmpty
                        ? Icon(Icons.pets, size: 42, color: theme.primaryColor)
                        : Image.network(
                            photoUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Icon(
                              Icons.pets,
                              size: 42,
                              color: theme.primaryColor,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: theme.textColor,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 6,
                  runSpacing: 6,
                  children: <Widget>[
                    if (gender.isNotEmpty) _chip(gender),
                    if (age.isNotEmpty) _chip(age),
                    if (breed.isNotEmpty) _chip(breed),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                IconButton(
                  tooltip: '編輯',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => showEditPetSheet(
                    context: context,
                    pet: pet,
                    theme: theme,
                    isAdminView: isAdminView,
                  ),
                  icon: Icon(Icons.edit_outlined, color: theme.textColor),
                ),
                if (!isAdminView)
                  IconButton(
                    tooltip: '刪除',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _confirmDelete(context),
                    icon: Icon(
                      Icons.delete_outline,
                      color: Colors.red.shade600,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: theme.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: theme.primaryColor,
        ),
      ),
    );
  }

  Widget _sectionCard({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.cardBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 18, color: theme.primaryColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: theme.textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    final bool empty = value.trim().isEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            icon,
            size: 18,
            color: theme.primaryColor.withValues(alpha: 0.8),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: theme.textColor.withValues(alpha: 0.55),
              ),
            ),
          ),
          Expanded(
            child: Text(
              empty ? '尚未填寫' : value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: empty
                    ? theme.textColor.withValues(alpha: 0.35)
                    : theme.textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _notesCard(String note) {
    final bool empty = note.isEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.cardBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.notes_outlined, size: 18, color: theme.primaryColor),
              const SizedBox(width: 8),
              Text(
                '其他備註',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: theme.textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            empty ? '尚無其他備註' : note,
            style: TextStyle(
              fontSize: empty ? 12 : 14,
              height: 1.4,
              color: empty
                  ? theme.textColor.withValues(alpha: 0.45)
                  : theme.textColor,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('刪除寵物'),
          content: const Text('確定刪除此寵物資料？刪除後無法復原。'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('刪除'),
            ),
          ],
        );
      },
    );
    if (confirmed == true && context.mounted) {
      await _deletePet(context);
    }
  }

  Future<void> _deletePet(BuildContext context) async {
    final String uid =
        (pet['userId'] ?? FirebaseAuth.instance.currentUser?.uid ?? '')
            .toString();
    final String petId = (pet['petId'] ?? '').toString();
    final String photoUrl = (pet['photoUrl'] ?? '').toString();
    if (photoUrl.isNotEmpty) {
      try {
        await FirebaseStorage.instance.refFromURL(photoUrl).delete();
      } catch (_) {}
    }
    await FirebaseFirestore.instance
        .collection('user_profiles')
        .doc(uid)
        .collection('pets')
        .doc(petId)
        .delete();
    if (context.mounted) {
      Navigator.pop(context);
    }
  }
}

class _FullImagePage extends StatelessWidget {
  const _FullImagePage({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Center(child: InteractiveViewer(child: Image.network(imageUrl))),
      ),
    );
  }
}
