part of '../../main.dart';

class _HomeContent extends StatelessWidget {
  const _HomeContent({
    required this.onAddToCart,
    required this.onViewProduct,
    required this.onToggleFavorite,
    required this.isFavorite,
    required this.products,
    required this.recommendedProducts,
    required this.newArrivalProducts,
    required this.isLoading,
    required this.errorText,
    required this.onBrowseAll,
    required this.categories,
    required this.onCategorySelected,
    required this.onStartShopping,
    required this.onExploreCategories,
    required this.heroKicker,
    required this.heroTitle,
    required this.heroSubtitle,
    required this.heroPrimaryCtaLabel,
    required this.heroSecondaryCtaLabel,
    required this.heroCalloutLabel,
    required this.heroCalloutValue,
    required this.heroImageUrl,
    required this.fetchVariants,
  });

  final void Function(ProductItem product) onAddToCart;
  final void Function(ProductItem product) onViewProduct;
  final void Function(ProductItem product) onToggleFavorite;
  final bool Function(ProductItem product) isFavorite;
  final List<ProductItem> products;
  final List<ProductItem> recommendedProducts;
  final List<ProductItem> newArrivalProducts;
  final bool isLoading;
  final String? errorText;
  final VoidCallback onBrowseAll;
  final List<CategoryNode> categories;
  final void Function(CategoryNode node) onCategorySelected;
  final VoidCallback onStartShopping;
  final VoidCallback onExploreCategories;
  final String heroKicker;
  final String heroTitle;
  final String heroSubtitle;
  final String heroPrimaryCtaLabel;
  final String heroSecondaryCtaLabel;
  final String heroCalloutLabel;
  final String heroCalloutValue;
  final String heroImageUrl;
  final Future<List<VariantItem>> Function(String productId) fetchVariants;

  @override
  Widget build(BuildContext context) {
    final fallbackProducts = products.isNotEmpty ? products : suggestedProducts;
    final primaryList = recommendedProducts.isNotEmpty
        ? recommendedProducts
        : fallbackProducts;
    final secondaryList = newArrivalProducts.isNotEmpty
        ? newArrivalProducts
        : (products.length > 8 ? products.sublist(0, 8) : newArrivals);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HeroSection(
          onStartShopping: onStartShopping,
          onExploreCategories: onExploreCategories,
          kicker: heroKicker,
          title: heroTitle,
          subtitle: heroSubtitle,
          primaryCtaLabel: heroPrimaryCtaLabel,
          secondaryCtaLabel: heroSecondaryCtaLabel,
          calloutLabel: heroCalloutLabel,
          calloutValue: heroCalloutValue,
          imageUrl: heroImageUrl,
        ),
        const SizedBox(height: 18),
        const _TrustBadgesSection(),
        const SizedBox(height: 18),
        _CategoriesSection(
          categories: categories,
          onSelect: onCategorySelected,
        ),
        const SizedBox(height: 24),
        _BenefitsSection(),
        const SizedBox(height: 24),
        _ProductsSection(
          title: 'منتجات مُقترحة لك',
          products: primaryList.take(8).toList(),
          onViewProduct: onViewProduct,
          onAddToCart: onAddToCart,
          fetchVariants: fetchVariants,
          onToggleFavorite: onToggleFavorite,
          isFavorite: isFavorite,
          isLoading: isLoading,
          errorText: errorText,
          onBrowseAll: onBrowseAll,
        ),
        const SizedBox(height: 24),
        _ProductsSection(
          title: 'وصل حديثًا',
          products: secondaryList.take(8).toList(),
          onViewProduct: onViewProduct,
          onAddToCart: onAddToCart,
          fetchVariants: fetchVariants,
          onToggleFavorite: onToggleFavorite,
          isFavorite: isFavorite,
          isLoading: isLoading,
          errorText: errorText,
          onBrowseAll: onBrowseAll,
        ),
        const SizedBox(height: 26),
        const _TestimonialsSection(),
        const SizedBox(height: 22),
        const _PaymentSection(),
        const SizedBox(height: 26),
        const _Footer(),
      ],
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({
    required this.onStartShopping,
    required this.onExploreCategories,
    required this.kicker,
    required this.title,
    required this.subtitle,
    required this.primaryCtaLabel,
    required this.secondaryCtaLabel,
    required this.calloutLabel,
    required this.calloutValue,
    required this.imageUrl,
  });

