// 檔案名稱：test/firestore_shop_form_answers_rules_test.dart
// 功能說明：寵物店家表單答案子集合的 Firestore Rules 權限矩陣與規則原文檢查。

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

class ShopFormAnswersAccess {
  const ShopFormAnswersAccess({
    this.authUid,
    required this.petOwnerUid,
    required this.answerShopId,
    this.documentShopId,
    this.memberOfShops = const <String>{},
    this.isRootAdmin = false,
  });

  final String? authUid;
  final String petOwnerUid;
  final String answerShopId;
  final String? documentShopId;
  final Set<String> memberOfShops;
  final bool isRootAdmin;

  bool get signedIn => authUid != null && authUid!.isNotEmpty;

  bool get isSelf => signedIn && authUid == petOwnerUid;

  bool canRead() {
    if (isSelf || isRootAdmin) {
      return true;
    }
    if (!signedIn || answerShopId.isEmpty) {
      return false;
    }
    if ((documentShopId ?? answerShopId) != answerShopId) {
      return false;
    }
    return memberOfShops.contains(answerShopId);
  }

  bool canWrite() {
    return isSelf &&
        answerShopId.isNotEmpty &&
        (documentShopId ?? answerShopId) == answerShopId;
  }
}

String _shopFormAnswersRulesBlock(String rules) {
  const String start = 'match /shop_form_answers/{answerShopId} {';
  final int begin = rules.indexOf(start);
  expect(begin, greaterThanOrEqualTo(0), reason: '缺少 shop_form_answers 規則');
  final int petsMatch = rules.lastIndexOf('match /pets/{petId}', begin);
  expect(petsMatch, greaterThanOrEqualTo(0), reason: '子集合必須寫在 pets 規則內');
  final int end = rules.indexOf('allow delete: if isSelf(uid);', begin);
  expect(end, greaterThan(begin));
  return rules.substring(begin, end + 'allow delete: if isSelf(uid);'.length);
}

void main() {
  late String rules;
  late String block;

  setUpAll(() {
    rules = File('firestore.rules').readAsStringSync();
    block = _shopFormAnswersRulesBlock(rules);
  });

  test('規則不可開放整個 collection', () {
    expect(block.contains('allow read, write: if true'), isFalse);
    expect(block.contains('allow write: if true'), isFalse);
  });

  test('規則原文：主人可讀寫、店家只能讀對應 shopId、管理員可讀、店家不可改答案', () {
    expect(block.contains('isSelf(uid)'), isTrue);
    expect(block.contains('isRootAdmin()'), isTrue);
    expect(block.contains('isShopMember(answerShopId)'), isTrue);
    expect(block.contains('resource.data.shopId == answerShopId'), isTrue);
    expect(
      block.contains('request.resource.data.shopId == answerShopId'),
      isTrue,
    );
    expect(block.contains('allow create, update: if'), isTrue);
    expect(block.contains('isShopMember(answerShopId)'), isTrue);
    expect(
      RegExp(r'allow create, update: if[\s\S]*isShopMember').hasMatch(block),
      isFalse,
      reason: '店家不可修改會員答案',
    );
  });

  test('主人可以讀寫', () {
    const ShopFormAnswersAccess access = ShopFormAnswersAccess(
      authUid: 'owner-1',
      petOwnerUid: 'owner-1',
      answerShopId: 'shop-a',
    );
    expect(access.canRead(), isTrue);
    expect(access.canWrite(), isTrue);
  });

  test('A 店可以讀 A 店答案', () {
    const ShopFormAnswersAccess access = ShopFormAnswersAccess(
      authUid: 'staff-a',
      petOwnerUid: 'owner-1',
      answerShopId: 'shop-a',
      memberOfShops: <String>{'shop-a'},
    );
    expect(access.canRead(), isTrue);
    expect(access.canWrite(), isFalse);
  });

  test('A 店不能讀 B 店答案', () {
    const ShopFormAnswersAccess access = ShopFormAnswersAccess(
      authUid: 'staff-a',
      petOwnerUid: 'owner-1',
      answerShopId: 'shop-b',
      memberOfShops: <String>{'shop-a'},
    );
    expect(access.canRead(), isFalse);
    expect(access.canWrite(), isFalse);
  });

  test('未登入不能讀', () {
    const ShopFormAnswersAccess access = ShopFormAnswersAccess(
      petOwnerUid: 'owner-1',
      answerShopId: 'shop-a',
    );
    expect(access.canRead(), isFalse);
    expect(access.canWrite(), isFalse);
  });

  test('非本人不能寫', () {
    const ShopFormAnswersAccess access = ShopFormAnswersAccess(
      authUid: 'other-user',
      petOwnerUid: 'owner-1',
      answerShopId: 'shop-a',
    );
    expect(access.canWrite(), isFalse);
    expect(access.canRead(), isFalse);
  });
}
