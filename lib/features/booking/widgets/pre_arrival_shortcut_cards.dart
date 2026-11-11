import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/pre_arrival_guide_model.dart';
import 'package:petnest_saas/core/services/inspection_owner_context.dart';
import 'package:petnest_saas/core/services/pre_arrival_guide_service.dart';
import 'package:petnest_saas/features/booking/models/pre_arrival_shortcut.dart';
import 'package:petnest_saas/features/booking/pages/pre_arrival_guide_page.dart';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_detail_view_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PreArrivalShortcutCards extends StatelessWidget {
  const PreArrivalShortcutCards({
    super.key,
    required this.theme,
    required this.shopId,
    this.memberId,
  });

  final HomeThemeModel theme;
  final String shopId;

  /// Null on the storefront, where only explicitly pinned bookings are shown.
  final String? memberId;

  @override
  Widget build(BuildContext context) {
    if (InspectionOwnerContext.active) return const SizedBox.shrink();
    if (memberId != null) {
      return _BookingCards(
        key: ValueKey(memberId),
        userId: memberId!,
        theme: theme,
      );
    }
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (user == null || user.isAnonymous) return const SizedBox.shrink();
        return _BookingCards(
          key: ValueKey((user.uid, shopId)),
          userId: user.uid,
          storefrontShop: shopId,
          theme: theme,
        );
      },
    );
  }
}

class _BookingCards extends StatefulWidget {
  const _BookingCards({
    super.key,
    required this.userId,
    required this.theme,
    this.storefrontShop,
  });

  final String userId;
  final HomeThemeModel theme;
  final String? storefrontShop;

  @override
  State<_BookingCards> createState() => _BookingCardsState();
}

class _BookingCardsState extends State<_BookingCards> {
  late final _prefs = SharedPreferences.getInstance();
  Stream<QuerySnapshot<Map<String, dynamic>>>? _orders;
  final _guides = <String, Future<PreArrivalGuideModel>>{};
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(minutes: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: _prefs,
    builder: (context, snapshot) {
      final prefs = snapshot.data;
      if (prefs == null || widget.userId.isEmpty) {
        return const SizedBox.shrink();
      }
      final shop = widget.storefrontShop;
      return ValueListenableBuilder(
        valueListenable: PreArrivalShortcut.changes,
        builder: (context, _, child) {
          if (shop != null &&
              !prefs.getKeys().any(
                (key) =>
                    key.startsWith(
                      PreArrivalShortcut.shopPrefix(widget.userId, shop),
                    ) &&
                    prefs.getBool(key) == true,
              )) {
            return const SizedBox.shrink();
          }
          _orders ??= FirebaseFirestore.instance
              .collection('bookings')
              .where('userId', isEqualTo: widget.userId)
              .snapshots();
          return StreamBuilder(
            stream: _orders,
            builder: (context, snapshot) {
              if (snapshot.hasError || !snapshot.hasData) {
                return const SizedBox.shrink();
              }
              final views =
                  snapshot.data!.docs
                      .map(
                        (doc) => BookingDetailViewData.fromBooking(
                          data: doc.data(),
                          docId: doc.id,
                        ),
                      )
                      .where(
                        (view) =>
                            PreArrivalShortcut.eligible(view) &&
                            view.shopId.isNotEmpty,
                      )
                      .where(
                        (view) =>
                            shop == null ||
                            (view.shopId == shop &&
                                PreArrivalShortcut(
                                      widget.userId,
                                      view.shopId,
                                      view.docId,
                                    ).choice(prefs) ==
                                    true),
                      )
                      .toList()
                    ..sort((a, b) => a.startDate!.compareTo(b.startDate!));
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final view in views)
                    FutureBuilder(
                      key: ValueKey((view.shopId, view.docId)),
                      future: _guides.putIfAbsent(
                        view.shopId,
                        () => PreArrivalGuideService.instance.getCustomerGuide(
                          shopId: view.shopId,
                          serviceType: PreArrivalGuideServiceType.accommodation,
                        ),
                      ),
                      builder: (context, snapshot) {
                        final guide = snapshot.data;
                        if (guide == null || !guide.hasCustomerContent) {
                          return const SizedBox.shrink();
                        }
                        final shortcut = PreArrivalShortcut(
                          widget.userId,
                          view.shopId,
                          view.docId,
                        );
                        return _card(context, view, guide, shortcut, prefs);
                      },
                    ),
                ],
              );
            },
          );
        },
      );
    },
  );

  Widget _card(
    BuildContext context,
    BookingDetailViewData view,
    PreArrivalGuideModel guide,
    PreArrivalShortcut shortcut,
    SharedPreferences prefs,
  ) {
    final theme = widget.theme;
    final accent = theme.primaryColor;
    final items = guide.visibleBlocks.where(
      (block) => block.type == PreArrivalGuideBlockType.checklist,
    );
    final checked =
        (prefs.getStringList(
                  PreArrivalShortcut.progressKey(
                    shortcut.scope,
                    guide.serviceType,
                  ),
                ) ??
                const <String>[])
            .toSet();
    final done = items
        .where((block) => checked.contains(PreArrivalShortcut.itemKey(block)))
        .length;
    final storefront = widget.storefrontShop != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        storefront ? 14 : 0,
        storefront ? 10 : 0,
        storefront ? 14 : 0,
        12,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            accent.withValues(alpha: .09),
            theme.cardColor,
          ),
          border: Border.all(color: accent.withValues(alpha: .35)),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.luggage_outlined, color: accent, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      storefront ? '我的住宿' : '即將入住',
                      style: TextStyle(
                        color: theme.textColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (storefront)
                    PopupMenuButton<bool>(
                      tooltip: '首頁卡片選項',
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: true, child: Text('從首頁移除')),
                      ],
                      onSelected: (_) async {
                        if (!await shortcut.saveChoice(prefs, false) &&
                            context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('目前無法儲存首頁設定')),
                          );
                        }
                      },
                    ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          PreArrivalShortcut.countdown(
                            view.startDate!,
                            DateTime.now(),
                          ),
                          style: TextStyle(
                            color: theme.textColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                          ),
                        ),
                        if (!storefront && view.shopName.isNotEmpty)
                          Text(
                            view.shopName,
                            style: TextStyle(color: theme.textColor),
                          ),
                        Text(
                          PreArrivalShortcut.schedule(view),
                          style: TextStyle(color: theme.textColor),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Image.asset(
                    'assets/images/pre_arrival_packing_cat_v1.png',
                    width: 68,
                    height: 62,
                    fit: BoxFit.contain,
                    excludeFromSemantics: true,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: Wrap(
                  spacing: 14,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (items.isNotEmpty)
                      SizedBox(
                        width: 140,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '準備進度 $done / ${items.length}',
                              style: TextStyle(
                                color: theme.textColor,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 5),
                            LinearProgressIndicator(
                              value: done / items.length,
                              color: accent,
                              backgroundColor: accent.withValues(alpha: .17),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ],
                        ),
                      ),
                    FilledButton(
                      onPressed: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => PreArrivalGuidePage(
                              guide: guide,
                              progressScope: shortcut.scope,
                              backLabel: '返回',
                            ),
                          ),
                        );
                        if (mounted) setState(() {});
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor:
                            ThemeData.estimateBrightnessForColor(accent) ==
                                Brightness.dark
                            ? Colors.white
                            : Colors.black,
                      ),
                      child: const Text('繼續準備'),
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
}
