// 檔案名稱：lib/core/services/booking_pet_care_form_loader.dart
// 功能說明：依訂單寵物批次讀取店家照護表單（子集合＋會員寵物＋舊 nested），避免每隻寵物獨立 Stream。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:petnest_saas/core/models/custom_form_answer_model.dart';
import 'package:petnest_saas/core/models/pet_snapshot.dart';
import 'package:petnest_saas/core/services/pet_shop_form_answers.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_pet_card.dart';

class BookingPetCareFormItem {
  const BookingPetCareFormItem({
    required this.petId,
    required this.name,
    required this.photoUrl,
    required this.raw,
    required this.filledCount,
  });

  final String petId;
  final String name;
  final String photoUrl;
  final Map<String, dynamic> raw;
  final int filledCount;
}

class BookingPetCareFormLoader {
  BookingPetCareFormLoader._();

  static final Map<String, Future<List<BookingPetCareFormItem>>> _inFlight =
      <String, Future<List<BookingPetCareFormItem>>>{};

  static Future<List<BookingPetCareFormItem>> load({
    required String shopId,
    required String userId,
    required List<Map<String, dynamic>> pets,
    String bookingId = '',
  }) {
    final String key =
        '${shopId.trim()}|${userId.trim()}|${bookingId.trim()}|${pets.map(PetShopFormAnswers.petIdOf).join(',')}';
    final Future<List<BookingPetCareFormItem>>? existing = _inFlight[key];
    if (existing != null) {
      return existing;
    }
    final Future<List<BookingPetCareFormItem>> run = () async {
      try {
        final List<BookingPetCareFormItem> items = await _loadOnce(
          shopId: shopId,
          userId: userId,
          pets: pets,
        );
        if (items.isEmpty) {
          _inFlight.remove(key);
        }
        return items;
      } catch (_) {
        _inFlight.remove(key);
        rethrow;
      }
    }();
    _inFlight[key] = run;
    return run;
  }

  static Future<List<BookingPetCareFormItem>> _loadOnce({
    required String shopId,
    required String userId,
    required List<Map<String, dynamic>> pets,
  }) async {
    final String sid = shopId.trim();
    final String uid = userId.trim();
    final Map<String, Map<String, dynamic>> memberPets =
        <String, Map<String, dynamic>>{};
    if (sid.isNotEmpty && uid.isNotEmpty) {
      final QuerySnapshot<Map<String, dynamic>> memberSnap =
          await FirebaseFirestore.instance
              .collection('shops')
              .doc(sid)
              .collection('members')
              .doc(uid)
              .collection('pets')
              .get();
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in memberSnap.docs) {
        memberPets[doc.id] = doc.data();
      }
    }

    final List<String> fetchIds = <String>[];
    final List<Map<String, dynamic>?> members = <Map<String, dynamic>?>[];
    for (final Map<String, dynamic> pet in pets) {
      String petId = PetShopFormAnswers.petIdOf(pet);
      Map<String, dynamic>? member = memberPets[petId];
      if (member == null) {
        final String name = (pet['name'] ?? pet['petName'] ?? '')
            .toString()
            .trim();
        if (name.isNotEmpty) {
          for (final MapEntry<String, Map<String, dynamic>> entry
              in memberPets.entries) {
            if ((entry.value['name'] ?? '').toString().trim() == name) {
              member = entry.value;
              if (petId.isEmpty) {
                petId = entry.key;
              }
              break;
            }
          }
        }
      }
      members.add(member);
      if (uid.isNotEmpty && sid.isNotEmpty && petId.isNotEmpty) {
        fetchIds.add(petId);
      } else {
        fetchIds.add('');
      }
    }

    final List<DocumentSnapshot<Map<String, dynamic>>> extra;
    final List<String> need = fetchIds
        .where((String id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (need.isNotEmpty) {
      extra = await Future.wait(
        need.expand((String petId) {
          final DocumentReference<Map<String, dynamic>> petRef =
              FirebaseFirestore.instance
                  .collection('user_profiles')
                  .doc(uid)
                  .collection('pets')
                  .doc(petId);
          return <Future<DocumentSnapshot<Map<String, dynamic>>>>[
            petRef.get(),
            petRef.collection(PetShopFormAnswers.collectionName).doc(sid).get(),
          ];
        }),
      );
    } else {
      extra = const <DocumentSnapshot<Map<String, dynamic>>>[];
    }

    final Map<String, Map<String, dynamic>?> profilePets =
        <String, Map<String, dynamic>?>{};
    final Map<String, Map<String, dynamic>?> subs =
        <String, Map<String, dynamic>?>{};
    for (int i = 0; i < need.length; i++) {
      profilePets[need[i]] = extra[i * 2].data();
      subs[need[i]] = extra[i * 2 + 1].data();
    }

    final List<BookingPetCareFormItem> out = <BookingPetCareFormItem>[];
    for (int i = 0; i < pets.length; i++) {
      final Map<String, dynamic> pet = pets[i];
      String petId = PetShopFormAnswers.petIdOf(pet);
      if (petId.isEmpty) {
        petId = fetchIds[i];
      }
      final Map<String, dynamic>? member = members[i];
      final Map<String, dynamic>? resolved =
          AdminBookingPetCard.resolveShopCareForm(
            shopId: sid,
            pet: pet,
            fallback: member ?? profilePets[petId],
            subcollectionData: subs[petId],
          );
      if (_filled(resolved) <= 0) {
        continue;
      }
      out.add(
        _item(
          pet: pet,
          petId: petId,
          fallback: member ?? profilePets[petId],
          raw: resolved!,
        ),
      );
    }
    return out;
  }

  static int _filled(Map<String, dynamic>? raw) {
    return CustomFormAnswerSnapshot.tryParse(raw)?.filledCount ?? 0;
  }

  static BookingPetCareFormItem _item({
    required Map<String, dynamic> pet,
    required String petId,
    Map<String, dynamic>? fallback,
    required Map<String, dynamic> raw,
  }) {
    final Map<String, dynamic> merged = PetSnapshot.merge(
      snapshot: pet,
      fallback: fallback,
    );
    final String name = (merged['name'] ?? pet['name'] ?? pet['petName'] ?? '')
        .toString()
        .trim();
    return BookingPetCareFormItem(
      petId: petId,
      name: name.isEmpty ? '未命名寵物' : name,
      photoUrl: (merged['photoUrl'] ?? merged['imageUrl'] ?? '').toString(),
      raw: raw,
      filledCount: _filled(raw),
    );
  }
}