  final VoidCallback onStartShopping;
  final VoidCallback onExploreCategories;
  final String kicker;
  final String title;
  final String subtitle;
  final String primaryCtaLabel;
  final String secondaryCtaLabel;
  final String calloutLabel;
  final String calloutValue;
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 920;

        final textPanel = Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (kicker.trim().isNotEmpty) ...[
              Text(
                kicker,
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: _appMuted(context),
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
            ],
            Text(
              title,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: isWide ? 38 : 32,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              subtitle,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: _appMuted(context),
                height: 1.6,
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 10,
              runSpacing: 10,
              children: [
                ElevatedButton(
                  onPressed: onStartShopping,
                  child: Text(primaryCtaLabel),
                ),
                OutlinedButton(
                  onPressed: onExploreCategories,
                  child: Text(secondaryCtaLabel),
                ),
              ],
            ),
          ],
        );

        final imagePanel = Stack(
          clipBehavior: Clip.none,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: AspectRatio(
                aspectRatio: 4 / 5,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(color: _appSoftSurface(context));
                  },
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: _appSoftSurface(context),
                    child: const Icon(Icons.image_not_supported_outlined, size: 42),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -16,
              right: 16,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 220),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface.withValues(
                    alpha: 0.95,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _appBorder(context)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x22000000),
                      blurRadius: 14,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      calloutLabel,
                      textAlign: TextAlign.right,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: _appMuted(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      calloutValue,
                      textAlign: TextAlign.right,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );

        final content = isWide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(flex: 10, child: textPanel),
                  const SizedBox(width: 24),
                  Expanded(flex: 8, child: imagePanel),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  imagePanel,
                  const SizedBox(height: 28),
                  textPanel,
                ],
              );

        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: const LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [Color(0xFFEFF3F6), Color(0xFFFFFFFF)],
            ),
            border: Border.all(color: _appBorder(context)),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(18, 18, 18, isWide ? 24 : 20),
            child: content,
          ),
        );
      },
    );
  }
}

class _TrustBadgesSection extends StatelessWidget {
  const _TrustBadgesSection();

  IconData _iconForKey(String key) {
    switch (key) {
      case 'delivery':
        return Icons.local_shipping_outlined;
      case 'support':
        return Icons.headset_mic_outlined;
      case 'secure':
        return Icons.shield_outlined;
      case 'returns':
        return Icons.autorenew_rounded;
      case 'quality':
        return Icons.workspace_premium_outlined;
      default:
        return Icons.verified_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width >= 1020
            ? 4
            : width >= 740
            ? 2
            : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 102,
          ),
          itemCount: trustBadges.length,
          itemBuilder: (context, index) {
            final badge = trustBadges[index];
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _appBorder(context)),
              ),
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    height: 38,
                    width: 38,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(
                        alpha: 0.08,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _iconForKey(badge.key),
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          badge.title,
                          textAlign: TextAlign.right,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          badge.description,
                          textAlign: TextAlign.right,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: _appMuted(context),
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
      },
    );
  }
}

class _CategoriesSection extends StatelessWidget {
  const _CategoriesSection({required this.categories, required this.onSelect});

  final List<CategoryNode> categories;
  final void Function(CategoryNode) onSelect;

