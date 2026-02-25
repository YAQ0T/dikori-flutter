import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import '../data/home_content.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.status, this.data});
  final String message;
  final int? status;
  final Map<String, dynamic>? data;
  @override
  String toString() => 'ApiException($status): $message';
}

class ApiSession {
  final String token;
  final UserProfile user;

  ApiSession({required this.token, required this.user});
}

class UserProfile {
  final String id;
  final String name;
  final String? email;
  final String? phone;
  final String role;

  const UserProfile({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.role = 'user',
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'مستخدم',
      email: json['email']?.toString(),
      phone: json['phone']?.toString(),
      role: json['role']?.toString() ?? 'user',
    );
  }

  Map<String, dynamic> toJson() => {
    '_id': id,
    'name': name,
    if (email != null) 'email': email,
    if (phone != null) 'phone': phone,
    'role': role,
  };
}

class ApiClient {
  ApiClient({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = _normalizeBase(baseUrl),
      favoritesPath = const String.fromEnvironment(
        'FAVORITES_PATH',
        defaultValue: '/favorites',
      ),
      cartPath = const String.fromEnvironment(
        'CART_PATH',
        defaultValue: '/cart',
      ),
      addToCartPath = const String.fromEnvironment(
        'ADD_TO_CART_PATH',
        defaultValue: '/cart/add',
      );

  final http.Client _client;
  final String _baseUrl;
  String? _token;
  final String favoritesPath;
  final String cartPath;
  final String addToCartPath;

  void setToken(String? token) {
    _token = token;
  }

  static String _normalizeBase(String? base) {
    final raw = base ?? kDefaultApiBase;
    return raw.isNotEmpty ? raw.replaceAll(RegExp(r'/+$'), '') : '';
  }

  Uri _uri(String path, [Map<String, String>? params]) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse(
      '$_baseUrl$normalizedPath',
    ).replace(queryParameters: params);
  }

  Map<String, String> _headers() {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      // Bypass reCAPTCHA for native clients
      'x-dikori-client': 'ios-app',
    };
    if (_token != null && _token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  Future<ApiSession> login({
    String? email,
    String? phone,
    required String password,
  }) async {
    final response = await _client.post(
      _uri('/auth/login'),
      headers: _headers(),
      body: jsonEncode({
        if (email != null && email.isNotEmpty) 'email': email,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        'password': password,
      }),
    );

    final data = _decode(response);
    final token = data['token']?.toString();
    final userJson = data['user'] as Map<String, dynamic>?;
    if (token == null || userJson == null) {
      throw ApiException('استجابة تسجيل الدخول غير متوقعة');
    }
    final profile = UserProfile.fromJson(userJson);
    _token = token;
    return ApiSession(token: token, user: profile);
  }

  Future<Map<String, dynamic>> signup({
    required String name,
    String? email,
    String? phone,
    required String password,
  }) async {
    final response = await _client.post(
      _uri('/auth/signup'),
      headers: _headers(),
      body: jsonEncode({
        'name': name,
        if (email != null && email.isNotEmpty) 'email': email,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        'password': password,
      }),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> sendSmsCode({
    String? userId,
    String? phone,
  }) async {
    final response = await _client.post(
      _uri('/auth/send-sms-code'),
      headers: _headers(),
      body: jsonEncode({
        if (userId != null && userId.isNotEmpty) 'userId': userId,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
      }),
    );
    return _decode(response);
  }

  Future<ApiSession> verifySms({
    required String userId,
    required String code,
  }) async {
    final response = await _client.post(
      _uri('/auth/verify-sms'),
      headers: _headers(),
      body: jsonEncode({'userId': userId, 'code': code}),
    );
    final data = _decode(response);
    final token = data['token']?.toString();
    final userJson = data['user'] as Map<String, dynamic>?;
    if (token == null || userJson == null) {
      throw ApiException('استجابة توثيق غير متوقعة');
    }
    final profile = UserProfile.fromJson(userJson);
    _token = token;
    return ApiSession(token: token, user: profile);
  }

  Future<void> requestPasswordReset({String? email, String? phone}) async {
    await _client.post(
      _uri('/auth/password/request-reset'),
      headers: _headers(),
      body: jsonEncode({
        if (email != null && email.isNotEmpty) 'email': email,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
      }),
    );
  }

  Future<void> resetPassword({
    required String token,
    required String password,
    String? email,
  }) async {
    await _client.post(
      _uri('/auth/password/reset'),
      headers: _headers(),
      body: jsonEncode({
        'token': token,
        'password': password,
        if (email != null && email.isNotEmpty) 'email': email,
      }),
    );
  }

  Future<UserProfile> me() async {
    final response = await _client.get(_uri('/auth/me'), headers: _headers());
    final data = _decode(response);
    return UserProfile.fromJson(data);
  }

  Future<List<ProductItem>> fetchProducts({
    int limit = 500,
    int page = 1,
  }) async {
    Future<List<ProductItem>> fetchFrom(String path) async {
      final response = await _client.get(
        _uri(path, {'limit': '$limit', 'page': '$page'}),
        headers: _headers(),
      );
      final data = _decode(response);
      final list = data['items'] ?? data['data'] ?? data['products'];
      if (list is! List) return [];
      return list
          .whereType<Map<String, dynamic>>()
          .map(ProductItem.fromJson)
          .toList();
    }

    try {
      // Match web behavior: with-stats computes minPrice from all variants.
      return await fetchFrom('/products/with-stats');
    } catch (_) {
      // Backward-compatible fallback for older server endpoints.
      return fetchFrom('/products');
    }
  }

  Future<List<ProductItem>> fetchHomeRecommended() =>
      _fetchHomeCollection('/home-collections/recommended');

  Future<List<ProductItem>> fetchHomeNewArrivals() =>
      _fetchHomeCollection('/home-collections/new');

  Future<List<ProductItem>> _fetchHomeCollection(String path) async {
    try {
      final response = await _client.get(_uri(path), headers: _headers());
      final data = _decode(response);
      final list = data['items'] ?? data['data'] ?? data['products'] ?? data;
      if (list is! List) return [];
      return list
          .whereType<Map<String, dynamic>>()
          .map(ProductItem.fromJson)
          .toList();
    } on ApiException catch (e) {
      if (e.status == 404) return [];
      rethrow;
    }
  }

  Future<SiteSettingsData?> fetchSiteSettings() async {
    try {
      final response = await _client.get(
        _uri('/site-settings'),
        headers: _headers(),
      );
      final data = _decode(response);
      if (data.isEmpty) return null;
      return SiteSettingsData.fromJson(data);
    } on ApiException catch (e) {
      if (e.status == 404) return null;
      rethrow;
    }
  }

  Future<SiteAdData?> fetchSiteAd() async {
    try {
      final response = await _client.get(_uri('/site-ad'), headers: _headers());
      final data = _decode(response);
      if (data.isEmpty) return null;
      return SiteAdData.fromJson(data);
    } on ApiException catch (e) {
      if (e.status == 404) return null;
      rethrow;
    }
  }

  Future<ProductItem?> fetchProductById(String id) async {
    final productId = id.trim();
    if (productId.isEmpty) return null;

    try {
      final response = await _client.get(
        _uri('/products/$productId'),
        headers: _headers(),
      );
      final data = _decode(response);
      if (data.isEmpty) return null;
      return ProductItem.fromJson(data);
    } on ApiException catch (e) {
      if (e.status == 404) return null;
      rethrow;
    }
  }

  Future<List<ProductItem>> fetchFavorites() async {
    try {
      final response = await _client.get(
        _uri(favoritesPath),
        headers: _headers(),
      );
      final data = _decode(response);
      final list = data['favorites'] ?? data['data'];
      if (list is! List) return [];
      return list
          .whereType<Map<String, dynamic>>()
          .map(ProductItem.fromJson)
          .toList();
    } on ApiException catch (e) {
      if (e.status == 404) return [];
      rethrow;
    }
  }

  Future<List<CartItem>> fetchCart() async {
    try {
      final response = await _client.get(_uri(cartPath), headers: _headers());
      final data = _decode(response);
      final list = data['items'] ?? data['data'];
      if (list is! List) return [];
      return list.whereType<Map<String, dynamic>>().map(_mapCartItem).toList();
    } on ApiException catch (e) {
      if (e.status == 404) return [];
      rethrow;
    }
  }

  Future<CartItem?> addToCart(String productId) async {
    try {
      final response = await _client.post(
        _uri(addToCartPath),
        headers: _headers(),
        body: jsonEncode({'productId': productId, 'quantity': 1}),
      );
      if (response.statusCode >= 400) return null;
      final data = _decode(response);
      final item = data['item'] ?? data['cartItem'] ?? data;
      if (item is Map<String, dynamic>) return _mapCartItem(item);
      return null;
    } on ApiException catch (e) {
      if (e.status == 404) return null;
      rethrow;
    }
  }

  Future<void> toggleFavorite(String productId) async {
    final response = await _client.post(
      _uri('$favoritesPath/toggle/$productId'),
      headers: _headers(),
    );
    _decode(response);
  }

  Future<List<OrderSummary>> fetchOrders() async {
    final response = await _client.get(
      _uri('/orders/mine'),
      headers: _headers(),
    );
    final data = _decode(response);
    final list = data['orders'] ?? data['data'] ?? data;
    if (list is! List) return [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(OrderSummary.fromJson)
        .toList();
  }

  Future<OrderSummary?> createOrder({
    required List<CartItem> items,
    required String customerName,
    required String customerPhone,
    required String address,
    String? note,
  }) async {
    if (items.isEmpty) {
      throw ApiException('لا توجد عناصر في السلة');
    }

    final payload = {
      'customerName': customerName,
      'customerPhone': customerPhone,
      'address': address,
      if (note != null && note.isNotEmpty) 'note': note,
      'paymentMethod': 'cod',
      'recaptchaAction': 'checkout',
      'items': items
          .map(
            (item) => {
              'productId': item.product.id,
              if (item.product.variantId != null)
                'variantId': item.product.variantId,
              if (item.product.variantMeasure != null)
                'measure': item.product.variantMeasure,
              if (item.product.variantColor != null)
                'color': item.product.variantColor,
              if (item.product.variantSku != null) 'sku': item.product.variantSku,
              'quantity': item.quantity,
              'name': item.product.name,
            },
          )
          .toList(),
    };

    final response = await _client.post(
      _uri('/orders'),
      headers: _headers(),
      body: jsonEncode(payload),
    );

    final data = _decode(response);
    final orderJson = data['order'] ?? data['data'] ?? data;
    if (orderJson is Map<String, dynamic>) {
      return OrderSummary.fromJson(orderJson);
    }
    return null;
  }

  Future<List<VariantItem>> fetchVariants(String productId) async {
    final response = await _client.get(
      _uri('/variants', {'product': productId, 'limit': '200'}),
      headers: _headers(),
    );
    final data = _decode(response);
    final list = data['items'] ?? data['data'] ?? data;
    if (list is! List) return [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(VariantItem.fromJson)
        .toList();
  }

  Future<List<AppNotification>> fetchNotifications() async {
    final response = await _client.get(
      _uri('/notifications/my'),
      headers: _headers(),
    );
    final data = _decode(response);
    final list = data['notifications'] ?? data['data'] ?? data;
    if (list is! List) return [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(AppNotification.fromJson)
        .toList();
  }

  Future<AppNotification?> markNotificationRead(String id) async {
    try {
      final response = await _client.patch(
        _uri('/notifications/$id/read'),
        headers: _headers(),
      );
      final data = _decode(response);
      if (data.isEmpty) return null;
      return AppNotification.fromJson(data);
    } on ApiException catch (e) {
      if (e.status == 404) return null;
      rethrow;
    }
  }

  Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic>? body;
    if (response.body.isNotEmpty) {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) {
        body = decoded;
      } else if (decoded is List) {
        body = {'data': decoded};
      }
    }

    if (response.statusCode >= 400) {
      final message =
          body?['message']?.toString() ?? 'فشل الطلب (${response.statusCode})';
      throw ApiException(message, status: response.statusCode, data: body);
    }

    return body ?? {};
  }

  CartItem _mapCartItem(Map<String, dynamic> json) {
    final productJson = json['product'] as Map<String, dynamic>? ?? json;
    final product = ProductItem.fromJson(productJson);
    final qty = json['quantity'] is num ? (json['quantity'] as num).toInt() : 1;
    return CartItem(product: product, quantity: qty);
  }
}
