part of '../../main.dart';

class _OrdersPage extends StatefulWidget {
  const _OrdersPage({
    required this.ordersProvider,
    required this.loadingProvider,
    required this.ordersErrorProvider,
    required this.onRefreshOrders,
    required this.onViewOrder,
  });

  final List<OrderSummary> Function() ordersProvider;
  final bool Function() loadingProvider;
  final String? Function() ordersErrorProvider;
  final Future<void> Function() onRefreshOrders;
  final void Function(OrderSummary order) onViewOrder;

  @override
  State<_OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<_OrdersPage> {
  static const int _pageSize = 10;
  int _pageIndex = 0;
  List<OrderSummary> _orders = [];

  @override
  void initState() {
    super.initState();
    _syncFromSource();
  }

  void _syncFromSource() {
    final latest = [...widget.ordersProvider()];
    latest.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final maxPage = (latest.length / _pageSize).ceil();
    setState(() {
      _orders = latest;
      if (maxPage == 0) {
        _pageIndex = 0;
      } else if (_pageIndex >= maxPage) {
        _pageIndex = maxPage - 1;
      }
    });
  }

  Future<void> _handleRefresh() async {
    await widget.onRefreshOrders();
    _syncFromSource();
  }

  void _goNext() {
    final maxPage = (_orders.length / _pageSize).ceil();
    if (_pageIndex < maxPage - 1) {
      setState(() => _pageIndex++);
    }
  }

  void _goPrev() {
    if (_pageIndex > 0) {
      setState(() => _pageIndex--);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = widget.loadingProvider();
    final error = widget.ordersErrorProvider();
    final maxPage = (_orders.length / _pageSize).ceil();
    final start = _pageIndex * _pageSize;
    final end = _orders.isEmpty
        ? 0
        : (_orders.length < start + _pageSize
              ? _orders.length
              : start + _pageSize);
    final pageOrders = _orders.sublist(start, end);
    final displayPage = _orders.isEmpty ? 0 : _pageIndex + 1;
    final totalPages = maxPage == 0 ? 1 : maxPage;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('جميع الطلبات')),
        body: RefreshIndicator(
          onRefresh: _handleRefresh,
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : error != null
              ? ListView(
                  padding: const EdgeInsets.all(16),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    Text(
                      error,
                      style: TextStyle(color: Colors.red.shade700),
                      textAlign: TextAlign.right,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _handleRefresh,
                      child: const Text('إعادة المحاولة'),
                    ),
                  ],
                )
              : _orders.isEmpty
              ? ListView(
                  padding: const EdgeInsets.all(16),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 80),
                    Text(
                      'لا توجد طلبات حالية.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.grey.shade700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    for (var i = 0; i < pageOrders.length; i++) ...[
                      _OrderTile(
                        order: pageOrders[i],
                        onTap: () => widget.onViewOrder(pageOrders[i]),
                      ),
                      if (i != pageOrders.length - 1) const Divider(height: 20),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text(
                          'الصفحة $displayPage من $totalPages',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const Spacer(),
                        OutlinedButton.icon(
                          onPressed: _pageIndex > 0 ? _goPrev : null,
                          icon: const Icon(Icons.chevron_right),
                          label: const Text('السابق'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: _pageIndex < maxPage - 1 ? _goNext : null,
                          icon: const Icon(Icons.chevron_left),
                          label: const Text('التالي'),
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

class _OrderTile extends StatelessWidget {
  const _OrderTile({required this.order, required this.onTap});

  final OrderSummary order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shortId = order.id.length > 6
        ? order.id.substring(order.id.length - 6)
        : order.id;
    final date = order.createdAt.toLocal();
    final dateLabel =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'الطلب #$shortId',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'المجموع: ${order.total.toStringAsFixed(2)} ₪ — ${order.itemsCount} عنصر',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade700,
                    ),
                  ),
                  Text(
                    'الحالة: ${order.status}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                dateLabel,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderDetailRow extends StatelessWidget {
  const _OrderDetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700),
            textAlign: TextAlign.left,
          ),
        ],
      ),
    );
  }
}

class _OrderLineItemTile extends StatelessWidget {
  const _OrderLineItemTile({required this.item});

  final OrderLineItem item;

  @override
  Widget build(BuildContext context) {
    final variantLabel = item.variantLabel;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            item.name,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
            textAlign: TextAlign.right,
          ),
          if (variantLabel != null) ...[
            const SizedBox(height: 4),
            Text(
              variantLabel,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
              textAlign: TextAlign.right,
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'الكمية: ${item.quantity}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const Spacer(),
              Text(
                'سعر الوحدة: ${item.price.toStringAsFixed(2)} ₪',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'المجموع: ${item.total.toStringAsFixed(2)} ₪',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
            textAlign: TextAlign.right,
          ),
        ],
      ),
    );
  }
}
