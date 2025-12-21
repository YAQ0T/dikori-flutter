class Category {
  final String key;
  final String label;
  final String value;
  final String image;

  const Category({
    required this.key,
    required this.label,
    required this.value,
    required this.image,
  });
}

class Benefit {
  final String key;
  final String iconUrl;
  final String title;
  final String description;

  const Benefit({
    required this.key,
    required this.iconUrl,
    required this.title,
    required this.description,
  });
}

class ProductItem {
  final String id;
  final String name;
  final double price;
  final String image;
  final String? description;
  final String? variantLabel;
  final String? variantId;
  final String? variantMeasure;
  final String? variantColor;
  final String? variantSku;
  final double? variantPrice;
  final String? mainCategory;
  final String? subCategory;

  const ProductItem({
    required this.id,
    required this.name,
    required this.price,
    required this.image,
    this.description,
    this.variantLabel,
    this.variantId,
    this.variantMeasure,
    this.variantColor,
    this.variantSku,
    this.variantPrice,
    this.mainCategory,
    this.subCategory,
  });

  factory ProductItem.fromJson(Map<String, dynamic> json) {
    String pickName(dynamic value) {
      if (value is String) return value;
      if (value is Map) {
        final ar = value['ar']?.toString();
        final en = value['en']?.toString();
        return ar ?? en ?? value.values.first.toString();
      }
      return 'منتج';
    }

    final id =
        json['_id']?.toString() ??
        json['id']?.toString() ??
        json['slug']?.toString() ??
        DateTime.now().millisecondsSinceEpoch.toString();
    final name = pickName(json['name'] ?? json['title']);
    final descField = json['description'];
    final description = descField is Map
        ? (descField['ar']?.toString() ??
              descField['en']?.toString() ??
              descField['he']?.toString())
        : descField?.toString();
    final priceField = json['price'];
    String? variantImage;
    String? variantLabel;
    double? variantPrice;
    String? variantId;
    String? variantMeasure;
    String? variantColor;
    String? variantSku;

    final vars = json['vars'];
    if (vars is List && vars.isNotEmpty) {
      final firstVar = vars.cast<Map<String, dynamic>?>().firstWhere(
        (v) => v != null,
        orElse: () => null,
      );
      if (firstVar != null) {
        final priceMap = firstVar['price'];
        final finalAmount = firstVar['finalAmount'];
        final amountFromPrice = priceMap is Map && priceMap['amount'] is num
            ? (priceMap['amount'] as num).toDouble()
            : null;
        final discounted = finalAmount is num ? finalAmount.toDouble() : null;
        variantPrice = discounted ?? amountFromPrice;

        final color = firstVar['color'];
        final colorImages = color is Map && color['images'] is List
            ? (color['images'] as List).whereType<String>()
            : const Iterable<String>.empty();
        final varImages = firstVar['images'] is List
            ? (firstVar['images'] as List).whereType<String>()
            : const Iterable<String>.empty();
        variantImage =
            (colorImages.isNotEmpty ? colorImages.first : null) ??
            (varImages.isNotEmpty ? varImages.first : null);
        final measure = firstVar['measure']?.toString();
        final colorName = color is Map ? color['name']?.toString() : null;
        final parts = [
          measure,
          colorName,
        ].where((v) => v != null && v.toString().isNotEmpty).toList();
        variantLabel = parts.isNotEmpty ? parts.join(' • ') : null;
        variantId = firstVar['_id']?.toString();
        variantMeasure = measure;
        variantColor = colorName;
        final stock = firstVar['stock'];
        if (stock is Map && stock['sku'] != null) {
          variantSku = stock['sku'].toString();
        } else if (firstVar['sku'] != null) {
          variantSku = firstVar['sku'].toString();
        }
      }
    }

    final priceRaw =
        json['minPrice'] ??
        json['finalPrice'] ??
        variantPrice ??
        (priceField is Map ? priceField['amount'] : priceField) ??
        json['basePrice'];
    final price = priceRaw is num
        ? priceRaw.toDouble()
        : double.tryParse(priceRaw?.toString() ?? '') ?? 0;
    final images = json['images'];
    String? firstImage;
    if (images is List && images.isNotEmpty) {
      firstImage = images.first.toString();
    }
    final image =
        variantImage ??
        firstImage ??
        json['image']?.toString() ??
        json['mainImage']?.toString() ??
        'https://placehold.co/600x400/png?text=No+Image';
    return ProductItem(
      id: id,
      name: name,
      price: price,
      image: image,
      description: description,
      variantLabel: variantLabel,
      variantId: variantId,
      variantMeasure: variantMeasure,
      variantColor: variantColor,
      variantSku: variantSku,
      variantPrice: variantPrice,
      mainCategory: json['mainCategory']?.toString(),
      subCategory: json['subCategory']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'price': price,
        'image': image,
        if (description != null) 'description': description,
        if (variantLabel != null) 'variantLabel': variantLabel,
        if (mainCategory != null) 'mainCategory': mainCategory,
        if (subCategory != null) 'subCategory': subCategory,
      };
}

class VariantItem {
  final String id;
  final String measure;
  final String measureSlug;
  final String colorName;
  final String colorSlug;
  final double price;
  final double? compareAt;
  final String? sku;
  final List<String> images;

