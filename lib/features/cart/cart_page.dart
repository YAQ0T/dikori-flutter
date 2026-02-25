part of '../../main.dart';

class _CartPage extends StatelessWidget {
  const _CartPage({
    required this.items,
    required this.onIncrement,
    required this.onDecrement,
    required this.onSetQuantity,
    required this.onCheckout,
    required this.placingOrder,
  });

  final List<CartItem> items;
  final void Function(CartItem) onIncrement;
  final void Function(CartItem) onDecrement;
  final void Function(CartItem, int quantity) onSetQuantity;
  final VoidCallback onCheckout;
  final bool placingOrder;

  @override
  Widget build(BuildContext context) {
    final total = items.fold<double>(0, (sum, item) => sum + item.total);
    final imageCacheSize = (68 * MediaQuery.of(context).devicePixelRatio)
        .round();

    if (items.isEmpty) {
      return const _PlaceholderPage(
        title: 'السلة فارغة',
        description: 'أضف منتجاتك المفضلة وسنجهزها لك.',
        icon: Icons.shopping_bag_outlined,
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        children: [
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (context, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = items[index];
                return Card(
                  key: ValueKey(item.product.id),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            height: 68,
                            width: 68,
                            color: _appSoftSurface(context),
                            child: Image.network(
                              item.product.image,
                              fit: BoxFit.cover,
                              cacheWidth:
                                  imageCacheSize > 0 ? imageCacheSize : null,
                              cacheHeight:
                                  imageCacheSize > 0 ? imageCacheSize : null,
                              filterQuality: FilterQuality.low,
                              gaplessPlayback: true,
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Container(
                                      color: _appSoftSurface(context),
                                    );
                                  },
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(
                                    Icons.image_not_supported_outlined,
                                  ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                item.product.name,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.right,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${item.product.price.toStringAsFixed(2)} ₪',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: _appMuted(context)),
                                textAlign: TextAlign.right,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'المجموع: ${item.total.toStringAsFixed(2)} ₪',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: _appMuted(context)),
                                textAlign: TextAlign.right,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => onDecrement(item),
                              icon: const Icon(Icons.remove_circle_outline),
                            ),
                            SizedBox(
                              width: 64,
                              child: _CartQuantityField(
                                quantity: item.quantity,
                                onCommit: (value) => onSetQuantity(item, value),
                              ),
                            ),
                            IconButton(
                              onPressed: () => onIncrement(item),
                              icon: const Icon(Icons.add_circle_outline),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(top: BorderSide(color: _appBorder(context))),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x11000000),
                  blurRadius: 10,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'الإجمالي',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${total.toStringAsFixed(2)} ₪',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ElevatedButton(
                    onPressed: placingOrder ? null : onCheckout,
                    child: placingOrder
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          )
                        : const Text('إتمام الشراء'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CartQuantityField extends StatefulWidget {
  const _CartQuantityField({
    required this.quantity,
    required this.onCommit,
  });

  final int quantity;
  final ValueChanged<int> onCommit;

  @override
  State<_CartQuantityField> createState() => _CartQuantityFieldState();
}

class _CartQuantityFieldState extends State<_CartQuantityField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.quantity.toString());
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(covariant _CartQuantityField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.quantity != oldWidget.quantity && !_focusNode.hasFocus) {
      _controller.text = widget.quantity.toString();
    }
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      _commit();
    }
  }

  void _commit() {
    final raw = _controller.text.trim();
    final parsed = int.tryParse(raw);
    if (parsed == null) {
      _controller.text = widget.quantity.toString();
      return;
    }
    widget.onCommit(parsed);
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_onFocusChanged)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      textAlign: TextAlign.center,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: false,
        signed: false,
      ),
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _commit(),
      decoration: const InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      ),
    );
  }
}
