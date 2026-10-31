import 'package:petnest_saas/core/models/shop_map_location.dart';
import 'package:petnest_saas/features/platform/models/public_map_shop.dart';
import 'platform_shop_map_page.dart';
import 'package:petnest_saas/features/platform/widgets/explore_section_header.dart';
import 'package:petnest_saas/core/services/shop_sharing_service.dart';
// 檔案名稱：lib/features/platform/pages/platform_shop_list_page.dart
// 功能說明：探索好店。首頁只逛店，會員功能收在左側可收合浮層。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/features/auth/pages/login_page.dart';
import 'package:petnest_saas/features/booking/pages/my_bookings_page.dart';
import 'package:petnest_saas/features/platform/widgets/compact_shop_card.dart';
import 'package:petnest_saas/features/platform/widgets/explore_discovery_header.dart';
import 'package:petnest_saas/core/widgets/app_state_panel.dart';
import 'package:petnest_saas/features/platform/widgets/explore_sidebar.dart';
import 'package:petnest_saas/features/platform/widgets/my_shops_section.dart';
import 'package:petnest_saas/features/shop/pages/shop_booking_entry_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_public_page.dart';

class PlatformShopListPage extends StatefulWidget {
  const PlatformShopListPage({super.key});

  @override
  State<PlatformShopListPage> createState() => _PlatformShopListPageState();
}

class _PlatformShopListPageState extends State<PlatformShopListPage> {
  static const List<String> _categories = <String>[
    '全部',
    '貓咪旅宿',
    '狗狗旅宿',
    '寵物美容',
    '動物醫院',
    '寵物賣場',
  ];

  late Stream<QuerySnapshot<Map<String, dynamic>>> _shopStream;

  Stream<QuerySnapshot<Map<String, dynamic>>> _publicShops() =>
      FirebaseFirestore.instance
          .collection('shops')
          .where('isPublic', isEqualTo: true)
          .snapshots();

  @override
  void initState() {
    super.initState();
    _shopStream = _publicShops();
  }

  void _resetFilters() {
    setState(() {
      _search.clear();
      _category = '全部';
      _openOnly = false;
    });
  }