  const VariantItem({
    required this.id,
    required this.measure,
    required this.measureSlug,
    required this.colorName,
    required this.colorSlug,
    required this.price,
    this.compareAt,
    this.sku,
    this.images = const [],
  });

  factory VariantItem.fromJson(Map<String, dynamic> json) {
    final priceMap = json['price'];
    final finalAmount = json['finalAmount'];
    final double amount = finalAmount is num
        ? finalAmount.toDouble()
        : priceMap is Map && priceMap['amount'] is num
        ? (priceMap['amount'] as num).toDouble()
        : 0.0;
    final compareAt = priceMap is Map && priceMap['compareAt'] is num
        ? (priceMap['compareAt'] as num).toDouble()
        : null;
    final color = json['color'];
    final colorName = color is Map && color['name'] != null
        ? color['name'].toString()
        : (json['colorName']?.toString() ?? '');
    final colorImages = color is Map && color['images'] is List
        ? (color['images'] as List).whereType<String>()
        : const Iterable<String>.empty();
    final ownImages = json['images'] is List
        ? (json['images'] as List).whereType<String>()
        : const Iterable<String>.empty();

    String? sku;
    final stock = json['stock'];
    if (stock is Map && stock['sku'] != null) {
      sku = stock['sku'].toString();
    } else if (json['sku'] != null) {
      sku = json['sku'].toString();
    }

    return VariantItem(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      measure: json['measure']?.toString() ?? '',
      measureSlug:
          json['measureSlug']?.toString() ??
          (json['measure']?.toString().toLowerCase() ?? ''),
      colorName: colorName,
      colorSlug: json['colorSlug']?.toString() ?? colorName.toLowerCase(),
      price: amount,
      compareAt: compareAt,
      sku: sku,
      images: [...colorImages, ...ownImages],
    );
  }
}

class CartItem {
  final ProductItem product;
  final int quantity;

  const CartItem({required this.product, required this.quantity});

  CartItem copyWith({ProductItem? product, int? quantity}) {
    return CartItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
    );
  }

  double get total => product.price * quantity;
}

class OrderLineItem {
  final String name;
  final int quantity;
  final double price;
  final String? color;
  final String? measure;
  final String? sku;

  const OrderLineItem({
    required this.name,
    required this.quantity,
    required this.price,
    this.color,
    this.measure,
    this.sku,
  });

  double get total => price * quantity;

  String? get variantLabel {
    final parts = [measure, color]
        .where((value) => value != null && value.toString().isNotEmpty)
        .map((value) => value!)
        .toList();
    return parts.isEmpty ? null : parts.join(' • ');
  }

  factory OrderLineItem.fromJson(Map<String, dynamic> json) {
    String pickName(dynamic value) {
      if (value is String) return value;
      if (value is Map) {
        final ar = value['ar']?.toString();
        final he = value['he']?.toString();
        final en = value['en']?.toString();
        return ar ?? he ?? en ?? value.values.first.toString();
      }
      return 'منتج';
    }

    final quantityRaw = json['quantity'] ?? json['qty'] ?? json['count'] ?? 0;
    final quantity = quantityRaw is num
        ? quantityRaw.toInt()
        : int.tryParse(quantityRaw.toString()) ?? 0;
    final priceRaw = json['price'] ?? json['unitPrice'] ?? 0;
    final price = priceRaw is num
        ? priceRaw.toDouble()
        : double.tryParse(priceRaw.toString()) ?? 0;

    return OrderLineItem(
      name: pickName(
        json['name'] ?? json['productName'] ?? json['title'] ?? json['product'],
      ),
      quantity: quantity,
      price: price,
      color: json['color']?.toString(),
      measure: json['measure']?.toString(),
      sku: json['sku']?.toString(),
    );
  }
}

