import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:petnest_saas/core/web/shop_maps_loader.dart';
import 'package:petnest_saas/features/platform/models/public_map_shop.dart';

class PlatformShopMapPage extends StatefulWidget {
  const PlatformShopMapPage({
    super.key,
    required this.shops,
    required this.onOpenShop,
    this.initialSearch = '',
    this.initialCategory = '全部',
    this.initialOpenOnly = false,
    this.mapPreviewBuilder,
  });
  final Stream<List<PublicMapShop>> shops;
  final Future<void> Function(String) onOpenShop;
  final String initialSearch, initialCategory;
  final bool initialOpenOnly;

  /// Inject a non-network canvas for widget tests only.
  final Widget Function(List<PublicMapShop>, ValueChanged<String>)?
  mapPreviewBuilder;
  @override
  State<PlatformShopMapPage> createState() => _MapPageState();
}

class _MapPageState extends State<PlatformShopMapPage> {
  static const categories = ['全部', '貓咪旅宿', '狗狗旅宿', '寵物美容', '動物醫院', '寵物賣場'];
  late final TextEditingController _search;
  late String _category;
  late bool _openOnly;
  Future<void>? _loading;
  GoogleMapController? _controller;
  List<double>? _bounds;
  String? _selected;
  bool _entering = false;
  @override
  void initState() {
    super.initState();
    _search = TextEditingController(text: widget.initialSearch);
    _category = widget.initialCategory;
    _openOnly = widget.initialOpenOnly;
  }