  final TextEditingController _search = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final Map<String, Future<QuerySnapshot<Map<String, dynamic>>>> _reviews =
      <String, Future<QuerySnapshot<Map<String, dynamic>>>>{};
  String? _stayUid;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _stayStream;
  String _category = '全部';
  bool _openOnly = false;
  bool _memberOpen = false;
  bool _showRecentEmpty = false;

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _toast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _requireLogin(VoidCallback next) async {
    if (FirebaseAuth.instance.currentUser != null) {
      next();
      return;
    }
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => const LoginPage()),
    );
  }

  Future<void> _openShop(String shopId) async {
    try {
      await ShopSharingService.instance.selectPublicShop(shopId);
    } catch (_) {
      if (mounted) _toast('暫時無法切換店家，請稍後重試');
      return;
    }
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => ShopPublicPage(shopId: shopId)),
    );
  }

  void _bookAgain(String shopId) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ShopBookingEntryPage(shopId: shopId),
      ),
    );
  }

  void _openBookings() {
    _requireLogin(() {
      Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => const MyBookingsPage()),
      );
    });
  }

  void _showMap() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => PlatformShopMapPage(
          initialSearch: _search.text,
          initialCategory: _category,
          initialOpenOnly: _openOnly,
          onOpenShop: _openShop,
          shops: _shopStream.map(
            (snapshot) => snapshot.docs.map((doc) {
              final shop = _ExploreShop.fromDoc(doc);
              final data = doc.data();
              final raw = data['mapLocation'];
              final point =
                  raw is Map && raw['addressSnapshot'] == shop.fullAddress
                  ? ShopMapLocation.fromMap(raw)
                  : null;
              return PublicMapShop(
                id: shop.id,
                name: shop.name,
                address: shop.fullAddress,
                area: shop.area,
                imageUrl: shop.coverUrl,
                services: shop.services,
                isOpen: shop.isOpen,
                isPublic: data['isPublic'] == true,
                location: point,
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Future<QuerySnapshot<Map<String, dynamic>>> _reviewFuture(String shopId) {
    return _reviews.putIfAbsent(shopId, () {
      return FirebaseFirestore.instance
          .collection('reviews')
          .where('shopId', isEqualTo: shopId)
          .where('status', isEqualTo: 'visible')
          .get();
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>>? _memberStays() {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return null;
    }
    if (_stayUid != user.uid || _stayStream == null) {
      _stayUid = user.uid;
      _stayStream = FirebaseFirestore.instance
          .collection('bookings')
          .where('userId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .limit(30)
          .snapshots();
    }
    return _stayStream;
  }

  void _toggleMember() {
    setState(() {
      _memberOpen = !_memberOpen;
    });
  }

  void _closeMember() {
    if (!_memberOpen) {
      return;
    }
    setState(() {
      _memberOpen = false;
    });
  }

  void _openRecent() {
    setState(() {
      _memberOpen = true;
      _showRecentEmpty = true;
    });
  }

  List<_ExploreShop> _visible(List<_ExploreShop> shops) {
    final String keyword = _search.text.trim().toLowerCase();
    return shops.where((_ExploreShop shop) {
      if (_openOnly && !shop.isOpen) {
        return false;
      }
      if (_category != '全部' && !shop.services.contains(_category)) {
        return false;
      }
      if (keyword.isEmpty) {
        return true;
      }
      final String haystack =
          '${shop.name} ${shop.area} ${shop.fullAddress} ${shop.services.join(' ')}'
              .toLowerCase();
      return haystack.contains(keyword);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _shopStream,
        builder:
            (
              BuildContext context,
              AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
            ) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return SafeArea(
                  child: AppStatePanel(
                    title: '店家列表暫時無法載入',
                    message: '請確認網路連線，再重新載入公開店家。',
                    onRetry: () => setState(() => _shopStream = _publicShops()),
                  ),
                );
              }
              final List<_ExploreShop> shops = (snapshot.data?.docs ?? [])
                  .map(_ExploreShop.fromDoc)
                  .toList();
              return LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final double width = constraints.maxWidth;
                  final bool desktop = width >= 900;
                  final List<_ExploreShop> visible = _visible(shops);
                  final Widget content = _ExploreBody(
                    desktop: desktop,
                    shops: shops,
                    visible: visible,
                    search: _search,
                    category: _category,
                    categories: _categories,
                    openOnly: _openOnly,
                    scroll: _scroll,
                    onSearch: () => setState(() {}),
                    onCategory: (String value) =>
                        setState(() => _category = value),
                    onOpenOnly: (bool value) =>
                        setState(() => _openOnly = value),
                    onBack: Navigator.canPop(context)
                        ? () => Navigator.pop(context)
                        : null,
                    onMap: _showMap,
                    onMember: _toggleMember,
                    onReset: _resetFilters,
                    onOpenShop: _openShop,
                    onFavorites: () {
                      _requireLogin(() => _toast('收藏功能準備中'));
                    },
                    reviewFuture: _reviewFuture,
                  );
                  final double panelWidth = desktop
                      ? 232
                      : (width * 0.88).clamp(260, 360).toDouble();
                  final Stream<QuerySnapshot<Map<String, dynamic>>>? stays =
                      _memberStays();
                  final Map<String, _ExploreShop> byId = <String, _ExploreShop>{
                    for (final _ExploreShop shop in shops) shop.id: shop,
                  };
                  return SafeArea(
                    child: stays == null
                        ? _ExploreShell(
                            desktop: desktop,
                            panelWidth: panelWidth,
                            memberOpen: _memberOpen,
                            showRecentEmpty: _showRecentEmpty,
                            stays: const <ExploreStayShop>[],
                            loggedIn: false,
                            content: content,
                            onToggle: _toggleMember,
                            onClose: _closeMember,
                            onMap: _showMap,
                            onMyStays: () {
                              _requireLogin(() {
                                setState(() => _memberOpen = true);
                              });
                            },
                            onBookings: () {
                              _closeMember();
                              _openBookings();
                            },
                            onFavorites: () {
                              _requireLogin(() => _toast('收藏功能準備中'));
                            },
                            onRecent: _openRecent,
                            onOpenStay: _openShop,
                          )
                        : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                            stream: stays,
                            builder:
                                (
                                  BuildContext context,
                                  AsyncSnapshot<
                                    QuerySnapshot<Map<String, dynamic>>
                                  >
                                  staySnapshot,
                                ) {
                                  final List<ExploreStayShop> grouped =
                                      staySnapshot.hasData
                                      ? _groupStays(
                                          staySnapshot.data!.docs,
                                          byId,
                                        )
                                      : const <ExploreStayShop>[];
                                  return _ExploreShell(
                                    desktop: desktop,
                                    panelWidth: panelWidth,
                                    memberOpen: _memberOpen,
                                    showRecentEmpty: _showRecentEmpty,
                                    stays: grouped,
                                    loggedIn: true,
                                    stayError: staySnapshot.hasError,
                                    content: content,
                                    onToggle: _toggleMember,
                                    onClose: _closeMember,
                                    onMap: _showMap,
                                    onMyStays: () {
                                      if (grouped.isEmpty) {
                                        setState(() => _memberOpen = true);
                                        return;
                                      }
                                      _closeMember();
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute<void>(
                                          builder: (_) => MyStayShopsPage(
                                            shops: grouped,
                                            onOpen: (ExploreStayShop shop) {
                                              Navigator.pop(context);
                                              _openShop(shop.shopId);
                                            },
                                            onBookAgain:
                                                (ExploreStayShop shop) =>
                                                    _bookAgain(shop.shopId),
                                          ),
                                        ),
                                      );
                                    },
                                    onBookings: () {
                                      _closeMember();
                                      _openBookings();
                                    },
                                    onFavorites: () {
                                      _requireLogin(() => _toast('收藏功能準備中'));
                                    },
                                    onRecent: _openRecent,
                                    onOpenStay: _openShop,
                                  );
                                },
                          ),
                  );
                },
              );
            },
      ),
    );
  }
}

class _ExploreBody extends StatelessWidget {
  const _ExploreBody({
    required this.desktop,
    required this.shops,
    required this.visible,
    required this.search,
    required this.category,
    required this.categories,
    required this.openOnly,
    required this.scroll,
    required this.onSearch,
    required this.onCategory,
    required this.onOpenOnly,
    required this.onBack,
    required this.onMap,
    required this.onMember,
    required this.onReset,
    required this.onOpenShop,
    required this.onFavorites,
    required this.reviewFuture,
  });

  final bool desktop;
  final List<_ExploreShop> shops;
  final List<_ExploreShop> visible;
  final TextEditingController search;
  final String category;
  final List<String> categories;
  final bool openOnly;
  final ScrollController scroll;
  final VoidCallback onSearch;
  final ValueChanged<String> onCategory;
  final ValueChanged<bool> onOpenOnly;
  final VoidCallback? onBack;
  final VoidCallback onMap;
  final VoidCallback onMember;
  final VoidCallback onReset;
  final ValueChanged<String> onOpenShop;
  final VoidCallback onFavorites;
  final Future<QuerySnapshot<Map<String, dynamic>>> Function(String shopId)
  reviewFuture;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final double textScale = MediaQuery.textScalerOf(context).scale(1);
    final double imageAspect = desktop ? 1.72 : 1.65;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double gridWidth = constraints.maxWidth;
        final int columns = gridWidth >= 900
            ? 3
            : exploreShopColumns(gridWidth);
        final double aspect = compactShopCardAspectRatio(
          gridWidth: gridWidth,
          columns: columns,
          textScale: textScale,
          imageAspect: imageAspect,
          roomy: desktop,
        );
        Widget cardBuilder(BuildContext context, int index) {
          final _ExploreShop shop = visible[index];
          final card = CompactShopCard(
            name: shop.name,
            imageUrl: shop.coverUrl,
            logoUrl: shop.logoUrl,
            isOpen: shop.isOpen,
            hours: shop.hoursLabel,
            roomy: desktop,
            mobile: gridWidth < 600 || (desktop && visible.length <= 2),
            services: compactServiceLine(shop.services),
            onTap: () => onOpenShop(shop.id),
            onFavorite: onFavorites,
            meta: _RatingLine(
              area: shop.area,
              future: reviewFuture(shop.id),
              fontSize: gridWidth < 600 ? 12.5 : (desktop ? 12.5 : 11.5),
            ),
          );
          return desktop && visible.length <= 2
              ? Align(
                  alignment: Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 860),
                    child: card,
                  ),
                )
              : card;
        }

        return Column(
          children: <Widget>[
            Expanded(
              child: CustomScrollView(
                controller: scroll,
                slivers: <Widget>[
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    sliver: SliverToBoxAdapter(
                      child: ExploreDiscoveryHeader(
                        search: search,
                        categories: categories,
                        category: category,
                        openOnly: openOnly,
                        onSearch: onSearch,
                        onCategory: onCategory,
                        onOpenOnly: onOpenOnly,
                        onReset: onReset,
                        onMap: onMap,
                        onMember: onMember,
                        onBack: onBack,
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                      child: ExploreResultsHeading(
                        count: visible.length,
                        total: shops.length,
                        filtered:
                            search.text.trim().isNotEmpty ||
                            category != '全部' ||
                            openOnly,
                      ),
                    ),
                  ),
                  if (shops.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: Text('目前沒有公開店家')),
                    )
                  else if (visible.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Text(
                              '沒有找到符合條件的店家',
                              style: text.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '試試其他關鍵字或分類',
                              style: text.bodyMedium?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 16),
                            FilledButton.tonalIcon(
                              onPressed: onReset,
                              icon: const Icon(Icons.restart_alt),
                              label: const Text('清除條件，查看全部店家'),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      sliver:
                          gridWidth < 600 || (desktop && visible.length <= 2)
                          ? SliverList.separated(
                              itemCount: visible.length,
                              itemBuilder: cardBuilder,
                              separatorBuilder: (_, index) =>
                                  const SizedBox(height: 12),
                            )
                          : SliverGrid(
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: columns,
                                    crossAxisSpacing: 10,
                                    mainAxisSpacing: 10,
                                    childAspectRatio: aspect,
                                  ),
                              delegate: SliverChildBuilderDelegate(
                                cardBuilder,
                                childCount: visible.length,
                              ),
                            ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ExploreShell extends StatelessWidget {
  const _ExploreShell({
    required this.desktop,
    required this.panelWidth,
    required this.memberOpen,
    required this.showRecentEmpty,
    required this.stays,
    required this.loggedIn,
    required this.content,
    required this.onToggle,
    required this.onClose,
    required this.onMap,
    required this.onMyStays,
    required this.onBookings,
    required this.onFavorites,
    required this.onRecent,
    required this.onOpenStay,
    this.stayError = false,
  });

  final bool desktop;
  final double panelWidth;
  final bool memberOpen;
  final bool showRecentEmpty;
  final List<ExploreStayShop> stays;
  final bool loggedIn;
  final Widget content;
  final VoidCallback onToggle;
  final VoidCallback onClose;
  final VoidCallback onMap;
  final VoidCallback onMyStays;
  final VoidCallback onBookings;
  final VoidCallback onFavorites;
  final VoidCallback onRecent;
  final ValueChanged<String> onOpenStay;
  final bool stayError;

  @override
  Widget build(BuildContext context) {
    final double railWidth = desktop ? 216 : 0;
    final double panelLeft = memberOpen ? railWidth : (railWidth - panelWidth);
    return Column(
      children: <Widget>[
        Expanded(
          child: Stack(
            children: <Widget>[
              Padding(
                padding: EdgeInsets.only(left: railWidth),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1160),
                    child: content,
                  ),
                ),
              ),
              if (memberOpen)
                Positioned(
                  left: railWidth + panelWidth,
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onClose,
                    child: ColoredBox(
                      color: Colors.black.withValues(
                        alpha: desktop ? 0.04 : 0.16,
                      ),
                    ),
                  ),
                ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                left: panelLeft,
                top: 0,
                bottom: 0,
                width: panelWidth,
                child: IgnorePointer(
                  ignoring: !memberOpen,
                  child: ExploreMemberPanel(
                    onClose: onClose,
                    onMap: () {
                      onClose();
                      onMap();
                    },
                    onMyStays: onMyStays,
                    onBookings: onBookings,
                    onFavorites: onFavorites,
                    onRecent: onRecent,
                    stays: stays,
                    loggedIn: loggedIn,
                    stayError: stayError,
                    showRecentEmpty: showRecentEmpty,
                    onOpenStay: (ExploreStayShop shop) {
                      onClose();
                      onOpenStay(shop.shopId);
                    },
                  ),
                ),
              ),
              if (desktop)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: railWidth,
                  child: ExploreMemberRail(
                    expanded: true,
                    onToggle: onToggle,
                    onMyStays: onMyStays,
                    onBookings: onBookings,
                    onFavorites: onFavorites,
                    onRecent: onRecent,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

List<ExploreStayShop> _groupStays(
  List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  Map<String, _ExploreShop> shops,
) {
  final Map<String, int> counts = <String, int>{};
  final Map<String, DateTime?> latest = <String, DateTime?>{};
  final Map<String, String> names = <String, String>{};
  for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in docs) {
    final Map<String, dynamic> data = doc.data();
    final String shopId = (data['shopId'] ?? '').toString().trim();
    if (shopId.isEmpty) {
      continue;
    }
    counts[shopId] = (counts[shopId] ?? 0) + 1;
    final DateTime? when =
        _readDate(data['startDate']) ?? _readDate(data['createdAt']);
    final DateTime? current = latest[shopId];
    if (when != null && (current == null || when.isAfter(current))) {
      latest[shopId] = when;
    }
    final String bookedName = (data['shopName'] ?? '').toString().trim();
    if (bookedName.isNotEmpty) {
      names[shopId] = bookedName;
    }
  }
  final List<String> ids = counts.keys.toList()
    ..sort((String a, String b) {
      final DateTime left = latest[a] ?? DateTime.fromMillisecondsSinceEpoch(0);
      final DateTime right =
          latest[b] ?? DateTime.fromMillisecondsSinceEpoch(0);
      return right.compareTo(left);
    });
  return <ExploreStayShop>[
    for (final String id in ids)
      ExploreStayShop(
        shopId: id,
        name: shops[id]?.name ?? names[id] ?? '旅店',
        imageUrl: shops[id]?.coverUrl ?? '',
        count: counts[id] ?? 0,
        latest: latest[id],
      ),
  ];
}

DateTime? _readDate(Object? value) {
  if (value is Timestamp) {
    return value.toDate();
  }
  if (value is DateTime) {
    return value;
  }
  if (value is String) {
    return DateTime.tryParse(value);
  }
  return null;
}

class _RatingLine extends StatelessWidget {
  const _RatingLine({
    required this.area,
    required this.future,
    required this.fontSize,
  });

  final String area;
  final Future<QuerySnapshot<Map<String, dynamic>>> future;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
      future: future,
      builder:
          (
            BuildContext context,
            AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
          ) {
            String prefix = snapshot.hasError ? '評價暫無法載入' : '尚無評價';
            final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
                snapshot.data?.docs ??
                <QueryDocumentSnapshot<Map<String, dynamic>>>[];
            if (docs.isNotEmpty) {
              double total = 0;
              for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
                  in docs) {
                total += ((doc.data()['rating'] ?? 0) as num).toDouble();
              }
              prefix =
                  '★ ${(total / docs.length).toStringAsFixed(1)} · ${docs.length} 則';
            }
            final String place = area.trim().isEmpty ? '地區未填' : area.trim();
            return Text(
              '$prefix · $place',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: fontSize,
                height: 1.15,
                color: colors.onSurfaceVariant,
              ),
            );
          },
    );
  }
}

class _ExploreShop {
  const _ExploreShop({
    required this.id,
    required this.name,
    required this.city,
    required this.district,
    required this.address,
    required this.coverUrl,
    required this.logoUrl,
    required this.isOpen,
    required this.openTime,
    required this.closeTime,
    required this.services,
  });

  final String id;
  final String name;
  final String city;
  final String district;
  final String address;
  final String coverUrl;
  final String logoUrl;
  final bool isOpen;
  final String openTime;
  final String closeTime;
  final List<String> services;

  String get hoursLabel {
    final String open = openTime.trim();
    final String close = closeTime.trim();
    if (open.isEmpty || close.isEmpty) {
      return '';
    }
    return '$open–$close';
  }

  String get area {
    final String cityText = city.trim();
    final String districtText = district.trim();
    if (cityText.isEmpty) {
      return districtText;
    }
    if (districtText.isEmpty) {
      return cityText;
    }
    return '$cityText$districtText';
  }

  String get fullAddress => '$city$district$address';

  static _ExploreShop fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final Map<String, dynamic> data = doc.data();
    final List<String> modules =
        List<String>.from(data['enabledModules'] ?? <dynamic>[])
            .where((String item) => item != 'basic_info' && item != 'reports')
            .toList();
    final List<String> labels = modules.isEmpty
        ? <String>[_typeLabel(data['businessType']?.toString() ?? '')]
        : modules.map(_moduleLabel).toList();
    final String platformCover = data['platformHomeCoverUrl']?.toString() ?? '';
    return _ExploreShop(
      id: doc.id,
      name: (data['name'] ?? '未命名店家').toString(),
      city: (data['city'] ?? '').toString(),
      district: (data['district'] ?? '').toString(),
      address: (data['address'] ?? '').toString(),
      coverUrl: platformCover.isNotEmpty
          ? platformCover
          : data['coverUrl']?.toString() ?? '',
      logoUrl: data['platformHomeLogoUrl']?.toString() ?? '',
      isOpen: _isOpenNow(data),
      openTime: data['openTime']?.toString() ?? '',
      closeTime: data['closeTime']?.toString() ?? '',
      services: labels,
    );
  }
}

String _moduleLabel(String value) {
  switch (value) {
    case 'cat_hotel':
      return '貓咪旅宿';
    case 'dog_hotel':
      return '狗狗旅宿';
    case 'grooming':
      return '寵物美容';
    case 'hospital':
      return '動物醫院';
    case 'shop':
      return '寵物賣場';
    default:
      return value;
  }
}

String _typeLabel(String value) {
  switch (value) {
    case 'cat_hotel':
      return '貓咪旅宿';
    case 'dog_hotel':
      return '狗狗旅宿';
    case 'grooming':
      return '寵物美容';
    case 'hospital':
      return '動物醫院';
    case 'shop':
      return '寵物賣場';
    default:
      return '其他';
  }
}

bool _isOpenNow(Map<String, dynamic> data) {
  if (data['isOpen'] != true) {
    return false;
  }
  final String openTime = data['openTime']?.toString() ?? '';
  final String closeTime = data['closeTime']?.toString() ?? '';
  if (openTime.isEmpty || closeTime.isEmpty) {
    return true;
  }
  int? minutes(String value) {
    final List<String> parts = value.split(':');
    if (parts.length != 2) {
      return null;
    }
    final int? hour = int.tryParse(parts[0]);
    final int? minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) {
      return null;
    }
    return hour * 60 + minute;
  }

  final int? open = minutes(openTime);
  final int? close = minutes(closeTime);
  if (open == null || close == null) {
    return true;
  }
  final DateTime now = DateTime.now();
  final int current = now.hour * 60 + now.minute;
  return current >= open && current <= close;
}
