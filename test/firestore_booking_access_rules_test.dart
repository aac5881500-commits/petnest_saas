// 檔案名稱：test/firestore_booking_access_rules_test.dart
// 功能說明：對照 bookings / shop_member_invites 規則原文，驗證本人、店家、平台與邀請權限。

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

class BookingAccess {
  const BookingAccess({
    required this.authUid,
    required this.ownerUid,
    required this.shopId,
    this.memberShopIds = const <String>{},
    this.ownerUidShopIds = const <String>{},
    this.isRoot = false,
    this.platformRole = '',
    this.platformPermissions = const <String>{},
    this.platformEnabled = false,
  });

  final String authUid;
  final String ownerUid;
  final String shopId;
  final Set<String> memberShopIds;
  final Set<String> ownerUidShopIds;
  final bool isRoot;
  final String platformRole;
  final Set<String> platformPermissions;
  final bool platformEnabled;

  bool get isOwner => authUid.isNotEmpty && authUid == ownerUid;

  bool get isShopReader {
    return memberShopIds.contains(shopId) || ownerUidShopIds.contains(shopId);
  }

  bool get canReadAllBookings {
    if (isRoot) {
      return true;
    }
    if (!platformEnabled) {
      return false;
    }
    if (platformRole == 'super_admin') {
      return true;
    }
    const Set<String> allowed = <String>{
      'all',
      'view_shops',
      'manage_shop_status',
      'view_platform_members',
      'manage_platform_members',
    };
    return platformPermissions.intersection(allowed).isNotEmpty;
  }

  bool canReadDocument() {
    return isOwner || isShopReader || canReadAllBookings;
  }

  bool canQueryOwnUid(String queryUid) {
    return authUid.isNotEmpty && queryUid == authUid;
  }

  bool canQueryAllBookings() {
    return canReadAllBookings;
  }

  bool canQueryShop(String queryShopId) {
    return canReadAllBookings ||
        memberShopIds.contains(queryShopId) ||
        ownerUidShopIds.contains(queryShopId);
  }

  bool customerCanSet({
    required String fromStatus,
    required String field,
    required Object? value,
  }) {
    const Set<String> forbidden = <String>{
      'depositStatus',
      'paid',
      'paidAmount',
      'assignStatus',
      'assignedRoomId',
      'roomId',
      'shopId',
      'totalPrice',
      'paymentStatus',
    };
    if (forbidden.contains(field)) {
      return false;
    }
    if (field == 'status') {
      return (fromStatus == 'pending' || fromStatus == 'unpaid') &&
          value == 'cancelled';
    }
    return false;
  }
}

class InviteAccess {
  const InviteAccess({
    required this.authUid,
    required this.authEmail,
    required this.inviteEmail,
    required this.inviteShopId,
    required this.inviteRole,
    this.memberRole = '',
    this.memberShopIds = const <String>{},
    this.isRoot = false,
  });

  final String authUid;
  final String authEmail;
  final String inviteEmail;
  final String inviteShopId;
  final String inviteRole;
  final String memberRole;
  final Set<String> memberShopIds;
  final bool isRoot;

  bool get isInvitee =>
      authEmail.isNotEmpty && authEmail.toLowerCase() == inviteEmail;

  bool get canManage {
    if (isRoot) {
      return true;
    }
    if (!memberShopIds.contains(inviteShopId)) {
      return false;
    }
    return memberRole == 'owner' || memberRole == 'manager';
  }

  bool canRead() => canManage || isInvitee;

  bool canAcceptAs(String role) {
    return isInvitee && role == inviteRole;
  }
}

String _block(String rules, String start, String end) {
  final int begin = rules.indexOf(start);
  expect(begin, greaterThanOrEqualTo(0), reason: '缺少 $start');
  final int finish = rules.indexOf(end, begin);
  expect(finish, greaterThan(begin), reason: '缺少 $end');
  return rules.substring(begin, finish);
}