  @override
  Widget build(BuildContext context) {
    final list = categories.isNotEmpty ? categories : <CategoryNode>[];
    if (list.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width >= 1200
            ? 6
            : width >= 1000
            ? 5
            : width >= 760
            ? 4
            : width >= 520
            ? 4
            : 3;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(title: 'تصفّح حسب الفئة'),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (ctx, box) {
                final itemWidth =
                    (box.maxWidth - (crossAxisCount - 1) * 14) / crossAxisCount;
                final itemHeight = itemWidth + 70;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    mainAxisExtent: itemHeight,
                  ),
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final category = list[index];
                    return _CategoryCard(
                      category: category,
                      onTap: () => onSelect(category),
                    );
                  },
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.category, required this.onTap});

  final CategoryNode category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    border: Border.all(color: _appBorder(context)),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x11000000),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final pixelRatio =
                            MediaQuery.of(context).devicePixelRatio;
                        final size = constraints.maxWidth.isFinite
                            ? constraints.maxWidth
                            : 0.0;
                        final cacheSize = (size * pixelRatio).round();
                        return Image.network(
                          category.image ??
                              'https://placehold.co/200x200/png?text=Category',
                          fit: BoxFit.cover,
                          cacheWidth: cacheSize > 0 ? cacheSize : null,
                          cacheHeight: cacheSize > 0 ? cacheSize : null,
                          filterQuality: FilterQuality.low,
                          gaplessPlayback: true,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(color: _appSoftSurface(context));
                          },
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                color: _appSoftSurface(context),
                                child: const Icon(
                                  Icons.image_not_supported_outlined,
                                ),
                              ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              category.displayMain,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _BenefitsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width >= 1100
            ? 4
            : width >= 780
            ? 3
            : 2;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(title: 'ماذا نقدّم لعملائنا؟'),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                mainAxisExtent: 190,
              ),
              itemCount: benefits.length,
              itemBuilder: (context, index) {
                final benefit = benefits[index];
                return _BenefitCard(benefit: benefit);
              },
            ),
          ],
        );
      },
    );
  }
}

class _BenefitCard extends StatelessWidget {
  const _BenefitCard({required this.benefit});

  final Benefit benefit;

  IconData _iconForBenefit() {
    switch (benefit.key) {
      case 'delivery':
        return Icons.local_shipping_outlined;
      case 'support':
        return Icons.headset_mic_outlined;
      case 'securePayment':
        return Icons.credit_card;
      case 'authentic':
        return Icons.verified_outlined;
      default:
        return Icons.star_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  color: _appSoftSurface(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Icon(
                    _iconForBenefit(),
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              benefit.title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
              textAlign: TextAlign.right,
            ),
            const SizedBox(height: 6),
            Text(
              benefit.description,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: _appMuted(context)),
              textAlign: TextAlign.right,
            ),
          ],
        ),
      ),
    );
  }
}

class _TestimonialsSection extends StatelessWidget {
  const _TestimonialsSection();

