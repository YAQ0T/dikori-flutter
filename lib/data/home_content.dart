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

class TrustBadge {
  final String key;
  final String title;
  final String description;

  const TrustBadge({
    required this.key,
    required this.title,
    required this.description,
  });
}

class TestimonialItem {
  final String key;
  final String name;
  final String role;
  final String quote;
  final int rating;
  final String imageUrl;

  const TestimonialItem({
    required this.key,
    required this.name,
    required this.role,
    required this.quote,
    this.rating = 5,
    this.imageUrl = '',
  });
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, val) => MapEntry(key.toString(), val));
  }
  return const <String, dynamic>{};
}

List<Map<String, dynamic>> _asMapList(dynamic value) {
  if (value is! List) return const <Map<String, dynamic>>[];
  return value.map(_asMap).where((item) => item.isNotEmpty).toList();
}

String _asCleanString(dynamic value) => value?.toString().trim() ?? '';

int _asInt(dynamic value, {int fallback = 0}) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

class SiteLocalizedText {
  final String ar;
  final String he;

  const SiteLocalizedText({this.ar = '', this.he = ''});

  factory SiteLocalizedText.fromJson(dynamic json) {
    if (json is String) {
      return SiteLocalizedText(ar: json.trim());
    }
    final map = _asMap(json);
    return SiteLocalizedText(
      ar: _asCleanString(map['ar']),
      he: _asCleanString(map['he']),
    );
  }

  String preferred({String locale = 'ar'}) {
    final normalizedLocale = locale.trim().toLowerCase();
    if (normalizedLocale == 'he' && he.isNotEmpty) return he;
    if (normalizedLocale == 'ar' && ar.isNotEmpty) return ar;
    if (ar.isNotEmpty) return ar;
    if (he.isNotEmpty) return he;
    return '';
  }
}

class SiteHeroSettings {
  final SiteLocalizedText kicker;
  final SiteLocalizedText title;
  final SiteLocalizedText subtitle;
  final String imageUrl;
  final SiteLocalizedText calloutLabel;
  final SiteLocalizedText calloutValue;
  final SiteLocalizedText primaryCtaLabel;
  final SiteLocalizedText secondaryCtaLabel;

  const SiteHeroSettings({
    this.kicker = const SiteLocalizedText(),
    this.title = const SiteLocalizedText(),
    this.subtitle = const SiteLocalizedText(),
    this.imageUrl = '',
    this.calloutLabel = const SiteLocalizedText(),
    this.calloutValue = const SiteLocalizedText(),
    this.primaryCtaLabel = const SiteLocalizedText(),
    this.secondaryCtaLabel = const SiteLocalizedText(),
  });

  factory SiteHeroSettings.fromJson(dynamic json) {
    final map = _asMap(json);
    return SiteHeroSettings(
      kicker: SiteLocalizedText.fromJson(map['kicker']),
      title: SiteLocalizedText.fromJson(map['title']),
      subtitle: SiteLocalizedText.fromJson(map['subtitle']),
      imageUrl: _asCleanString(map['imageUrl']),
      calloutLabel: SiteLocalizedText.fromJson(map['calloutLabel']),
      calloutValue: SiteLocalizedText.fromJson(map['calloutValue']),
      primaryCtaLabel: SiteLocalizedText.fromJson(map['primaryCtaLabel']),
      secondaryCtaLabel: SiteLocalizedText.fromJson(map['secondaryCtaLabel']),
    );
  }
}

class SiteCategoryItem {
  final String value;
  final SiteLocalizedText label;
  final String imageUrl;
  final int order;

  const SiteCategoryItem({
    required this.value,
    this.label = const SiteLocalizedText(),
    this.imageUrl = '',
    this.order = 0,
  });

  factory SiteCategoryItem.fromJson(dynamic json) {
    final map = _asMap(json);
    return SiteCategoryItem(
      value: _asCleanString(map['value']),
      label: SiteLocalizedText.fromJson(map['label']),
      imageUrl: _asCleanString(map['imageUrl']),
      order: _asInt(map['order']),
    );
  }
}

class SiteSubCategoryItem {
  final String main;
  final String value;
  final SiteLocalizedText label;
  final String imageUrl;
  final int order;

  const SiteSubCategoryItem({
    required this.main,
    required this.value,
    this.label = const SiteLocalizedText(),
    this.imageUrl = '',
    this.order = 0,
  });

  factory SiteSubCategoryItem.fromJson(dynamic json) {
    final map = _asMap(json);
    return SiteSubCategoryItem(
      main: _asCleanString(map['main']),
      value: _asCleanString(map['value']),
      label: SiteLocalizedText.fromJson(map['label']),
      imageUrl: _asCleanString(map['imageUrl']),
      order: _asInt(map['order']),
    );
  }
}

