// 檔案名稱：lib/features/admin/widgets/admin_booking_pet_card.dart
// 功能說明：訂單寵物摘要卡：只顯示有值欄位，可展開詳細與該店照護表單

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/custom_form_answer_model.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/pet_snapshot.dart';
import 'package:petnest_saas/core/widgets/member_avatar.dart';
import 'package:petnest_saas/core/models/shop_frontend_theme.dart';
import 'package:petnest_saas/core/services/pet_shop_form_answers.dart';
import 'package:petnest_saas/features/custom_form/widgets/custom_form_answer_view.dart';

class AdminBookingPetCard extends StatelessWidget {
  const AdminBookingPetCard({
    super.key,
    required this.pet,
    this.fallback,
    this.shopId = '',
    this.userId = '',
    this.compact = false,
  });

  final Map<String, dynamic> pet;
  final Map<String, dynamic>? fallback;
  final String shopId;
  final String userId;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> merged = PetSnapshot.merge(
      snapshot: pet,
      fallback: fallback,
    );
    final String name = (merged['name'] ?? '').toString().trim();
    final String photoUrl = (merged['photoUrl'] ?? merged['imageUrl'] ?? '')
        .toString();
    final List<MapEntry<String, String>> rows = PetSnapshot.visibleRows(merged);
    final List<MapEntry<String, String>> safety = PetSnapshot.safetyRows(
      merged,
    );
    final Map<String, dynamic>? formRaw = PetShopFormAnswers.resolve(
      shopId: shopId,
      subcollectionData: merged['shopFormAnswers'] is Map
          ? Map<String, dynamic>.from(merged['shopFormAnswers'] as Map)
          : (pet['shopFormAnswers'] is Map
                ? Map<String, dynamic>.from(pet['shopFormAnswers'] as Map)
                : (fallback != null && fallback!['shopFormAnswers'] is Map
                      ? Map<String, dynamic>.from(
                          fallback!['shopFormAnswers'] as Map,
                        )
                      : null)),
      petData: fallback ?? pet,
    );
    final CustomFormAnswerSnapshot? form = CustomFormAnswerSnapshot.tryParse(
      formRaw,
    );
    final int filled = form == null
        ? 0
        : form.answers
              .where(
                (CustomFormAnswerItem item) =>
                    item.displayValue.trim().isNotEmpty,
              )
              .length;
    final String summary = rows
        .take(3)
        .map((MapEntry<String, String> e) => e.value)
        .where((String e) => e.isNotEmpty)
        .join('・');

    final Color accent = ShopFrontendTheme.of(context).primaryColor;
    final String breed = (merged['breed'] ?? '').toString().trim();
    final String gender = (merged['gender'] ?? '').toString().trim();
    final String type = (merged['species'] ?? merged['type'] ?? '')
        .toString()
        .trim();