class OrderSummary {
  final String id;
  final double total;
  final String status;
  final DateTime createdAt;
  final int itemsCount;
  final List<OrderLineItem> items;

  const OrderSummary({
    required this.id,
    required this.total,
    required this.status,
    required this.createdAt,
    required this.itemsCount,
    required this.items,
  });

  factory OrderSummary.fromJson(Map<String, dynamic> json) {
    final id = json['_id']?.toString() ?? json['id']?.toString() ?? '';
    final totalRaw = json['total'] ?? 0;
    final double total = totalRaw is num
        ? totalRaw.toDouble()
        : double.tryParse(totalRaw.toString()) ?? 0;
    final status = json['status']?.toString() ?? 'pending';
    final created =
        DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final rawItems = json['items'];
    final items = rawItems is List
        ? rawItems
            .whereType<Map<String, dynamic>>()
            .map(OrderLineItem.fromJson)
            .toList()
        : <OrderLineItem>[];
    final itemsCount = items.isNotEmpty
        ? items.length
        : rawItems is List
        ? rawItems.length
        : 0;
    return OrderSummary(
      id: id,
      total: total,
      status: status,
      createdAt: created,
      itemsCount: itemsCount,
      items: items,
    );
  }
}

class AppNotification {
  final String id;
  final String title;
  final String message;
  final DateTime? createdAt;
  final bool isRead;

  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.createdAt,
    this.isRead = false,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final createdAtRaw = json['createdAt']?.toString();
    return AppNotification(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      createdAt:
          createdAtRaw != null ? DateTime.tryParse(createdAtRaw) : null,
      isRead: json['isRead'] == true,
    );
  }

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      title: title,
      message: message,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
    );
  }
}

const String heroTitle = 'مرحبًا بكم في متجر ديكوري';
const String heroSubtitle =
    'هنا تجد أفضل مستلزمات النجارة وأقمشة التنجيد وخامات صناعة الكنب.';

const List<Category> categories = [
  Category(
    key: 'carpentry',
    label: 'لوازم نجارين',
    value: 'لوازم نجارين',
    image: 'https://i.imgur.com/aPYhaQW.png',
  ),
  Category(
    key: 'upholstery',
    label: 'لوازم منجدين',
    value: 'لوازم منجدين',
    image: 'https://i.imgur.com/S9rjrsh.png',
  ),
  Category(
    key: 'doorHandles',
    label: 'مقابض ابواب',
    value: 'مقابض أبواب',
    image: 'https://i.imgur.com/O9xXLeu.png',
  ),
  Category(
    key: 'cabinetHandles',
    label: 'مقابض خزائن',
    value: 'مقابض خزائن',
    image: 'https://i.imgur.com/AEyMjHc.png',
  ),
  Category(
    key: 'kitchenAccessories',
    label: 'اكسسوارات مطابخ',
    value: 'اكسسوارات مطابخ',
    image: 'https://i.imgur.com/hlpu1oK.png',
  ),
  Category(
    key: 'bedroomAccessories',
    label: 'إكسسوارات غرف نوم',
    value: 'اكسسوارات غرف نوم',
    image: 'https://i.imgur.com/ZMr397G.png',
  ),
  Category(
    key: 'tools',
    label: 'عدة وأدوات',
    value: 'عدة وأدوات',
    image: 'https://i.imgur.com/Hf5NvqJ.png',
  ),
  Category(
    key: 'drawers',
    label: 'جوارير وسكك ومفصلات',
    value: 'جوارير وسكك ومفصلات',
    image: 'https://i.imgur.com/fE6zgKp.png',
  ),
  Category(
    key: 'fabrics',
    label: 'أقمشة كنب',
    value: 'أقمشة كنب',
    image: 'https://i.imgur.com/bf8geWx.jpeg',
  ),
  Category(
    key: 'fasteners',
    label: 'كبسات مسامير و براغي',
    value: 'كبسات مسامير و براغي',
    image: 'https://i.imgur.com/CntFVhx.png',
  ),
  Category(
    key: 'doorSupplies',
    label: 'لوازم أبواب',
    value: 'لوازم أبواب',
    image: 'https://i.imgur.com/UskLo6H.png',
  ),
    Category(
    key: 'AlaminumeSupplies',
    label: 'لوازم المنيوم',
    value: 'لوازم المنيوم',
    image: 'https://i.imgur.com/YbIfpWw.png',
  ),
];