class SiteSettingsData {
  final SiteHeroSettings hero;
  final List<SiteCategoryItem> homeCategories;
  final List<SiteCategoryItem> categoryMenuMain;
  final List<SiteSubCategoryItem> categoryMenuSub;

  const SiteSettingsData({
    this.hero = const SiteHeroSettings(),
    this.homeCategories = const <SiteCategoryItem>[],
    this.categoryMenuMain = const <SiteCategoryItem>[],
    this.categoryMenuSub = const <SiteSubCategoryItem>[],
  });

  factory SiteSettingsData.fromJson(Map<String, dynamic> json) {
    final categoryMenu = _asMap(json['categoryMenu']);

    final homeCategories = _asMapList(json['homeCategories'])
        .map(SiteCategoryItem.fromJson)
        .where((item) => item.value.isNotEmpty)
        .toList();

    final categoryMenuMain = _asMapList(categoryMenu['main'])
        .map(SiteCategoryItem.fromJson)
        .where((item) => item.value.isNotEmpty)
        .toList();

    final categoryMenuSub = _asMapList(categoryMenu['sub'])
        .map(SiteSubCategoryItem.fromJson)
        .where((item) => item.main.isNotEmpty && item.value.isNotEmpty)
        .toList();

    return SiteSettingsData(
      hero: SiteHeroSettings.fromJson(json['hero']),
      homeCategories: homeCategories,
      categoryMenuMain: categoryMenuMain,
      categoryMenuSub: categoryMenuSub,
    );
  }

  List<SiteCategoryItem> get sortedHomeCategories {
    final list = [...homeCategories];
    list.sort((a, b) {
      final byOrder = a.order.compareTo(b.order);
      return byOrder != 0 ? byOrder : a.value.compareTo(b.value);
    });
    return list;
  }

  List<SiteCategoryItem> get sortedCategoryMenuMain {
    final list = [...categoryMenuMain];
    list.sort((a, b) {
      final byOrder = a.order.compareTo(b.order);
      return byOrder != 0 ? byOrder : a.value.compareTo(b.value);
    });
    return list;
  }

  List<SiteSubCategoryItem> get sortedCategoryMenuSub {
    final list = [...categoryMenuSub];
    list.sort((a, b) {
      final byMain = a.main.compareTo(b.main);
      if (byMain != 0) return byMain;
      final byOrder = a.order.compareTo(b.order);
      return byOrder != 0 ? byOrder : a.value.compareTo(b.value);
    });
    return list;
  }
}

enum SiteAdTargetType { none, product, url }

enum SiteAdShowMode { oncePerSession, always }

class SiteAdData {
  final bool enabled;
  final SiteLocalizedText title;
  final SiteLocalizedText text;
  final String imageUrl;
  final SiteAdTargetType targetType;
  final String targetValue;
  final SiteAdShowMode showMode;
  final String dismissKey;

  const SiteAdData({
    this.enabled = false,
    this.title = const SiteLocalizedText(),
    this.text = const SiteLocalizedText(),
    this.imageUrl = '',
    this.targetType = SiteAdTargetType.none,
    this.targetValue = '',
    this.showMode = SiteAdShowMode.oncePerSession,
    this.dismissKey = 'site-ad:0',
  });

  factory SiteAdData.fromJson(Map<String, dynamic> json) {
    final targetTypeRaw = _asCleanString(json['targetType']);
    final showModeRaw = _asCleanString(json['showMode']);
    final dismissKeyRaw = _asCleanString(json['dismissKey']);

    final targetType = switch (targetTypeRaw) {
      'product' => SiteAdTargetType.product,
      'url' => SiteAdTargetType.url,
      _ => SiteAdTargetType.none,
    };

    final showMode = switch (showModeRaw) {
      'always' => SiteAdShowMode.always,
      _ => SiteAdShowMode.oncePerSession,
    };

    return SiteAdData(
      enabled: json['enabled'] == true,
      title: SiteLocalizedText.fromJson(json['title']),
      text: SiteLocalizedText.fromJson(json['text']),
      imageUrl: _asCleanString(json['imageUrl']),
      targetType: targetType,
      targetValue: _asCleanString(json['targetValue']),
      showMode: showMode,
      dismissKey: dismissKeyRaw.isNotEmpty ? dismissKeyRaw : 'site-ad:0',
    );
  }
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

