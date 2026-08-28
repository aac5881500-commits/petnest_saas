// lib/features/shop/pages/store/shop_store_product_list_page.dart
// 🛒 後台商品列表

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/store_product_model.dart';
import 'package:petnest_saas/core/services/store_product_service.dart';
import 'package:petnest_saas/features/shop/pages/store/shop_store_product_form_page.dart';

class ShopStoreProductListPage extends StatelessWidget {
  const ShopStoreProductListPage({
    super.key,
    required this.shopId,
    required this.canManage,
  });

  final String shopId;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => ShopStoreProductFormPage(shopId: shopId),
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('新增商品'),
            )
          : null,
      body: StreamBuilder<List<StoreProductModel>>(
        stream: StoreProductService.instance.streamProducts(shopId),
        builder: (
          BuildContext context,
          AsyncSnapshot<List<StoreProductModel>> snapshot,
        ) {
          final List<StoreProductModel> products =
              snapshot.data ?? const <StoreProductModel>[];
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (products.isEmpty) {
            return const Center(child: Text('尚未建立商品'));
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
            itemCount: products.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (BuildContext context, int index) {
              final StoreProductModel product = products[index];
              return Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: canManage
                      ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => ShopStoreProductFormPage(
                                shopId: shopId,
                                product: product,
                              ),
                            ),
                          );
                        }
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: <Widget>[
                        _ProductThumb(imageUrl: product.imageUrl),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                product.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text('NT\$ ${product.price}'),
                              Text(
                                [
                                  product.enabled ? '上架' : '停用',
                                  if (product.featured) '精選',
                                  if (product.useInventory) '庫存連動',
                                ].join(' · '),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ProductThumb extends StatelessWidget {
  const _ProductThumb({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 56,
        height: 56,
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
        child: imageUrl.trim().isEmpty
            ? Icon(
                Icons.shopping_bag_outlined,
                color: Theme.of(context).colorScheme.primary,
              )
            : Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) {
                  return Icon(
                    Icons.shopping_bag_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  );
                },
              ),
      ),
    );
  }
}
