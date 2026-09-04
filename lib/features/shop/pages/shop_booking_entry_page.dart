// lib/features/shop/pages/shop_booking_entry_page.dart
// 🐾 前台預約入口：貓咪旅店＋臨托同時開啟時，先選兩張大型服務卡片

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/daycare_settings_model.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/policy_applicable_service.dart';
import 'package:petnest_saas/core/services/booking_entry_card_service.dart';
import 'package:petnest_saas/core/services/daycare_settings_service.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/features/auth/pages/login_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_booking_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_daycare_booking_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_policy_view_page.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_entry_service_card.dart';

class ShopBookingEntryPage extends StatelessWidget {
  const ShopBookingEntryPage({
    super.key,
    required this.shopId,
    this.preSelectedRoomType,
    this.theme = HomeThemeModel.classicDefault,
    this.useModernDrawer = false,
    this.initialDaycare = false,
  });

  final String shopId;
  final Map<String, dynamic>? preSelectedRoomType;
  final HomeThemeModel theme;
  final bool useModernDrawer;
  final bool initialDaycare;

  /// 住宿條款只在進入住宿流程時要求，不擋「我要預約」入口卡片。
  static Future<bool> ensureAccommodationPolicy({
    required BuildContext context,
    required String shopId,
    required HomeThemeModel theme,
  }) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      await Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => LoginPage(redirectShopId: shopId),
        ),
      );
      if (!context.mounted) {
        return false;
      }
      user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return false;
      }
    }
    final bool hasAccepted = await ShopService.instance.hasAcceptedPolicy(
      shopId: shopId,
      userId: user.uid,
      serviceType: PolicyApplicableService.accommodation,
    );
    if (hasAccepted) {
      return true;
    }
    if (!context.mounted) {
      return false;
    }
    final bool? result = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => ShopPolicyViewPage(
          shopId: shopId,
          theme: theme,
          serviceType: PolicyApplicableService.accommodation,
        ),
      ),
    );
    return result == true;
  }

  static Future<void> openStayBooking({
    required BuildContext context,
    required String shopId,
    Map<String, dynamic>? preSelectedRoomType,
    HomeThemeModel theme = HomeThemeModel.classicDefault,
    bool useModernDrawer = false,
    bool replaceCurrent = false,
  }) async {
    final MaterialPageRoute<void> route = MaterialPageRoute<void>(
      builder: (_) => ShopBookingPage(
        shopId: shopId,
        preSelectedRoomType: preSelectedRoomType,
        theme: theme,
        useModernDrawer: useModernDrawer,
      ),
    );
    if (replaceCurrent) {
      await Navigator.pushReplacement(context, route);
      return;
    }
    await Navigator.push(context, route);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: ShopService.instance.streamShop(shopId),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<Map<String, dynamic>?> shopSnap,
          ) {
            return StreamBuilder<DaycareSettingsModel>(
              stream: DaycareSettingsService.instance.stream(shopId),
              builder:
                  (
                    BuildContext context,
                    AsyncSnapshot<DaycareSettingsModel> settingSnap,
                  ) {
                    if (!shopSnap.hasData || !settingSnap.hasData) {
                      return const Scaffold(
                        body: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final Map<String, dynamic> shop =
                        shopSnap.data ?? const <String, dynamic>{};
                    final DaycareSettingsModel settings = settingSnap.data!;
                    final bool daycareOn = DaycareSettingsService.instance
                        .isEnabledForShop(shop: shop, settings: settings);
                    if (!daycareOn) {
                      if (initialDaycare) {
                        return Scaffold(
                          appBar: AppBar(title: const Text('安親預約')),
                          body: const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                '此店家尚未開放安親',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 18),
                              ),
                            ),
                          ),
                        );
                      }
                      return _GatedStayBooking(
                        shopId: shopId,
                        preSelectedRoomType: preSelectedRoomType,
                        theme: theme,
                        useModernDrawer: useModernDrawer,
                      );
                    }
                    if (initialDaycare) {
                      return ShopDaycareBookingPage(
                        shopId: shopId,
                        settings: settings,
                        shop: shop,
                      );
                    }
                    return Scaffold(
                      appBar: AppBar(title: const Text('我要預約')),
                      body: LayoutBuilder(
                        builder:
                            (BuildContext context, BoxConstraints constraints) {
                              final bool sideBySide =
                                  constraints.maxWidth >= 760;
                              final Widget stayCard = BookingEntryServiceCard(
                                title: '住宿預約',
                                subtitle: '安排貓咪入住與退房日期',
                                imageUrl:
                                    (shop[BookingEntryCardService.instance
                                                .urlField(
                                                  BookingEntryCardKind
                                                      .accommodation,
                                                )] ??
                                            shop['coverUrl'] ??
                                            shop['bannerUrl'] ??
                                            '')
                                        .toString(),
                                fallbackIcon: Icons.nights_stay,
                                onTap: () {
                                  ShopBookingEntryPage.openStayBooking(
                                    context: context,
                                    shopId: shopId,
                                    preSelectedRoomType: preSelectedRoomType,
                                    theme: theme,
                                    useModernDrawer: useModernDrawer,
                                  );
                                },
                              );
                              final Widget
                              daycareCard = BookingEntryServiceCard(
                                title: settings.serviceName.isEmpty
                                    ? '貓咪安親'
                                    : settings.serviceName,
                                subtitle: '選擇單日送達與接回時間',
                                imageUrl:
                                    (shop[BookingEntryCardService.instance
                                                .urlField(
                                                  BookingEntryCardKind.daycare,
                                                )] ??
                                            '')
                                        .toString(),
                                fallbackIcon: Icons.wb_sunny_outlined,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute<void>(
                                      builder: (_) => ShopDaycareBookingPage(
                                        shopId: shopId,
                                        settings: settings,
                                        shop: shop,
                                      ),
                                    ),
                                  );
                                },
                              );
                              if (sideBySide) {
                                return Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Row(
                                    children: <Widget>[
                                      Expanded(child: stayCard),
                                      const SizedBox(width: 16),
                                      Expanded(child: daycareCard),
                                    ],
                                  ),
                                );
                              }
                              return ListView(
                                padding: const EdgeInsets.all(16),
                                children: <Widget>[
                                  stayCard,
                                  const SizedBox(height: 16),
                                  daycareCard,
                                ],
                              );
                            },
                      ),
                    );
                  },
            );
          },
    );
  }
}

class _GatedStayBooking extends StatefulWidget {
  const _GatedStayBooking({
    required this.shopId,
    required this.preSelectedRoomType,
    required this.theme,
    required this.useModernDrawer,
  });

  final String shopId;
  final Map<String, dynamic>? preSelectedRoomType;
  final HomeThemeModel theme;
  final bool useModernDrawer;

  @override
  State<_GatedStayBooking> createState() => _GatedStayBookingState();
}

class _GatedStayBookingState extends State<_GatedStayBooking> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final bool ok = await ShopBookingEntryPage.ensureAccommodationPolicy(
        context: context,
        shopId: widget.shopId,
        theme: widget.theme,
      );
      if (!mounted) {
        return;
      }
      if (!ok) {
        Navigator.pop(context);
        return;
      }
      setState(() => _ready = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return ShopBookingPage(
      shopId: widget.shopId,
      preSelectedRoomType: widget.preSelectedRoomType,
      theme: widget.theme,
      useModernDrawer: widget.useModernDrawer,
    );
  }
}