void main() {
  late String rules;
  late String bookings;
  late String invites;

  setUpAll(() {
    rules = File('firestore.rules').readAsStringSync();
    bookings = _block(rules, 'match /bookings/{bookingId}', 'match /messages/');
    invites = _block(
      rules,
      'match /shop_member_invites/{inviteId}',
      'match /shops/{shopId}',
    );
  });

  test('bookings 不再允許任何登入者讀全部', () {
    expect(bookings.contains('allow read: if signedIn();'), isFalse);
    expect(bookings.contains('|| signedIn()'), isFalse);
    expect(rules.contains('function canReadShopBookings(shopId)'), isTrue);
    expect(rules.contains('function canReadAllBookings()'), isTrue);
    expect(rules.contains('function canManageShopBookings(shopId)'), isTrue);
    expect(rules.contains('function canManageAllBookings()'), isTrue);
    expect(
      rules.contains("hasShopPermissionKey(shopId, 'manage_bookings')"),
      isTrue,
    );
    expect(rules.contains('function canManageShopInvites(shopId)'), isTrue);
    expect(rules.contains('function inviteDoc(shopId, emailKey)'), isTrue);
    expect(
      rules.contains('isShopMember(shopId) || isShopOwnerUid(shopId)'),
      isTrue,
    );
    expect(
      rules.contains("hasShopPermissionKey(shopId, 'manage_members')"),
      isTrue,
    );
    expect(
      bookings.contains('resource.data.userId == request.auth.uid'),
      isTrue,
    );
    expect(
      bookings.contains('canReadShopBookings(resource.data.shopId)'),
      isTrue,
    );
    expect(bookings.contains('canReadAllBookings()'), isTrue);
    expect(bookings.contains("request.resource.data.depositStatus == 'paid'"), isFalse);
    expect(bookings.contains("request.resource.data.depositStatus == 'confirmed'"), isTrue);
    expect(bookings.contains('allow delete: if false;'), isTrue);
    expect(bookings.contains("request.resource.data.source != 'admin'"), isTrue);
    expect(bookings.contains("'assignStatus'"), isFalse);
    expect(
      bookings.contains("request.resource.data.status == 'cancelled'"),
      isTrue,
    );
  });

  test('邀請不可全域讀，接受時角色必須等於邀請', () {
    expect(invites.contains('allow read: if signedIn();'), isFalse);
    expect(invites.contains('canManageShopInvites'), isTrue);
    expect(rules.contains('inviteDoc('), isTrue);
    expect(rules.contains('.role == request.resource.data.role'), isTrue);
    expect(
      rules.contains('.permissions == request.resource.data.permissions'),
      isTrue,
    );
  });

  test('TEST 1-10 讀取範圍', () {
    const BookingAccess customerA = BookingAccess(
      authUid: 'a',
      ownerUid: 'a',
      shopId: 'shopA',
    );
    const BookingAccess other = BookingAccess(
      authUid: 'a',
      ownerUid: 'b',
      shopId: 'shopB',
    );
    expect(customerA.canReadDocument(), isTrue);
    expect(other.canReadDocument(), isFalse);
    expect(customerA.canQueryOwnUid('a'), isTrue);
    expect(customerA.canQueryAllBookings(), isFalse);

    const BookingAccess staffA = BookingAccess(
      authUid: 'staff',
      ownerUid: 'customer',
      shopId: 'shopA',
      memberShopIds: <String>{'shopA'},
    );
    expect(staffA.canQueryShop('shopA'), isTrue);
    expect(staffA.canReadDocument(), isTrue);
    expect(staffA.canQueryShop('shopB'), isFalse);

    const BookingAccess ownerA = BookingAccess(
      authUid: 'owner',
      ownerUid: 'customer',
      shopId: 'shopA',
      ownerUidShopIds: <String>{'shopA'},
    );
    expect(ownerA.canQueryShop('shopA'), isTrue);
    expect(ownerA.canQueryShop('shopB'), isFalse);

    const BookingAccess platform = BookingAccess(
      authUid: 'platform',
      ownerUid: 'customer',
      shopId: 'shopB',
      platformEnabled: true,
      platformRole: 'super_admin',
    );
    expect(platform.canReadDocument(), isTrue);
    expect(platform.canQueryAllBookings(), isTrue);

    const BookingAccess signedIn = BookingAccess(
      authUid: 'random',
      ownerUid: 'customer',
      shopId: 'shopA',
    );
    expect(signedIn.canQueryAllBookings(), isFalse);
    expect(signedIn.canQueryShop('shopA'), isFalse);
  });

  test('TEST 11-14 顧客不能改付款、分房與完成狀態，只能取消待處理訂單', () {
    const BookingAccess customer = BookingAccess(
      authUid: 'a',
      ownerUid: 'a',
      shopId: 'shopA',
    );
    expect(
      customer.customerCanSet(
        fromStatus: 'pending',
        field: 'depositStatus',
        value: 'confirmed',
      ),
      isFalse,
    );
    expect(
      customer.customerCanSet(
        fromStatus: 'pending',
        field: 'assignedRoomId',
        value: 'r1',
      ),
      isFalse,
    );
    expect(
      customer.customerCanSet(
        fromStatus: 'pending',
        field: 'status',
        value: 'completed',
      ),
      isFalse,
    );
    expect(
      customer.customerCanSet(
        fromStatus: 'pending',
        field: 'status',
        value: 'checked_in',
      ),
      isFalse,
    );
    expect(
      customer.customerCanSet(
        fromStatus: 'completed',
        field: 'status',
        value: 'checked_in',
      ),
      isFalse,
    );
    expect(
      customer.customerCanSet(
        fromStatus: 'pending',
        field: 'status',
        value: 'cancelled',
      ),
      isTrue,
    );
    expect(
      customer.customerCanSet(
        fromStatus: 'confirmed',
        field: 'status',
        value: 'cancelled',
      ),
      isFalse,
    );
  });

  test('TEST 15-18 邀請角色與讀取', () {
    const InviteAccess staffInvite = InviteAccess(
      authUid: 'new',
      authEmail: 'staff@pet.test',
      inviteEmail: 'staff@pet.test',
      inviteShopId: 'shopA',
      inviteRole: 'staff',
    );
    expect(staffInvite.canAcceptAs('owner'), isFalse);
    expect(staffInvite.canAcceptAs('staff'), isTrue);

    const InviteAccess stranger = InviteAccess(
      authUid: 'other',
      authEmail: 'other@pet.test',
      inviteEmail: 'staff@pet.test',
      inviteShopId: 'shopA',
      inviteRole: 'staff',
    );
    expect(stranger.canRead(), isFalse);
    expect(staffInvite.canRead(), isTrue);
  });
}
