// 檔案名稱：lib/core/widgets/member_avatar.dart
// 功能說明：會員頭像解析與顯示（可快取、壞圖 fallback、姓名首字）
// 優先順序：
// 1. 會員上傳的 avatarUrl（user_profiles / 明確參數）
// 2. shops/{shopId}/members 快取的 avatarUrl
// 3. 訂單／舊快照欄位（僅當目前資料沒有 avatarUrl 鍵）
// 4. Firebase Auth photoURL
// 5. 姓名首字＋暖色圓底

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

String? resolveMemberAvatarUrl({
  String? customAvatarUrl,
  String? authPhotoUrl,
  Map<String, dynamic>? profile,
  Map<String, dynamic>? member,
  Map<String, dynamic>? booking,
}) {
  return MemberAvatarSource.resolveUrl(
    customAvatarUrl: customAvatarUrl,
    authPhotoUrl: authPhotoUrl,
    profile: profile,
    member: member,
    booking: booking,
  );
}

bool hasCustomMemberAvatar(String? customAvatarUrl) {
  return (customAvatarUrl ?? '').trim().isNotEmpty;
}

class MemberAvatarSource {
  MemberAvatarSource._();

  static const List<Color> warmInitialColors = <Color>[
    Color(0xFFE8A87C),
    Color(0xFFD4A574),
    Color(0xFFC97B63),
    Color(0xFFE0BBE4),
    Color(0xFFB5D5C5),
    Color(0xFFF2C6A0),
    Color(0xFFD9A5B3),
    Color(0xFFC9B896),
  ];

  static String? resolveUrl({
    String? customAvatarUrl,
    String? authPhotoUrl,
    Map<String, dynamic>? profile,
    Map<String, dynamic>? member,
    Map<String, dynamic>? booking,
  }) {
    final String explicit = (customAvatarUrl ?? '').trim();
    if (explicit.isNotEmpty) {
      return explicit;
    }

    final String? fromProfile = _fromCurrentAvatarDoc(profile);
    if (profile != null && profile.containsKey('avatarUrl')) {
      if (fromProfile != null && fromProfile.isNotEmpty) {
        return fromProfile;
      }
      return _nonEmpty(authPhotoUrl);
    }
    if (fromProfile != null && fromProfile.isNotEmpty) {
      return fromProfile;
    }

    final String? fromMember = _fromCurrentAvatarDoc(member);
    if (member != null && member.containsKey('avatarUrl')) {
      if (fromMember != null && fromMember.isNotEmpty) {
        return fromMember;
      }
      return _nonEmpty(authPhotoUrl);
    }
    if (fromMember != null && fromMember.isNotEmpty) {
      return fromMember;
    }

    final String fromBooking = _firstUrl(booking, const <String>[
      'customerAvatarUrl',
      'avatarUrl',
      'customerPhotoUrl',
      'photoUrl',
      'photoURL',
      'imageUrl',
    ]);
    if (fromBooking.isNotEmpty) {
      return fromBooking;
    }

    return _nonEmpty(authPhotoUrl);
  }

  static String initialOf(String name) {
    final String trimmed = name.trim();
    if (trimmed.isEmpty) {
      return '?';
    }
    return trimmed.characters.first.toUpperCase();
  }

  static Color colorFor(String seed) {
    if (seed.trim().isEmpty) {
      return warmInitialColors.first;
    }
    final int index = seed.hashCode.abs() % warmInitialColors.length;
    return warmInitialColors[index];
  }

  static String? _fromCurrentAvatarDoc(Map<String, dynamic>? data) {
    if (data == null) {
      return null;
    }
    return _firstUrl(data, const <String>['avatarUrl', 'photoUrl', 'photoURL']);
  }

  static String _firstUrl(Map<String, dynamic>? data, List<String> keys) {
    if (data == null) {
      return '';
    }
    for (final String key in keys) {
      final String value = (data[key] ?? '').toString().trim();
      if (value.isNotEmpty && value != 'null') {
        return value;
      }
    }
    return '';
  }

