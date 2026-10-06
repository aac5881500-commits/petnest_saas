// 檔案名稱：lib/features/platform/pages/platform_shop_list_page.dart
// 功能說明：探索好店。首頁只逛店，會員功能收在左側可收合浮層。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/features/auth/pages/login_page.dart';
import 'package:petnest_saas/features/booking/pages/my_bookings_page.dart';
import 'package:petnest_saas/features/platform/widgets/compact_shop_card.dart';
import 'package:petnest_saas/features/platform/widgets/explore_section_header.dart';
import 'package:petnest_saas/features/platform/widgets/explore_sidebar.dart';
import 'package:petnest_saas/features/platform/widgets/my_shops_section.dart';
import 'package:petnest_saas/features/shop/pages/shop_booking_entry_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_public_page.dart';
import 'package:url_launcher/url_launcher.dart';

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
  ];

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

  void _openShop(String shopId) {
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

  Future<void> _openMapFor(String address) async {
    if (address.trim().isEmpty) {
      _toast('這間店還沒有地址');
      return;
    }
    final Uri uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _showMap(List<_ExploreShop> shops) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: ListView(
            children: <Widget>[
              const ListTile(title: Text('地圖找店')),
              if (shops.isEmpty) const ListTile(title: Text('目前沒有可顯示在地圖的店家')),
              for (final _ExploreShop shop in shops)
                ListTile(
                  leading: const Icon(Icons.location_on_outlined),
                  title: Text(
                    shop.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    shop.area,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _openMapFor(shop.fullAddress);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _showFilters() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: StatefulBuilder(
            builder: (BuildContext context, StateSetter setSheet) {
              return SwitchListTile(
                title: const Text('只看營業中'),
                value: _openOnly,
                onChanged: (bool value) {
                  setState(() {
                    _openOnly = value;
                  });
                  setSheet(() {});
                },
              );
            },
          ),
        );
      },
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
        stream: FirebaseFirestore.instance
            .collection('shops')
            .where('isPublic', isEqualTo: true)
            .snapshots(),
        builder:
            (
              BuildContext context,
              AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
            ) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
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
                    screenWidth: width,
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
                    onMap: () => _showMap(visible),
                    onFilter: _showFilters,
                    onOpenShop: _openShop,
                    onFavorites: () {
                      _requireLogin(() => _toast('收藏功能準備中'));
                    },
                    reviewFuture: _reviewFuture,
                  );
                  final double panelWidth = desktop
                      ? 232
                      : (width * 0.78).clamp(220, 300).toDouble();
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
    required this.screenWidth,
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
    required this.onFilter,
    required this.onOpenShop,
    required this.onFavorites,
    required this.reviewFuture,
  });

  final double screenWidth;
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
  final VoidCallback onFilter;
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
        final int columns = exploreShopColumns(screenWidth);
        final double aspect = compactShopCardAspectRatio(
          gridWidth: gridWidth,
          columns: columns,
          textScale: textScale,
          imageAspect: imageAspect,
          roomy: desktop,
        );
        return Column(
          children: <Widget>[
            if (!desktop)
              _PhoneHeader(onBack: onBack, onMap: onMap, onFilter: onFilter)
            else if (onBack != null)
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back),
                ),
              ),
            Expanded(
              child: CustomScrollView(
                controller: scroll,
                slivers: <Widget>[
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(16, desktop ? 20 : 4, 16, 0),
                    sliver: SliverToBoxAdapter(
                      child: SizedBox(
                        height: 46,
                        child: TextField(
                          controller: search,
                          onChanged: (_) => onSearch(),
                          style: text.bodyMedium,
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: '搜尋店名、地區或服務',
                            prefixIcon: const Icon(Icons.search, size: 20),
                            filled: true,
                            fillColor: colors.surface,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 0,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: colors.outlineVariant,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: colors.outlineVariant,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 48,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                        itemCount: categories.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (BuildContext context, int index) {
                          final String label = categories[index];
                          return _CategoryChip(
                            label: label,
                            selected: label == category,
                            onTap: () => onCategory(label),
                          );
                        },
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 40,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        children: <Widget>[
                          _CategoryChip(
                            label: '營業中',
                            selected: openOnly,
                            onTap: () => onOpenOnly(!openOnly),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: ExploreSectionHeader(title: '探索更多店家'),
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
                          ],
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: aspect,
                        ),
                        delegate: SliverChildBuilderDelegate((
                          BuildContext context,
                          int index,
                        ) {
                          final _ExploreShop shop = visible[index];
                          return CompactShopCard(
                            name: shop.name,
                            imageUrl: shop.coverUrl,
                            logoUrl: shop.logoUrl,
                            isOpen: shop.isOpen,
                            hours: shop.hoursLabel,
                            roomy: desktop,
                            services: compactServiceLine(shop.services),
                            onTap: () => onOpenShop(shop.id),
                            onFavorite: onFavorites,
                            meta: _RatingLine(
                              area: shop.area,
                              future: reviewFuture(shop.id),
                              fontSize: desktop ? 12.5 : 11.5,
                            ),
                          );
                        }, childCount: visible.length),
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
  final VoidCallback onMyStays;
  final VoidCallback onBookings;
  final VoidCallback onFavorites;
  final VoidCallback onRecent;
  final ValueChanged<String> onOpenStay;
  final bool stayError;

  @override
  Widget build(BuildContext context) {
    final double panelLeft = memberOpen
        ? (desktop ? 56 : 0)
        : (desktop ? 56 - panelWidth : -panelWidth);
    return Stack(
      children: <Widget>[
        Padding(
          padding: EdgeInsets.only(left: desktop ? 56 : 0),
          child: Align(
            alignment: Alignment.topLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: content,
            ),
          ),
        ),
        if (memberOpen)
          Positioned(
            left: desktop ? 56 + panelWidth : panelWidth,
            right: 0,
            top: 0,
            bottom: 0,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onClose,
              child: ColoredBox(
                color: Colors.black.withValues(alpha: desktop ? 0.04 : 0.16),
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
            width: 56,
            child: ExploreMemberRail(
              onToggle: onToggle,
              onMyStays: onMyStays,
              onBookings: onBookings,
              onFavorites: onFavorites,
              onRecent: onRecent,
            ),
          )
        else if (!memberOpen)
          Positioned(
            left: 0,
            top: 248,
            child: ExplorePawHandle(onTap: onToggle),
          ),
      ],
    );
  }
}

class _PhoneHeader extends StatelessWidget {
  const _PhoneHeader({
    required this.onBack,
    required this.onMap,
    required this.onFilter,
  });

  final VoidCallback? onBack;
  final VoidCallback onMap;
  final VoidCallback onFilter;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return SafeArea(
      bottom: false,
      child: SizedBox(
        height: 52,
        child: Row(
          children: <Widget>[
            if (onBack != null)
              IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back))
            else
              const SizedBox(width: 12),
            Expanded(
              child: Text(
                '探索好店',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            TextButton.icon(
              onPressed: onMap,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 6),
              ),
              icon: const Icon(Icons.map_outlined, size: 18),
              label: const Text('地圖'),
            ),
            TextButton.icon(
              onPressed: onFilter,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 6),
              ),
              icon: const Icon(Icons.tune, size: 18),
              label: const Text('篩選'),
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Material(
      color: selected ? colors.primary : colors.surface,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? colors.primary : colors.outlineVariant,
            ),
          ),
          child: Text(
            label,
            maxLines: 1,
            style: TextStyle(
              color: selected ? colors.onPrimary : colors.onSurface,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ),
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
            String prefix = '尚無評價';
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
