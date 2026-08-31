// lib/features/shop/widgets/modern_home/modern_staying_daily_care_section.dart
// 🐾 新版首頁「住宿中的寶貝」入口
// 功能：僅在會員於本店 checked_in，且店家啟用每日照護時顯示。
// 不掃整間店訂單，只用 shopId + userId 既有查詢。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../core/models/daily_care_setting_model.dart';
import '../../../../core/models/daily_care_stay_info.dart';
import '../../../../core/models/home_theme_model.dart';
import '../../../../core/services/daily_care_record_service.dart';
import '../../../../core/services/daily_care_setting_service.dart';
import '../../../booking/pages/customer_daily_care_page.dart';
import '../../../booking/pages/my_bookings_page.dart';

class ModernStayingDailyCareSection extends StatelessWidget {
  const ModernStayingDailyCareSection({
    super.key,
    required this.shopId,
    required this.theme,
    this.platformPreview = false,
  });

  final String shopId;
  final HomeThemeModel theme;
  final bool platformPreview;

  @override
  Widget build(BuildContext context) {
    if (platformPreview || shopId.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        final User? user = authSnapshot.data ?? FirebaseAuth.instance.currentUser;
        if (user == null) {
          return const SizedBox.shrink();
        }

        return StreamBuilder<DailyCareSettingModel>(
          stream: DailyCareSettingService.instance.streamSetting(shopId),
          builder: (context, settingSnapshot) {
            if (!settingSnapshot.hasData) {
              return const SizedBox.shrink();
            }

            final DailyCareSettingModel setting = settingSnapshot.data!;
            if (!setting.enabled) {
              return const SizedBox.shrink();
            }

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('bookings')
                  .where('shopId', isEqualTo: shopId)
                  .where('userId', isEqualTo: user.uid)
                  .orderBy('createdAt', descending: true)
                  .limit(15)
                  .snapshots(),
              builder: (context, bookingSnapshot) {
                if (!bookingSnapshot.hasData) {
                  return const SizedBox.shrink();
                }

                final List<QueryDocumentSnapshot<Map<String, dynamic>>>
                stayingDocs = bookingSnapshot.data!.docs.where((
                  QueryDocumentSnapshot<Map<String, dynamic>> doc,
                ) {
                  return (doc.data()['status'] ?? '').toString().trim() ==
                      'checked_in';
                }).toList();

                if (stayingDocs.isEmpty) {
                  return const SizedBox.shrink();
                }

                final int visibleCount = stayingDocs.length > 2
                    ? 2
                    : stayingDocs.length;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Icon(
                            Icons.pets_rounded,
                            size: 16,
                            color: theme.primaryColor,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '住宿中的寶貝',
                              style: TextStyle(
                                fontSize: 16,
                                height: 1.2,
                                fontWeight: FontWeight.w800,
                                color: theme.textColor,
                              ),
                            ),
                          ),
                          Text(
                            _todayLabel(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: theme.textColor.withValues(alpha: 0.55),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 9),
                      for (int index = 0; index < visibleCount; index++) ...<
                        Widget
                      >[
                        if (index > 0) const SizedBox(height: 8),
                        _StayingDailyCareCard(
                          shopId: shopId,
                          bookingId: stayingDocs[index].id,
                          data: stayingDocs[index].data(),
                          setting: setting,
                          theme: theme,
                          compact: stayingDocs.length > 1,
                        ),
                      ],
                      if (stayingDocs.length > 2) ...<Widget>[
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) => MyBookingsPage(
                                    returnShopId: shopId,
                                  ),
                                ),
                              );
                            },
                            child: Text(
                              '查看全部入住照護 >',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: theme.primaryColor,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  static String _todayLabel() {
    final DateTime now = DateTime.now();
    return '${now.month}/${now.day}';
  }
}

class _StayingDailyCareCard extends StatelessWidget {
  const _StayingDailyCareCard({
    required this.shopId,
    required this.bookingId,
    required this.data,
    required this.setting,
    required this.theme,
    required this.compact,
  });

  final String shopId;
  final String bookingId;
  final Map<String, dynamic> data;
  final DailyCareSettingModel setting;
  final HomeThemeModel theme;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final DailyCareStayInfo stay = DailyCareStayInfo.fromBookingMap(data);
    final String roomName = stay.roomName.trim().isEmpty
        ? '尚未分房'
        : stay.roomName.trim();
    final DateTime careDate = stay.currentCareDate();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openJournal(context, roomName),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(12, compact ? 10 : 12, 12, 10),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.cardBorderColor),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 7,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(Icons.pets, size: 16, color: theme.primaryColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '住宿中的寶貝',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: theme.textColor,
                      ),
                    ),
                  ),
                  Flexible(
                    child: Text(
                      roomName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: theme.primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _petRow(stay),
              const SizedBox(height: 10),
              Text(
                '今天的照護紀錄',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: theme.textColor.withValues(alpha: 0.72),
                ),
              ),
              const SizedBox(height: 6),
              StreamBuilder<Set<int>>(
                stream: DailyCareRecordService.instance
                    .streamFilledSessionIndexes(
                      bookingId: bookingId,
                      recordDate: careDate,
                      sessionCount: setting.sessionCount,
                    ),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const SizedBox(height: 22);
                  }
                  final Set<int> filled = snapshot.data ?? const <int>{};

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (filled.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            '今天的照護尚未更新',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: theme.textColor.withValues(alpha: 0.62),
                            ),
                          ),
                        ),
                      ...List<Widget>.generate(setting.sessionCount, (
                        int index,
                      ) {
                      final bool done = filled.contains(index);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: <Widget>[
                            Icon(
                              _sessionIcon(index, setting.sessionLabel(index)),
                              size: 15,
                              color: done
                                  ? theme.primaryColor
                                  : theme.textColor.withValues(alpha: 0.40),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                setting.sessionLabel(index),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: theme.textColor,
                                ),
                              ),
                            ),
                            Text(
                              done ? '✓ 已更新' : '尚未更新',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: done
                                    ? const Color(0xFF2E7D32)
                                    : theme.textColor.withValues(alpha: 0.45),
                              ),
                            ),
                          ],
                        ),
                      );
                      }),
                    ],
                  );
                },
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '查看今日照護 →',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: theme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _petRow(DailyCareStayInfo stay) {
    final List<DailyCareStayPet> pets = stay.pets;
    final String names = _petNames(pets);

    return Row(
      children: <Widget>[
        _petAvatars(pets),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            names,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: theme.textColor,
            ),
          ),
        ),
      ],
    );
  }

  String _petNames(List<DailyCareStayPet> pets) {
    if (pets.isEmpty) {
      return '入住毛孩';
    }
    if (pets.length <= 3) {
      return pets.map((DailyCareStayPet pet) => pet.name).join('、');
    }
    return '${pets[0].name}、${pets[1].name} +${pets.length - 2}';
  }

  Widget _petAvatars(List<DailyCareStayPet> pets) {
    if (pets.isEmpty) {
      return _avatar(photoUrl: '', overlay: null);
    }

    final int visible = pets.length > 3 ? 3 : pets.length;
    final int extra = pets.length > 3 ? pets.length - 3 : 0;
    final double width = 28.0 + ((visible - 1) * 18);

    return SizedBox(
      width: width,
      height: 28,
      child: Stack(
        children: <Widget>[
          for (int index = 0; index < visible; index++)
            Positioned(
              left: index * 18,
              child: _avatar(
                photoUrl: pets[index].photoUrl,
                overlay: extra > 0 && index == visible - 1 ? '+$extra' : null,
              ),
            ),
        ],
      ),
    );
  }

  Widget _avatar({required String photoUrl, required String? overlay}) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFF1F3F6),
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (photoUrl.trim().isNotEmpty)
            Image.network(
              photoUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Icon(Icons.pets, size: 14, color: theme.primaryColor);
              },
            )
          else
            Icon(Icons.pets, size: 14, color: theme.primaryColor),
          if (overlay != null)
            ColoredBox(
              color: Colors.black.withValues(alpha: 0.45),
              child: Center(
                child: Text(
                  overlay,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  IconData _sessionIcon(int sessionIndex, String sessionName) {
    if (sessionName.contains('晚上') || sessionName.contains('晚間')) {
      return Icons.nightlight_outlined;
    }
    if (sessionName.contains('下午')) {
      return Icons.light_mode_outlined;
    }
    if (sessionName.contains('上午') || sessionName.contains('早安')) {
      return Icons.wb_sunny_outlined;
    }
    if (sessionIndex <= 0) {
      return Icons.wb_sunny_outlined;
    }
    if (sessionIndex == 1) {
      return Icons.light_mode_outlined;
    }
    return Icons.nightlight_outlined;
  }

  void _openJournal(BuildContext context, String roomName) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => CustomerDailyCarePage(
          shopId: shopId,
          bookingId: bookingId,
          roomName: roomName,
        ),
      ),
    );
  }
}