  static String? _nonEmpty(String? value) {
    final String text = (value ?? '').trim();
    return text.isEmpty ? null : text;
  }
}

class MemberAvatar extends StatelessWidget {
  const MemberAvatar({
    super.key,
    this.imageUrl,
    this.name = '',
    this.size = 60,
    this.showCameraBadge = false,
    this.loading = false,
    this.onTap,
  });

  final String? imageUrl;
  final String name;
  final double size;
  final bool showCameraBadge;
  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final double badgeSize = size <= 48 ? 18 : 20;
    final double box = size + (showCameraBadge ? 4 : 0);
    final Color wash = MemberAvatarSource.colorFor(name);

    return SizedBox(
      width: box,
      height: box,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              top: 0,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(color: wash, shape: BoxShape.circle),
                clipBehavior: Clip.antiAlias,
                child: _buildFace(wash),
              ),
            ),
            if (showCameraBadge)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: badgeSize,
                  height: badgeSize,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Icon(
                    Icons.photo_camera_rounded,
                    size: badgeSize * 0.55,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFace(Color wash) {
    if (loading) {
      return const Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2.2),
        ),
      );
    }

    final String url = (imageUrl ?? '').trim();
    if (url.isEmpty) {
      return _initials(wash);
    }

    final int cachePx = (size * 3).round().clamp(64, 512);
    return Image.network(
      url,
      width: size,
      height: size,
      fit: BoxFit.cover,
      alignment: Alignment.center,
      gaplessPlayback: true,
      cacheWidth: cachePx,
      cacheHeight: cachePx,
      loadingBuilder:
          (
            BuildContext context,
            Widget child,
            ImageChunkEvent? loadingProgress,
          ) {
            if (loadingProgress == null) {
              return child;
            }
            return ColoredBox(color: wash.withValues(alpha: 0.35));
          },
      errorBuilder: (BuildContext context, Object error, StackTrace? stack) {
        return _initials(wash);
      },
    );
  }

  Widget _initials(Color wash) {
    final String initial = MemberAvatarSource.initialOf(name);
    if (initial == '?' && name.trim().isEmpty) {
      return Icon(
        Icons.person_rounded,
        color: Color.lerp(wash, const Color(0xFF5C4033), 0.45),
        size: size * 0.48,
      );
    }
    return Center(
      child: Text(
        initial,
        style: TextStyle(
          color: const Color(0xFF5C4033),
          fontWeight: FontWeight.w800,
          fontSize: size * 0.42,
        ),
      ),
    );
  }
}

/// 後台用：以店家會員快取 Stream 顯示最新頭像（員工通常不能讀 user_profiles）。
class ShopMemberLiveAvatar extends StatelessWidget {
  const ShopMemberLiveAvatar({
    super.key,
    required this.shopId,
    required this.userId,
    this.name = '',
    this.size = 48,
    this.member,
    this.booking,
    this.profile,
    this.authPhotoUrl,
  });

  final String shopId;
  final String userId;
  final String name;
  final double size;
  final Map<String, dynamic>? member;
  final Map<String, dynamic>? booking;
  final Map<String, dynamic>? profile;
  final String? authPhotoUrl;

  @override
  Widget build(BuildContext context) {
    final String sid = shopId.trim();
    final String uid = userId.trim();
    if (sid.isEmpty || uid.isEmpty) {
      return MemberAvatar(
        imageUrl: MemberAvatarSource.resolveUrl(
          profile: profile,
          member: member,
          booking: booking,
          authPhotoUrl: authPhotoUrl,
        ),
        name: name,
        size: size,
      );
    }
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('shops')
          .doc(sid)
          .collection('members')
          .doc(uid)
          .snapshots(),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
          ) {
            final Map<String, dynamic>? live = snapshot.data?.data();
            return MemberAvatar(
              imageUrl: MemberAvatarSource.resolveUrl(
                profile: profile,
                member: live ?? member,
                booking: booking,
                authPhotoUrl: authPhotoUrl,
              ),
              name: name,
              size: size,
            );
          },
    );
  }
}