const List<Benefit> benefits = [
  Benefit(
    key: 'delivery',
    iconUrl: 'https://www.svgrepo.com/show/467670/delivery-truck.svg',
    title: 'توصيل إلى كافة المدن',
    description: 'توصيل سريع وفي الموعد',
  ),
  Benefit(
    key: 'support',
    iconUrl: 'https://www.svgrepo.com/show/469025/headset-alt.svg',
    title: 'دعم أونلاين',
    description: 'فريق دعم مخصص من 8:30 صباحًا حتى 12:00 ليلًا',
  ),
  Benefit(
    key: 'securePayment',
    iconUrl: 'https://www.svgrepo.com/show/468385/credit-card-2.svg',
    title: 'دفع آمن 100٪',
    description: 'جميع البطاقات مقبولة ومعالجة آمنة',
  ),
  Benefit(
    key: 'authentic',
    iconUrl: 'https://www.svgrepo.com/show/468263/check-mark-circle.svg',
    title: 'منتجات أصلية 100٪',
    description: 'ضمان الأصالة والجودة',
  ),
];

const List<ProductItem> suggestedProducts = [
  ProductItem(
    id: '1',
    name: 'مقبض خزانة معدني',
    price: 29.9,
    image: 'https://i.imgur.com/lu2y3pi.png',
    description: 'مقبض معدني متين للأدراج والخزائن.',
  ),
  ProductItem(
    id: '2',
    name: 'سحّاب درج هادئ',
    price: 49,
    image: 'https://i.imgur.com/bf8geWx.jpeg',
    description: 'سكة درج بآلية إغلاق هادئة.',
  ),
  ProductItem(
    id: '3',
    name: 'قماش كنب مقاوم للبقع',
    price: 89,
    image: 'https://i.imgur.com/oW6JO0A.png',
    description: 'قماش جودة عالية للمجالس والكنب.',
  ),
  ProductItem(
    id: '4',
    name: 'مفصلات هيدروليك',
    price: 39.5,
    image: 'https://i.imgur.com/CCEly6H.jpeg',
    description: 'مفصلات بضغط هيدروليكي لإغلاق ناعم.',
  ),
  ProductItem(
    id: '5',
    name: 'مقبض باب حديث',
    price: 55,
    image: 'https://i.imgur.com/O9xXLeu.png',
    description: 'مقبض أبواب بتصميم عصري.',
  ),
  ProductItem(
    id: '6',
    name: 'طقم براغي متنوع',
    price: 19.5,
    image: 'https://i.imgur.com/CntFVhx.png',
    description: 'طقم براغي للاستخدامات العامة.',
  ),
];

const List<ProductItem> newArrivals = [
  ProductItem(
    id: '7',
    name: 'قفل باب أمان',
    price: 75,
    image: 'https://i.imgur.com/UskLo6H.png',
    description: 'قفل باب متين للأمان المنزلي.',
  ),
  ProductItem(
    id: '8',
    name: 'مقابض مطبخ خشبية',
    price: 32,
    image: 'https://i.imgur.com/AEyMjHc.png',
  ),
  ProductItem(
    id: '9',
    name: 'أقمشة جديدة لآخر الموسم',
    price: 120,
    image: 'https://i.imgur.com/bf8geWx.jpeg',
  ),
  ProductItem(
    id: '10',
    name: 'سكة أدراج ثقيلة',
    price: 64,
    image: 'https://i.imgur.com/fE6zgKp.png',
  ),
  ProductItem(
    id: '11',
    name: 'عدة احترافية متكاملة',
    price: 199,
    image: 'https://i.imgur.com/Hf5NvqJ.png',
  ),
  ProductItem(
    id: '12',
    name: 'مقابض غرف نوم فاخرة',
    price: 89,
    image: 'https://i.imgur.com/ZMr397G.png',
  ),
];