    if (compact) {
      return Material(
        color: Color.alphaBlend(accent.withValues(alpha: 0.06), Colors.white),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openDetail(
            context,
            name: name,
            photoUrl: photoUrl,
            rows: rows,
            safety: safety,
            formRaw: formRaw,
            petId: (merged['petId'] ?? pet['petId'] ?? pet['id'] ?? '')
                .toString(),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: <Widget>[
                _petPhoto(photoUrl, name),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        name.isEmpty ? '未命名寵物' : name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      if (summary.isNotEmpty)
                        Text(
                          summary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: <Widget>[
                          if (gender.isNotEmpty) _petChip(gender, accent),
                          if (breed.isNotEmpty) _petChip(breed, accent),
                          for (final MapEntry<String, String> row
                              in safety.take(2))
                            _petChip(row.key, Colors.red),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      color: Color.alphaBlend(accent.withValues(alpha: 0.06), Colors.white),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        leading: _petPhoto(photoUrl, name),
        title: Text(
          name.isEmpty ? '未命名寵物' : name,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (summary.isNotEmpty)
              Text(summary, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: <Widget>[
                if (type.isNotEmpty) _petChip(type, accent),
                if (breed.isNotEmpty) _petChip(breed, accent),
                if (gender.isNotEmpty) _petChip(gender, accent),
                for (final MapEntry<String, String> row in safety.take(3))
                  _petChip(row.key, Colors.red),
              ],
            ),
          ],
        ),
        children: <Widget>[
          if (rows.isEmpty && safety.isEmpty)
            const Text('此訂單沒有足夠的寵物欄位，且找不到會員寵物快取。'),
          for (final MapEntry<String, String> row in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(
                    width: 72,
                    child: Text(
                      row.key,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Expanded(child: Text(row.value)),
                ],
              ),
            ),
          if (safety.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    '安全資訊',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  for (final MapEntry<String, String> row in safety)
                    Text('${row.key}：${row.value}'),
                ],
              ),
            ),
          ],
          if (form != null && filled > 0)
            CustomFormAnswerView(
              raw: formRaw,
              title: '店家照護資料・已填 $filled 題',
              theme: HomeThemeModel.classicDefault,
              collapsible: true,
            ),
        ],
      ),
    );
  }

  Future<void> _openDetail(
    BuildContext context, {
    required String name,
    required String photoUrl,
    required List<MapEntry<String, String>> rows,
    required List<MapEntry<String, String>> safety,
    required Map<String, dynamic>? formRaw,
    required String petId,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext context) {
        Widget formView(Map<String, dynamic>? raw) {
          final CustomFormAnswerSnapshot? parsed =
              CustomFormAnswerSnapshot.tryParse(raw);
          final int count = parsed == null
              ? 0
              : parsed.answers
                    .where(
                      (CustomFormAnswerItem item) =>
                          item.displayValue.trim().isNotEmpty,
                    )
                    .length;
          if (raw == null || count <= 0) {
            return const SizedBox.shrink();
          }
          return CustomFormAnswerView(
            raw: raw,
            title: '店家照護資料／寵物自訂表單',
            theme: HomeThemeModel.classicDefault,
            collapsible: false,
            initiallyExpanded: true,
          );
        }

        final String uid = userId.trim();
        final String sid = shopId.trim();
        final String pid = petId.trim();
        final Widget formBlock =
            uid.isNotEmpty && sid.isNotEmpty && pid.isNotEmpty
            ? StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('user_profiles')
                    .doc(uid)
                    .collection('pets')
                    .doc(pid)
                    .collection('shop_form_answers')
                    .doc(sid)
                    .snapshots(),
                builder:
                    (
                      BuildContext context,
                      AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>>
                      snap,
                    ) {
                      final Map<String, dynamic>? live = snap.data?.data();
                      return formView(
                        PetShopFormAnswers.resolve(
                              shopId: sid,
                              subcollectionData: live,
                              petData: fallback ?? pet,
                            ) ??
                            formRaw,
                      );
                    },
              )
            : formView(formRaw);

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    _petPhoto(photoUrl, name),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        name.isEmpty ? '未命名寵物' : name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  '寵物基本資料',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                if (rows.isEmpty && safety.isEmpty)
                  const Text('此訂單沒有足夠的寵物欄位，且找不到會員寵物快取。'),
                for (final MapEntry<String, String> row in rows)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        SizedBox(
                          width: 72,
                          child: Text(
                            row.key,
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Expanded(child: Text(row.value)),
                      ],
                    ),
                  ),
                if (safety.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          '安全資訊',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        for (final MapEntry<String, String> row in safety)
                          Text('${row.key}：${row.value}'),
                      ],
                    ),
                  ),
                ],
                formBlock,
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _petPhoto(String photoUrl, String name) {
    final Color wash = MemberAvatarSource.colorFor(name);
    return ClipOval(
      child: SizedBox(
        width: 44,
        height: 44,
        child: photoUrl.trim().isEmpty
            ? ColoredBox(
                color: wash,
                child: const Icon(Icons.pets, color: Color(0xFF5C4033)),
              )
            : Image.network(
                photoUrl,
                fit: BoxFit.cover,
                cacheWidth: 132,
                cacheHeight: 132,
                errorBuilder:
                    (BuildContext context, Object error, StackTrace? stack) {
                      return ColoredBox(
                        color: wash,
                        child: const Icon(Icons.pets, color: Color(0xFF5C4033)),
                      );
                    },
              ),
      ),
    );
  }

  Widget _petChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