  @override
  void dispose() {
    _search.dispose();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _select(PublicMapShop shop) async {
    setState(() => _selected = shop.id);
    final point = shop.location;
    if (point != null) {
      await _controller?.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(point.latitude, point.longitude), 14),
      );
    }
  }

  Future<void> _fit(List<PublicMapShop> shops) async {
    final points = shops
        .where((s) => s.location != null)
        .map((s) => s.location!)
        .toList();
    if (points.isEmpty || _controller == null) return;
    if (points.length == 1) {
      await _controller!.moveCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(points.first.latitude, points.first.longitude),
          14,
        ),
      );
      return;
    }
    var south = points.first.latitude,
        north = south,
        west = points.first.longitude,
        east = west;
    for (final p in points) {
      if (p.latitude < south) south = p.latitude;
      if (p.latitude > north) north = p.latitude;
      if (p.longitude < west) west = p.longitude;
      if (p.longitude > east) east = p.longitude;
    }
    if (south == north && west == east) {
      await _controller!.moveCamera(
        CameraUpdate.newLatLngZoom(LatLng(south, west), 14),
      );
      return;
    }
    await _controller!.moveCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(south, west),
          northeast: LatLng(north, east),
        ),
        56,
      ),
    );
  }

  Future<void> _open(PublicMapShop shop) async {
    if (_entering) return;
    setState(() => _entering = true);
    try {
      await widget.onOpenShop(shop.id);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('店家暫時無法開啟，請重新查詢。')));
      }
    } finally {
      if (mounted) setState(() => _entering = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('地圖找店')),
    body: StreamBuilder<List<PublicMapShop>>(
      stream: widget.shops,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('公開店家暫時無法載入，請返回找店頁重試。'),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final public = filterMapShops(snapshot.data!);
        final filtered = filterMapShops(
          public,
          search: _search.text,
          category: _category,
          openOnly: _openOnly,
        );
        final visible = filterMapShops(filtered, bounds: _bounds);
        final located = filtered.where((s) => s.location != null).toList();
        final selected = visible.where((s) => s.id == _selected).firstOrNull;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Column(
                children: [
                  TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {
                      _bounds = null;
                    }),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: '搜尋店名、地區或服務',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: 150,
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: _category,
                          items: [
                            for (final c in categories)
                              DropdownMenuItem(
                                value: c,
                                child: Text(c == '全部' ? '全部服務' : c),
                              ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _category = value;
                                _bounds = null;
                              });
                            }
                          },
                        ),
                      ),
                      FilterChip(
                        label: const Text('營業中'),
                        selected: _openOnly,
                        onSelected: (value) => setState(() {
                          _openOnly = value;
                          _bounds = null;
                        }),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _search.clear();
                            _category = '全部';
                            _openOnly = false;
                            _bounds = null;
                            _selected = null;
                          });
                          _fit(public);
                        },
                        child: const Text('顯示全部'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${visible.length} 間符合條件 · ${located.length} 間有確認位置${filtered.length > located.length ? ' · ${filtered.length - located.length} 間待店家設定位置' : ''}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: LayoutBuilder(
                builder: (context, bounds) {
                  final wide = bounds.maxWidth >= 900;
                  final map = Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _controller == null
                                  ? null
                                  : () async {
                                      final b = await _controller!
                                          .getVisibleRegion();
                                      if (mounted) {
                                        setState(
                                          () => _bounds = [
                                            b.southwest.latitude,
                                            b.southwest.longitude,
                                            b.northeast.latitude,
                                            b.northeast.longitude,
                                          ],
                                        );
                                      }
                                    },
                              icon: const Icon(Icons.search, size: 17),
                              label: const Text('搜尋這個範圍'),
                            ),
                            TextButton(
                              onPressed: () => _fit(filtered),
                              child: const Text('查看全部標記'),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: _map(located),
                        ),
                      ),
                      if (!wide && selected != null)
                        SizedBox(
                          height: bounds.maxHeight * 0.42,
                          child: SingleChildScrollView(
                            child: _card(selected, selected: true),
                          ),
                        ),
                    ],
                  );
                  if (wide) {
                    return Row(
                      children: [
                        SizedBox(width: 330, child: _list(visible)),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(0, 0, 16, 16),
                            child: map,
                          ),
                        ),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: map,
                        ),
                      ),
                      SizedBox(
                        height: selected == null
                            ? (bounds.maxHeight * 0.32).clamp(0, 190).toDouble()
                            : 0,
                        child: selected == null ? _list(visible) : null,
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    ),
  );
  Widget _map(List<PublicMapShop> shops) {
    if (widget.mapPreviewBuilder != null) {
      return widget.mapPreviewBuilder!(
        shops,
        (id) => setState(() => _selected = id),
      );
    }
    if (!shopMapsConfigured) {
      return _message('地圖服務尚未啟用', '店家列表仍可使用；平台設定地圖服務後即可顯示位置。');
    }
    if (shops.isEmpty && _loading == null) {
      return _message('目前沒有可標示的位置', '符合條件的公開店家尚未確認位置，仍可從列表進店。');
    }
    return FutureBuilder<void>(
      future: _loading ??= ensureShopMapsLoaded(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _message(
            '地圖暫時無法載入',
            '請確認網路或稍後重試。',
            retry: () {
              setState(() => _loading = ensureShopMapsLoaded());
            },
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final first = shops.isEmpty ? null : shops.first.location;
        return GoogleMap(
          initialCameraPosition: CameraPosition(
            target: LatLng(first?.latitude ?? 23.7, first?.longitude ?? 120.96),
            zoom: 11,
          ),
          mapId: const String.fromEnvironment('GOOGLE_MAPS_MAP_ID'),
          markerType: GoogleMapMarkerType.advancedMarker,
          myLocationEnabled: false,
          myLocationButtonEnabled: false,
          mapToolbarEnabled: false,
          markers: {
            for (final shop in shops)
              Marker(
                markerId: MarkerId(shop.id),
                position: LatLng(
                  shop.location!.latitude,
                  shop.location!.longitude,
                ),
                infoWindow: InfoWindow(title: shop.name, snippet: shop.area),
                onTap: () => setState(() => _selected = shop.id),
              ),
          },
          onMapCreated: (controller) {
            _controller = controller;
            _fit(shops);
            if (mounted) setState(() {});
          },
        );
      },
    );
  }

  Widget _list(List<PublicMapShop> shops) => shops.isEmpty
      ? const Center(child: Text('此範圍沒有符合的公開店家'))
      : ListView.builder(
          itemCount: shops.length,
          itemBuilder: (context, index) =>
              _card(shops[index], selected: shops[index].id == _selected),
        );
  Widget _card(PublicMapShop shop, {required bool selected}) => Card(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(
        color: selected
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.outlineVariant,
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (shop.imageUrl.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    shop.imageUrl,
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const Icon(Icons.storefront),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shop.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      '${shop.area} · ${shop.isOpen ? '營業中' : '休息中'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(
                      shop.location == null
                          ? '位置待店家確認'
                          : shop.services.join('・'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: [
              if (shop.location != null)
                TextButton(
                  onPressed: () => _select(shop),
                  child: const Text('定位'),
                ),
              FilledButton.tonal(
                onPressed: _entering ? null : () => _open(shop),
                child: const Text('進入店家'),
              ),
              if (selected)
                TextButton(
                  onPressed: () => setState(() => _selected = null),
                  child: const Text('返回店家列表'),
                ),
              if (shop.address.trim().isNotEmpty)
                IconButton(
                  tooltip: '外部地圖導航',
                  onPressed: () => launchUrl(
                    Uri.https('www.google.com', '/maps/search/', {
                      'api': '1',
                      'query': shop.address,
                    }),
                    mode: LaunchMode.externalApplication,
                  ),
                  icon: const Icon(Icons.directions_outlined, size: 20),
                ),
            ],
          ),
        ],
      ),
    ),
  );
  Widget _message(String title, String text, {VoidCallback? retry}) =>
      ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.map_outlined, size: 40),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(text, textAlign: TextAlign.center),
                if (retry != null)
                  TextButton(onPressed: retry, child: const Text('重試')),
              ],
            ),
          ),
        ),
      );
}
