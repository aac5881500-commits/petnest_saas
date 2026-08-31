// lib/core/widgets/member_avatar.dart
// 會員頭像顯示與來源優先順序：
// 1. PetNest 自訂大頭貼（user_profiles.avatarUrl）
// 2. Firebase Auth / Google photoURL
// 3. 系統人物 placeholder

import 'package:flutter/material.dart';

String? resolveMemberAvatarUrl({
  String? customAvatarUrl,
  String? authPhotoUrl,
}) {
  final String custom = (customAvatarUrl ?? '').trim();
  if (custom.isNotEmpty) {
    return custom;
  }

  final String auth = (authPhotoUrl ?? '').trim();
  if (auth.isNotEmpty) {
    return auth;
  }

  return null;
}

bool hasCustomMemberAvatar(String? customAvatarUrl) {
  return (customAvatarUrl ?? '').trim().isNotEmpty;
}

class MemberAvatar extends StatelessWidget {
  const MemberAvatar({
    super.key,
    this.imageUrl,
    this.size = 60,
    this.showCameraBadge = false,
    this.loading = false,
    this.onTap,
  });

  final String? imageUrl;
  final double size;
  final bool showCameraBadge;
  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final double badgeSize = size <= 48 ? 18 : 20;
    final double box = size + (showCameraBadge ? 4 : 0);

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
                decoration: const BoxDecoration(
                  color: Color(0xFFE8EEF6),
                  shape: BoxShape.circle,
                ),
                clipBehavior: Clip.antiAlias,
                child: _buildFace(),
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
                    color: const Color(0xFF6B8FBF),
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

  Widget _buildFace() {
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
      return Icon(
        Icons.person_rounded,
        color: const Color(0xFF6B8FBF),
        size: size * 0.48,
      );
    }

    return Image.network(
      url,
      width: size,
      height: size,
      fit: BoxFit.cover,
      alignment: Alignment.center,
      gaplessPlayback: true,
      loadingBuilder:
          (
            BuildContext context,
            Widget child,
            ImageChunkEvent? loadingProgress,
          ) {
            if (loadingProgress == null) {
              return child;
            }
            return const ColoredBox(color: Color(0xFFE8EEF6));
          },
      errorBuilder: (BuildContext context, Object error, StackTrace? stack) {
        return Icon(
          Icons.person_rounded,
          color: const Color(0xFF6B8FBF),
          size: size * 0.48,
        );
      },
    );
  }
}
