part of '../../main.dart';

class ProductDetailsPage extends StatefulWidget {
  const ProductDetailsPage({
    super.key,
    required this.product,
    required this.onAddToCart,
    required this.api,
  });

  final ProductItem product;
  final void Function(ProductItem) onAddToCart;
  final ApiClient api;

  @override
  State<ProductDetailsPage> createState() => _ProductDetailsPageState();
}

class _ProductDetailsPageState extends State<ProductDetailsPage> {
  List<VariantItem> _variants = [];
  VariantItem? _selected;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadVariants();
  }

  Future<void> _loadVariants() async {
    setState(() {
      _loading = true;
    });
    try {
      final data = await widget.api.fetchVariants(widget.product.id);
      setState(() {
        _variants = data;
        _selected = data.isNotEmpty ? data.first : null;
      });
    } catch (_) {
      setState(() {
        _variants = [];
        _selected = null;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  double get displayPrice {
    if (_selected != null) return _selected!.price;
    return widget.product.price;
  }

  @override
  Widget build(BuildContext context) {
    final image = _selected?.images.isNotEmpty == true
        ? _selected!.images.first
        : widget.product.image;
    final media = MediaQuery.of(context);
    final bottomInset = media.viewPadding.bottom + media.padding.bottom;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.product.name,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset + 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: 4 / 5,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final pixelRatio =
                          MediaQuery.of(context).devicePixelRatio;
                      final width = constraints.maxWidth.isFinite
                          ? constraints.maxWidth
                          : media.size.width;
                      final cacheWidth = (width * pixelRatio).round();
                      return Image.network(
                        image,
                        fit: BoxFit.cover,
                        cacheWidth: cacheWidth > 0 ? cacheWidth : null,
                        filterQuality: FilterQuality.low,
                        gaplessPlayback: true,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(color: Colors.grey.shade200);
                        },
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.image_not_supported_outlined),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.product.name,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.right,
              ),
              const SizedBox(height: 8),
              Text(
                displayPrice > 0
                    ? '${displayPrice.toStringAsFixed(2)} ₪'
                    : 'السعر عند الاختيار',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(color: Colors.grey.shade700),
                textAlign: TextAlign.right,
              ),
              if (_selected?.compareAt != null &&
                  _selected!.compareAt! > displayPrice)
                Text(
                  'السعر قبل الخصم: ${_selected!.compareAt!.toStringAsFixed(2)} ₪',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.redAccent,
                    decoration: TextDecoration.lineThrough,
                  ),
                  textAlign: TextAlign.right,
                ),
              const SizedBox(height: 12),
              if (widget.product.description != null &&
                  widget.product.description!.trim().isNotEmpty)
                Text(
                  widget.product.description!,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey.shade700,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.right,
                )
              else
                Text(
                  'لا يوجد وصف متاح لهذا المنتج.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey.shade700,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.right,
                ),
              const SizedBox(height: 16),
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else if (_variants.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'اختر المقاس',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.right,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.end,
                      children: _variants
                          .map((v) => v.measureSlug)
                          .toSet()
                          .map(
                            (slug) => ChoiceChip(
                              label: Text(
                                _variants
                                        .firstWhere(
                                          (v) => v.measureSlug == slug,
                                        )
                                        .measure
                                        .isNotEmpty
                                    ? _variants
                                          .firstWhere(
                                            (v) => v.measureSlug == slug,
                                          )
                                          .measure
                                    : 'مقاس',
                              ),
                              selected: _selected?.measureSlug == slug,
                              onSelected: (_) {
                                final firstMatch = _variants.firstWhere(
                                  (v) => v.measureSlug == slug,
                                );
                                setState(() {
                                  _selected = firstMatch;
                                });
                              },
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'اختر اللون',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.right,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.end,
                      children: _variants
                          .map((v) => v.colorSlug)
                          .toSet()
                          .map(
                            (slug) => ChoiceChip(
                              label: Text(
                                _variants
                                        .firstWhere((v) => v.colorSlug == slug)
                                        .colorName
                                        .isNotEmpty
                                    ? _variants
                                          .firstWhere(
                                            (v) => v.colorSlug == slug,
                                          )
                                          .colorName
                                    : 'لون',
                              ),
                              selected: _selected?.colorSlug == slug,
                              onSelected: (_) {
                                final firstMatch = _variants.firstWhere(
                                  (v) => v.colorSlug == slug,
                                );
                                setState(() {
                                  _selected = firstMatch;
                                });
                              },
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: (_variants.isNotEmpty && _selected == null)
                          ? null
                          : () {
                              final toAdd = _selected != null
                                  ? ProductItem(
                                      id: widget.product.id,
                                      name: widget.product.name,
                                      price: displayPrice,
                                      image: image,
                                      description: widget.product.description,
                                      variantLabel:
                                          '${_selected!.measure} • ${_selected!.colorName}',
                                      variantId: _selected!.id,
                                      variantMeasure: _selected!.measure,
                                      variantColor: _selected!.colorName,
                                      variantSku: _selected!.sku,
                                      variantPrice: _selected!.price,
                                    )
                                  : widget.product;
                              widget.onAddToCart(toAdd);
                              Navigator.of(context).maybePop();
                            },
                      child: const Text('إضافة للسلة'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      child: const Text('رجوع'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
