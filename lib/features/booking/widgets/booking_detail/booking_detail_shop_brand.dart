import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'booking_detail_ui.dart';

/// Brand is resolved by this booking's shop, never the previously visited shop.
class BookingDetailShopBrand extends StatelessWidget {
  const BookingDetailShopBrand({
    super.key,
    required this.booking,
    this.shopStream,
  });
  final Map<String, dynamic> booking;
  final Stream<Map<String, dynamic>?> Function(String shopId)? shopStream;
  @override
  Widget build(BuildContext context) {
    final id = '${booking['shopId'] ?? ''}'.trim();
    Widget header(Map<String, dynamic>? shop) => BookingDetailBrandHeader(
      name:
          '${shop?['name'] ?? shop?['shopName'] ?? booking['shopName'] ?? ''}',
      logoUrl: '${shop?['logoUrl'] ?? booking['shopLogoUrl'] ?? ''}',
    );
    if (id.isEmpty) return header(null);
    return StreamBuilder<Map<String, dynamic>?>(
      key: ValueKey('booking-brand-$id'),
      stream: shopStream?.call(id) ?? ShopService.instance.streamShop(id),
      builder: (context, snapshot) =>
          header(snapshot.hasError ? null : snapshot.data),
    );
  }
}

class BookingDetailBrandHeader extends StatelessWidget {
  const BookingDetailBrandHeader({
    super.key,
    required this.name,
    this.logoUrl = '',
  });
  final String name, logoUrl;
  @override
  Widget build(BuildContext context) {
    final theme = BookingDetailUi.of(context);
    final fallback = Icon(
      Icons.storefront_outlined,
      color: theme.primary,
      size: 42,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final logoWidth = (constraints.maxWidth * .23).clamp(64.0, 96.0);
        return Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: logoWidth,
                height: 92,
                child: logoUrl.trim().isEmpty
                    ? fallback
                    : Image.network(
                        logoUrl.trim(),
                        fit: BoxFit.contain,
                        alignment: Alignment.center,
                        errorBuilder: (_, error, stack) => fallback,
                      ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '本次預約的店家',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        fontVariations: const [FontVariation('wght', 550)],
                        color: theme.muted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      name.trim().isEmpty ? '訂單店家' : name.trim(),
                      key: const ValueKey('booking-shop-name'),
                      style: TextStyle(
                        fontSize: constraints.maxWidth < 350 ? 20 : 22,
                        height: 1.35,
                        fontWeight: FontWeight.w800,
                        fontVariations: const [FontVariation('wght', 800)],
                        color: theme.text,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