  @override
  Widget build(BuildContext context) {
    if (testimonials.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width >= 1000
            ? 3
            : width >= 680
            ? 2
            : 1;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(title: 'آراء العملاء'),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                mainAxisExtent: 224,
              ),
              itemCount: testimonials.length,
              itemBuilder: (context, index) {
                final item = testimonials[index];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: List.generate(
                            item.rating,
                            (_) => const Padding(
                              padding: EdgeInsets.only(left: 2),
                              child: Icon(
                                Icons.star_rounded,
                                size: 18,
                                color: Color(0xFFF59E0B),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: Text(
                            '“${item.quote}”',
                            textAlign: TextAlign.right,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: _appMuted(context),
                              height: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  item.name,
                                  textAlign: TextAlign.right,
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                Text(
                                  item.role,
                                  textAlign: TextAlign.right,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: _appMuted(context)),
                                ),
                              ],
                            ),
                            const SizedBox(width: 10),
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: _appSoftSurface(context),
                              backgroundImage:
                                  item.imageUrl.isNotEmpty ? NetworkImage(item.imageUrl) : null,
                              child: item.imageUrl.isEmpty
                                  ? const Icon(Icons.person_outline)
                                  : null,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _PaymentSection extends StatelessWidget {
  const _PaymentSection();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 720;
            final logos = const [
              _PaymentLogoChip(label: 'VISA'),
              _PaymentLogoChip(label: 'Mastercard'),
            ];
            final details = Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'طرق دفع موثوقة',
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'دفع آمن ومعالجة فورية عبر مزودي الدفع المعتمدين.',
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: _appMuted(context),
                  ),
                ),
              ],
            );
            if (isWide) {
              return Row(
                children: [
                  Wrap(spacing: 10, runSpacing: 10, children: logos),
                  const Spacer(),
                  details,
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                details,
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 10,
                  runSpacing: 10,
                  children: logos,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PaymentLogoChip extends StatelessWidget {
  const _PaymentLogoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: _appSoftSurface(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _appBorder(context)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ProductsSection extends StatelessWidget {
  const _ProductsSection({
    required this.title,
    required this.products,
    required this.onViewProduct,
    required this.onAddToCart,
    required this.onToggleFavorite,
    required this.isFavorite,
    this.isLoading = false,
    this.errorText,
    this.onRetry,
    this.emptyMessage = 'لا توجد منتجات متاحة الآن.',
    this.onBrowseAll,
    this.fetchVariants,
  });

  final String title;
  final List<ProductItem> products;
  final void Function(ProductItem) onViewProduct;
  final void Function(ProductItem) onAddToCart;
  final void Function(ProductItem) onToggleFavorite;
  final bool Function(ProductItem) isFavorite;
  final bool isLoading;
  final String? errorText;
  final VoidCallback? onRetry;
  final String emptyMessage;
  final VoidCallback? onBrowseAll;
  final Future<List<VariantItem>> Function(String productId)? fetchVariants;

  void _showVariantPickerOrAdd(
    BuildContext context,
    ProductItem product,
    Future<List<VariantItem>> Function(String productId)? fetcher,
    void Function(ProductItem) onAdd,
  ) {
    if (fetcher == null) {
      onAdd(product);
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        List<VariantItem> variants = [];
        VariantItem? selected;
        String? error;
        bool loading = true;
        bool initialized = false;

        Future<void> load(StateSetter setState) async {
          setState(() {
            error = null;
            loading = true;
          });
          try {
            final data = await fetcher(product.id);
            if (!sheetCtx.mounted) return;
            if (data.isEmpty) {
              Navigator.of(sheetCtx).pop();
              onAdd(product);
              return;
            }
            setState(() {
              variants = data;
              selected ??= variants.first;
              loading = false;
            });
          } catch (_) {
            if (!sheetCtx.mounted) return;
            setState(() {
              error = 'تعذر تحميل الخيارات، حاول مرة أخرى.';
              loading = false;
            });
          }
        }

        return StatefulBuilder(
          builder: (ctx, setState) {
            if (!initialized) {
              initialized = true;
              Future.microtask(() async {
                await load(setState);
              });
            }

            final selectedMeasure = selected?.measureSlug;
            final selectedColor = selected?.colorSlug;
            final measures = variants.map((v) => v.measureSlug).toSet().toList()
              ..sort();
            final colors = variants.map((v) => v.colorSlug).toSet().toList()
              ..sort();

            void setVariant({String? measure, String? color}) {
              VariantItem? match = variants.firstWhere(
                (v) =>
                    (measure == null || v.measureSlug == measure) &&
                    (color == null || v.colorSlug == color),
                orElse: () => variants.first,
              );
              setState(() {
                selected = match;
              });
            }

            final price = selected?.price ?? product.price;
            final image = (selected?.images.isNotEmpty ?? false)
                ? selected!.images.first
                : product.image;

            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      product.name,
                      style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                      textAlign: TextAlign.right,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      price > 0
                          ? '${price.toStringAsFixed(2)} ₪'
                          : 'السعر عند الاختيار',
                      style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        color: _appMuted(ctx),
                      ),
                      textAlign: TextAlign.right,
                    ),
                    const SizedBox(height: 12),
                    if (loading)
                      const Center(child: CircularProgressIndicator())
                    else if (error != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            error!,
                            style: TextStyle(color: _appError(ctx)),
                            textAlign: TextAlign.right,
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton(
                            onPressed: () => load(setState),
                            child: const Text('إعادة المحاولة'),
                          ),
                        ],
                      )
                    else ...[
                      if (measures.length > 1 || measures.first.isNotEmpty) ...[
                        Text(
                          'اختر المقاس',
                          style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          textAlign: TextAlign.right,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.end,
                          children: measures
                              .map(
                                (slug) => ChoiceChip(
                                  label: Text(
                                    variants
                                            .firstWhere(
                                              (v) => v.measureSlug == slug,
                                            )
                                            .measure
                                            .isNotEmpty
                                        ? variants
                                              .firstWhere(
                                                (v) => v.measureSlug == slug,
                                              )
                                              .measure
                                        : 'مقاس',
                                  ),
                                  selected: selectedMeasure == slug,
                                  onSelected: (_) => setVariant(
                                    measure: slug,
                                    color: selectedColor,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (colors.isNotEmpty) ...[
                        Text(
                          'اختر اللون',
                          style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          textAlign: TextAlign.right,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.end,
                          children: colors
                              .map(
                                (slug) => ChoiceChip(
                                  label: Text(
                                    variants
                                            .firstWhere(
                                              (v) => v.colorSlug == slug,
                                            )
                                            .colorName
                                            .isNotEmpty
                                        ? variants
                                              .firstWhere(
                                                (v) => v.colorSlug == slug,
                                              )
                                              .colorName
                                        : 'لون',
                                  ),
                                  selected: selectedColor == slug,
                                  onSelected: (_) => setVariant(
                                    measure: selectedMeasure,
                                    color: slug,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: 12),
                      ],
                      SizedBox(
                        height: 44,
                        child: ElevatedButton(
                          onPressed: selected == null
                              ? null
                              : () {
                                  final v = selected!;
                                  final variantLabel =
                                      '${v.measure} • ${v.colorName}';
                                  final enriched = ProductItem(
                                    id: product.id,
                                    name: product.name,
                                    price: v.price,
                                    image: image,
                                    description: product.description,
                                    variantLabel: variantLabel,
                                    variantId: v.id,
                                    variantMeasure: v.measure,
                                    variantColor: v.colorName,
                                    variantSku: v.sku,
                                    variantPrice: v.price,
                                    mainCategory: product.mainCategory,
                                    subCategory: product.subCategory,
                                  );
                                  onAdd(enriched);
                                  Navigator.of(ctx).pop();
                                },
                          child: const Text('إضافة للسلة'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (errorText != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            title: title,
            action: TextButton(
              onPressed: onRetry,
              child: const Text('إعادة المحاولة'),
            ),
          ),
          const SizedBox(height: 12),
          _PlaceholderPage(
            title: 'حدث خطأ',
            description: errorText ?? '',
            icon: Icons.wifi_off,
          ),
        ],
      );
    }

    if (!isLoading && products.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(title: title),
          const SizedBox(height: 12),
          _PlaceholderPage(
            title: 'لا توجد عناصر',
            description: emptyMessage,
            icon: Icons.inventory_2_outlined,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: title,
          action: onBrowseAll != null
              ? TextButton(
                  onPressed: onBrowseAll,
                  child: const Text('تصفّح الكل'),
                )
              : null,
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final crossAxisCount = width >= 1100
                ? 4
                : width >= 820
                ? 3
                : width >= 560
                ? 2
                : 2;

            final items = isLoading ? List<ProductItem>.empty() : products;
            final skeletonCount = crossAxisCount * 2;
            const gap = 16.0;
            const double cardVerticalExtras = 185;
            final itemWidth =
                (width - (crossAxisCount - 1) * gap) / crossAxisCount;
            final itemHeight = itemWidth + cardVerticalExtras;

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: gap,
                crossAxisSpacing: gap,
                mainAxisExtent: itemHeight,
              ),
              itemCount: isLoading ? skeletonCount : items.length,
              itemBuilder: (context, index) {
                if (isLoading) {
                  return const _ProductSkeleton();
                }
                final product = items[index];
                return _ProductCard(
                  product: product,
                  onView: () => onViewProduct(product),
                  onAdd: () => _showVariantPickerOrAdd(
                    context,
                    product,
                    fetchVariants,
                    onAddToCart,
                  ),
                  onToggleFavorite: () => onToggleFavorite(product),
                  isFavorite: isFavorite(product),
                );
              },
            );
          },
        ),
      ],
    );
  }
}
