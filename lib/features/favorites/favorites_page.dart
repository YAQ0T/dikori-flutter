part of '../../main.dart';

class _FavoritesPage extends StatelessWidget {
  const _FavoritesPage({
    required this.products,
    required this.onRemove,
    required this.onAddToCart,
    required this.onViewProduct,
    this.fetchVariants,
  });

  final List<ProductItem> products;
  final void Function(ProductItem) onRemove;
  final void Function(ProductItem) onAddToCart;
  final void Function(ProductItem) onViewProduct;
  final Future<List<VariantItem>> Function(String productId)? fetchVariants;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return const _PlaceholderPage(
        title: 'لا توجد عناصر مفضلة',
        description: 'أضف منتجاتك للمفضلة لمراجعتها لاحقًا.',
        icon: Icons.favorite_border,
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'مفضلتي',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.right,
                ),
                const SizedBox(height: 12),
                _ProductsSection(
                  title: 'مفضلة',
                  products: products,
                  onViewProduct: onViewProduct,
                  onAddToCart: onAddToCart,
                  fetchVariants: fetchVariants,
                  onToggleFavorite: onRemove,
                  isFavorite: (_) => true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
