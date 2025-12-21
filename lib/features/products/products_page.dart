part of '../../main.dart';

class _ProductsPage extends StatefulWidget {
  const _ProductsPage({
    required this.products,
    required this.onAddToCart,
    required this.onToggleFavorite,
    required this.isFavorite,
    required this.onViewProduct,
    required this.loading,
    required this.errorText,
    required this.onRetry,
    required this.categories,
    // ignore: unused_element_parameter
    this.fetchVariants,
  });

  final List<ProductItem> products;
  final void Function(ProductItem) onAddToCart;
  final void Function(ProductItem) onToggleFavorite;
  final bool Function(ProductItem) isFavorite;
  final void Function(ProductItem) onViewProduct;
  final bool loading;
  final String? errorText;
  final Future<void> Function()? onRetry;
  final List<CategoryNode> categories;
  final Future<List<VariantItem>> Function(String productId)? fetchVariants;

  @override
  State<_ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<_ProductsPage> {
  static const int _pageSize = 8;
  int _page = 0;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String? _selectedCategory;

  List<String> get _categoryFilters => [
    'الكل',
    ...widget.categories.map((c) => c.main).toSet(),
  ];

  List<ProductItem> get _filteredProducts {
    if (widget.loading) return const [];
    final q = _query.trim().toLowerCase();
    final selected = _selectedCategory;
    return widget.products.where((p) {
      final name = p.name.toLowerCase();
      final matchesQuery = q.isEmpty || name.contains(q);
      final cat = p.mainCategory?.toLowerCase().trim();
      final matchesCat =
          selected == null ||
          selected == 'الكل' ||
          (cat != null && cat == selected.toLowerCase().trim());
      return matchesQuery && matchesCat;
    }).toList();
  }

  void _nextPage(int totalPages) {
    setState(() {
      _page = (_page + 1).clamp(0, totalPages - 1);
    });
  }

  void _prevPage() {
    setState(() {
      _page = (_page - 1).clamp(0, 0x7fffffff);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = widget.loading;
    final filteredProducts = _filteredProducts;
    final totalPages = (isLoading || filteredProducts.isEmpty)
        ? 1
        : (filteredProducts.length / _pageSize).ceil();
    final safePage = _page.clamp(0, (totalPages - 1).clamp(0, totalPages - 1));
    final start = safePage * _pageSize;
    final currentProducts = isLoading
        ? <ProductItem>[]
        : filteredProducts.skip(start).take(_pageSize).toList();

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
                  'كل المنتجات',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.right,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() {
                    _query = value;
                    _page = 0;
                  }),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'ابحث عن منتج',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                  ),
                  textAlign: TextAlign.right,
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  reverse: true,
                  child: Row(
                    children: _categoryFilters
                        .map(
                          (cat) => Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: ChoiceChip(
                              label: Text(cat),
                              selected:
                                  _selectedCategory == cat ||
                                  (_selectedCategory == null && cat == 'الكل'),
                              onSelected: (_) {
                                setState(() {
                                  _selectedCategory = cat;
                                  _page = 0;
                                });
                              },
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 12),
                _ProductsSection(
                  title: 'جميع العناصر',
                  products: currentProducts,
                  onViewProduct: widget.onViewProduct,
                  onAddToCart: widget.onAddToCart,
                  fetchVariants: widget.fetchVariants,
                  onToggleFavorite: widget.onToggleFavorite,
                  isFavorite: widget.isFavorite,
                  isLoading: isLoading,
                  errorText: widget.errorText,
                  onRetry: widget.onRetry,
                  emptyMessage: 'لم يتم العثور على منتجات في هذه الصفحة.',
                  onBrowseAll: widget.onRetry,
                ),
                if (!isLoading &&
                    widget.errorText == null &&
                    widget.products.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: safePage > 0 ? _prevPage : null,
                          icon: const Icon(Icons.arrow_back_ios_new, size: 16),
                          label: const Text('السابق'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: safePage < totalPages - 1
                              ? () => _nextPage(totalPages)
                              : null,
                          icon: const Icon(Icons.arrow_forward_ios, size: 16),
                          label: const Text('التالي'),
                        ),
                        const Spacer(),
                        Text(
                          'صفحة ${safePage + 1} من $totalPages',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoriesPage extends StatefulWidget {
  const _CategoriesPage({
    required this.categories,
    required this.products,
    required this.onAddToCart,
    required this.onToggleFavorite,
    required this.isFavorite,
    required this.onViewProduct,
    required this.api,
    this.initialMain,
  });

  final List<CategoryNode> categories;
  final List<ProductItem> products;
  final void Function(ProductItem) onAddToCart;
  final void Function(ProductItem) onToggleFavorite;
  final bool Function(ProductItem) isFavorite;
  final void Function(ProductItem) onViewProduct;
  final ApiClient api;
  final String? initialMain;

  @override
  State<_CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<_CategoriesPage> {
  String? _selectedMain;
  String? _selectedSub;
  final TextEditingController _categorySearchController =
      TextEditingController();
  String _categoryQuery = '';
  static const int _categoryPageSize = 20;
  int _categoryPage = 0;

  @override
  void initState() {
    super.initState();
    _selectedMain =
        widget.initialMain ?? (widget.categories.isNotEmpty ? 'الكل' : null);
  }

  @override
  void didUpdateWidget(covariant _CategoriesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextMain = widget.initialMain;
    if (nextMain != null && nextMain != _selectedMain) {
      setState(() {
        _selectedMain = nextMain;
        _selectedSub = null;
        _categoryPage = 0;
      });
    }
  }

  @override
  void dispose() {
    _categorySearchController.dispose();
    super.dispose();
  }

  List<ProductItem> get _filteredProducts {
    final queryRaw = _categoryQuery.trim();
    final query = queryRaw.toLowerCase();
    return widget.products.where((p) {
      if (_selectedMain != null &&
          _selectedMain != 'الكل' &&
          (p.mainCategory ?? '') != _selectedMain) {
        return false;
      }
      if (_selectedSub != null && _selectedSub!.isNotEmpty) {
        if ((p.subCategory ?? '') != _selectedSub) return false;
      }
      if (query.isNotEmpty) {
        final name = p.name;
        final nameLower = name.toLowerCase();
        if (!name.contains(queryRaw) && !nameLower.contains(query)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  List<String> get _subsForMain {
    if (_selectedMain == null || _selectedMain == 'الكل') return [];
    final node = widget.categories.firstWhere(
      (c) => c.main == _selectedMain,
      orElse: () =>
          CategoryNode(main: _selectedMain ?? '', subs: [], image: null),
    );
    return node.subs;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('التصنيفات')),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _categorySearchController,
                  onChanged: (value) => setState(() {
                    _categoryQuery = value;
                    _categoryPage = 0;
                  }),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'ابحث عن منتج أو فئة',
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  textAlign: TextAlign.right,
                ),
                const SizedBox(height: 12),
                Text(
                  'اختر فئة',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.right,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 130,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    reverse: true,
                    itemCount: widget.categories.length + 1,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final isAll = index == 0;
                      final c = isAll
                          ? CategoryNode(
                              main: 'الكل',
                              subs: const [],
                              image: null,
                            )
                          : widget.categories[index - 1];
                      final selected =
                          _selectedMain == c.main ||
                          (_selectedMain == null && isAll);
                      final icon = isAll
                          ? Icons.all_inclusive
                          : kCategoryIcons[c.main] ?? Icons.category_outlined;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedMain = c.main;
                            _selectedSub = null;
                            _categoryPage = 0;
                          });
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              height: 64,
                              width: 64,
                              decoration: BoxDecoration(
                                color: selected
                                    ? Colors.black
                                    : Colors.grey.shade200,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                icon,
                                color: selected
                                    ? Colors.white
                                    : Colors.grey.shade800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            SizedBox(
                              width: 110,
                              child: Text(
                                c.main,
                                maxLines: 2,
                                softWrap: true,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      fontWeight: selected
                                          ? FontWeight.w700
                                          : null,
                                      height: 1.2,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                if (_subsForMain.isNotEmpty) ...[
                  Text(
                    'اختر تصنيف فرعي',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.right,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 130,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      reverse: true,
                      itemCount: _subsForMain.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        final s = _subsForMain[index];
                        final selected = _selectedSub == s;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedSub = s;
                              _categoryPage = 0;
                            });
                          },
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                height: 64,
                                width: 64,
                                decoration: BoxDecoration(
                                  color: selected
                                      ? Colors.black
                                      : Colors.grey.shade200,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  kSubcategoryIcons[s] ??
                                      kSubcategoryIcons['default'] ??
                                      Icons.label_important_outline,
                                  color: selected
                                      ? Colors.white
                                      : Colors.grey.shade800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              SizedBox(
                                width: 110,
                                child: Text(
                                  s,
                                  maxLines: 2,
                                  softWrap: true,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        fontWeight: selected
                                            ? FontWeight.w700
                                            : null,
                                        height: 1.2,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Builder(
                  builder: (context) {
                    final filtered = _filteredProducts;
                    final totalPages = filtered.isEmpty
                        ? 1
                        : (filtered.length / _categoryPageSize).ceil();
                    final safePage = _categoryPage.clamp(
                      0,
                      (totalPages - 1).clamp(0, totalPages - 1),
                    );
                    final start = safePage * _categoryPageSize;
                    final current = filtered
                        .skip(start)
                        .take(_categoryPageSize)
                        .toList();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _ProductsSection(
                          title: 'المنتجات',
                          products: current,
                          onViewProduct: widget.onViewProduct,
                          onAddToCart: widget.onAddToCart,
                          fetchVariants: widget.api.fetchVariants,
                          onToggleFavorite: widget.onToggleFavorite,
                          isFavorite: widget.isFavorite,
                          isLoading:
                              widget.products.isEmpty &&
                              widget.categories.isEmpty,
                          errorText: null,
                          emptyMessage: 'لا توجد منتجات في هذا التصنيف.',
                          onBrowseAll: null,
                        ),
                        if (filtered.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Row(
                              children: [
                                OutlinedButton.icon(
                                  onPressed: safePage > 0
                                      ? () => setState(() {
                                          _categoryPage = (_categoryPage - 1)
                                              .clamp(0, 0x7fffffff);
                                        })
                                      : null,
                                  icon: const Icon(
                                    Icons.arrow_back_ios_new,
                                    size: 16,
                                  ),
                                  label: const Text('السابق'),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  onPressed: safePage < totalPages - 1
                                      ? () => setState(() {
                                          _categoryPage = (_categoryPage + 1)
                                              .clamp(0, totalPages - 1);
                                        })
                                      : null,
                                  icon: const Icon(
                                    Icons.arrow_forward_ios,
                                    size: 16,
                                  ),
                                  label: const Text('التالي'),
                                ),
                                const Spacer(),
                                Text(
                                  'صفحة ${safePage + 1} من $totalPages',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(color: Colors.grey.shade700),
                                ),
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.onView,
    required this.onAdd,
    required this.onToggleFavorite,
    required this.isFavorite,
  });

  final ProductItem product;
  final VoidCallback onView;
  final VoidCallback onAdd;
  final VoidCallback onToggleFavorite;
  final bool isFavorite;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final imageSize = constraints.maxWidth;
        final pixelRatio = MediaQuery.of(context).devicePixelRatio;
        final cacheSize = (imageSize * pixelRatio).round();

        return InkWell(
          onTap: onView,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      height: imageSize,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Image.network(
                              product.image,
                              fit: BoxFit.cover,
                              cacheWidth: cacheSize > 0 ? cacheSize : null,
                              cacheHeight: cacheSize > 0 ? cacheSize : null,
                              filterQuality: FilterQuality.low,
                              gaplessPlayback: true,
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Container(
                                      color: Colors.grey.shade200,
                                    );
                                  },
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                    color: Colors.grey.shade200,
                                    child: const Icon(
                                      Icons.image_not_supported_outlined,
                                    ),
                                  ),
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: IconButton(
                              style: IconButton.styleFrom(
                                backgroundColor: const Color(0xE6FFFFFF),
                                padding: const EdgeInsets.all(8),
                              ),
                              onPressed: onToggleFavorite,
                              icon: Icon(
                                isFavorite
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                color: isFavorite
                                    ? Colors.redAccent
                                    : Colors.black,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 8,
                            left: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: const Text(
                                'جديد',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    product.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                  ),
                  const SizedBox(height: 4),
                  if (product.price > 0)
                    Text(
                      '${product.price.toStringAsFixed(2)} ₪',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade700,
                      ),
                      textAlign: TextAlign.right,
                    )
                  else
                    Text(
                      'السعر عند الاختيار',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade700,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 42,
                    child: ElevatedButton(
                      onPressed: onView,
                      child: const Text('عرض المنتج'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 40,
                    child: OutlinedButton(
                      onPressed: onAdd,
                      child: const Text('إضافة للسلة'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ProductSkeleton extends StatelessWidget {
  const _ProductSkeleton();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final imageSize = constraints.maxWidth;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    height: imageSize,
                    child: Container(color: Colors.grey.shade200),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 12,
                  width: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