    double? readDouble(dynamic value) {
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '');
    }

    DateTime? readDate(dynamic value) {
      if (value is DateTime) return value;
      final raw = value?.toString();
      if (raw == null || raw.isEmpty) return null;
      return DateTime.tryParse(raw);
    }

    bool isDiscountActive(Map<String, dynamic> discount, DateTime now) {
      final discountValue = readDouble(discount['value']) ?? 0;
      if (discountValue <= 0) return false;
      final startAt = readDate(discount['startAt']);
      final endAt = readDate(discount['endAt']);
      if (startAt != null && now.isBefore(startAt)) return false;
      if (endAt != null && now.isAfter(endAt)) return false;
      return true;
    }

    double? resolveVariantPrice(Map<String, dynamic> variant, DateTime now) {
      final finalAmount = readDouble(variant['finalAmount']);
      if (finalAmount != null) return finalAmount < 0 ? 0 : finalAmount;

      final finalPrice = readDouble(variant['finalPrice']);
      if (finalPrice != null) return finalPrice < 0 ? 0 : finalPrice;

      final rawPrice = variant['price'];
      final priceMap = _asMap(rawPrice);
      final amount = readDouble(
        priceMap.isNotEmpty ? priceMap['amount'] : rawPrice,
      );
      if (amount == null) return null;

      final rawDiscount = priceMap.isNotEmpty
          ? priceMap['discount']
          : variant['discount'];
      final discountMap = _asMap(rawDiscount);
      if (discountMap.isNotEmpty && isDiscountActive(discountMap, now)) {
        final discountValue = readDouble(discountMap['value']) ?? 0;
        final discountType = discountMap['type']?.toString().trim().toLowerCase();
        if (discountValue > 0) {
          if (discountType == 'amount') {
            final discounted = amount - discountValue;
            return discounted < 0 ? 0 : discounted;
          }
          final discounted = amount - (amount * discountValue / 100);
          return discounted < 0 ? 0 : discounted;
        }
      }

      return amount < 0 ? 0 : amount;
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
    double? minVariantPrice;

    final vars = json['vars'];
    final now = DateTime.now();
    if (vars is List && vars.isNotEmpty) {
      Map<String, dynamic>? firstVar;
      for (final rawVar in vars) {
        final varMap = _asMap(rawVar);
        if (varMap.isEmpty) continue;
        firstVar ??= varMap;
        final currentPrice = resolveVariantPrice(varMap, now);
        if (currentPrice == null) continue;
        if (minVariantPrice == null || currentPrice < minVariantPrice!) {
          minVariantPrice = currentPrice;
        }
      }

      if (firstVar != null) {
        variantPrice = resolveVariantPrice(firstVar, now);
        final color = _asMap(firstVar['color']);
        final colorImages = color['images'] is List
            ? (color['images'] as List).whereType<String>()
            : const Iterable<String>.empty();
        final varImages = firstVar['images'] is List
            ? (firstVar['images'] as List).whereType<String>()
            : const Iterable<String>.empty();
        variantImage =
            (colorImages.isNotEmpty ? colorImages.first : null) ??
            (varImages.isNotEmpty ? varImages.first : null);
        final measure = firstVar['measure']?.toString();
        final colorName = color['name']?.toString();
        final parts = [
          measure,
          colorName,
        ].where((v) => v != null && v.toString().isNotEmpty).toList();
        variantLabel = parts.isNotEmpty ? parts.join(' • ') : null;
        variantId = firstVar['_id']?.toString();
        variantMeasure = measure;
        variantColor = colorName;
        final stock = _asMap(firstVar['stock']);
        if (stock['sku'] != null) {
          variantSku = stock['sku'].toString();
        } else if (firstVar['sku'] != null) {
          variantSku = firstVar['sku'].toString();
        }
      }
    }

    final priceRaw =
        json['minPrice'] ??
        json['finalPrice'] ??
        minVariantPrice ??
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

const List<TrustBadge> trustBadges = [
  TrustBadge(
    key: 'delivery',
    title: 'توصيل سريع',
    description: 'شحن منظم وتحديثات مستمرة للطلب.',
  ),
  TrustBadge(
    key: 'support',
    title: 'دعم مباشر',
    description: 'فريق مختص يجاوبك بسرعة ووضوح.',
  ),
  TrustBadge(
    key: 'secure',
    title: 'دفع محمي',
    description: 'معالجة آمنة عبر مزودي دفع معتمدين.',
  ),
  TrustBadge(
    key: 'returns',
    title: 'استبدال مرن',
    description: 'سياسات واضحة لخدمة ما بعد البيع.',
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

const List<TestimonialItem> testimonials = [
  TestimonialItem(
    key: '1',
    name: 'أحمد صالح',
    role: 'صاحب ورشة نجارة',
    quote: 'الجودة ممتازة والأسعار واضحة، والطلب يصل بسرعة.',
    rating: 5,
  ),
  TestimonialItem(
    key: '2',
    name: 'ميساء عواد',
    role: 'مصممة مطابخ',
    quote: 'التصنيفات دقيقة والخيارات واسعة، سهّل علي اختيار القطع.',
    rating: 5,
  ),
  TestimonialItem(
    key: '3',
    name: 'محمد دويك',
    role: 'منجّد أثاث',
    quote: 'التعامل محترف، ومتابعة الطلبات ممتازة من البداية للنهاية.',
    rating: 5,
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
