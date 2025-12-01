import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api/api_client.dart';
import 'data/home_content.dart';
import 'models/category_node.dart';

void main() {
  runApp(const MadinaApp());
}

class MadinaApp extends StatelessWidget {
  const MadinaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseTheme = ThemeData(
      useMaterial3: true,
      colorScheme:
          ColorScheme.fromSeed(
            seedColor: const Color(0xFF1f1f1f),
            brightness: Brightness.light,
          ).copyWith(
            surface: Colors.white,
            surfaceContainerHighest: Colors.grey.shade100,
            outlineVariant: Colors.grey.shade300,
          ),
      scaffoldBackgroundColor: Colors.grey.shade50,
      textTheme: GoogleFonts.cairoTextTheme(),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0.5,
        scrolledUnderElevation: 0.5,
        foregroundColor: Colors.black,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );

    return MaterialApp(
      title: 'ديكوري - Madina',
      debugShowCheckedModeBanner: false,
      theme: baseTheme,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

enum _AuthMode { login, register, verify }

class _HomePageState extends State<HomePage> {
  int _navIndex = 0;
  final ApiClient _api = ApiClient(
    baseUrl: const String.fromEnvironment(
      'API_BASE',
      defaultValue: 'http://localhost:3001/api',
    ),
  );
  final List<CartItem> _cart = [];
  final Set<String> _favoriteIds = {
    ...suggestedProducts.take(2).map((p) => p.id),
  };

  List<ProductItem> _products = [];
  bool _loadingProducts = true;
  String? _productsError;

  bool _loadingFavorites = false;
  bool _loadingCart = false;

  UserProfile? _user;
  bool _loadingProfile = false;
  bool _authSubmitting = false;
  String? _authError;
  String? _pendingUserId;
  String? _pendingPhone;
  List<OrderSummary> _orders = [];
  bool _loadingOrders = false;
  String? _ordersError;
  List<CategoryNode> _categories = [];

  Future<void> _handleRegister({
    required String name,
    String? email,
    String? phone,
    required String password,
  }) async {
    setState(() {
      _authSubmitting = true;
      _authError = null;
    });
    try {
      if (name.isEmpty || phone?.isEmpty != false || password.isEmpty) {
        setState(() {
          _authError = 'أدخل الاسم والجوال وكلمة المرور';
          _authSubmitting = false;
        });
        return;
      }
      final res = await _api.signup(
        name: name,
        email: email?.trim().isEmpty == true ? null : email,
        phone: phone?.trim(),
        password: password,
      );
      setState(() {
        _pendingUserId = res['userId']?.toString() ?? _pendingUserId;
        _pendingPhone = res['phone']?.toString() ?? _pendingPhone;
      });
      final message =
          res['message']?.toString() ??
          'تم إنشاء الحساب. أدخل رمز التحقق المرسل لجوالك.';
      _showDesignMessage(message);
    } catch (_) {
      setState(() {
        _authError = 'تعذر إنشاء الحساب. تأكد من البيانات أو الخادم.';
      });
    } finally {
      if (mounted) setState(() => _authSubmitting = false);
    }
  }

  Future<void> _handleVerify({
    required String userId,
    required String code,
  }) async {
    setState(() {
      _authSubmitting = true;
      _authError = null;
    });
    try {
      final session = await _api.verifySms(userId: userId, code: code);
      _api.setToken(session.token);
      await _persistSession(session);
      if (!mounted) return;
      setState(() {
        _user = session.user;
        _pendingUserId = null;
        _pendingPhone = null;
      });
      await Future.wait([
        _loadFavorites(),
        _loadCart(),
        _loadProfile(),
        _loadOrders(),
      ]);
      if (mounted) _showDesignMessage('تم التوثيق وتسجيل الدخول بنجاح');
    } catch (_) {
      if (mounted) {
        setState(() {
          _authError = 'رمز غير صحيح أو منتهي. أعد المحاولة.';
        });
      }
    } finally {
      if (mounted) setState(() => _authSubmitting = false);
    }
  }

  Future<void> _handleSendSms({String? userId, String? phone}) async {
    try {
      await _api.sendSmsCode(userId: userId, phone: phone);
      _showDesignMessage('أرسلنا رمز تحقق إن كان الحساب موجودًا.');
    } catch (_) {
      _showDesignMessage('تعذر إرسال الرمز. حاول لاحقًا.');
    }
  }

  List<ProductItem> get _allProducts =>
      _products.isNotEmpty ? _products : [...suggestedProducts, ...newArrivals];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _restoreSession();
    await Future.wait([
      _loadProducts(),
      _loadFavorites(),
      _loadCart(),
      _loadProfile(),
      _loadOrders(),
    ]);
  }

  Future<void> _restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final userJson = prefs.getString('user_json');
    if (token != null && token.isNotEmpty) {
      _api.setToken(token);
    }
    if (userJson != null) {
      try {
        final decoded = jsonDecode(userJson) as Map<String, dynamic>;
        _user = UserProfile.fromJson(decoded);
      } catch (_) {}
    }
    setState(() {});
  }

  Future<void> _persistSession(ApiSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', session.token);
    await prefs.setString('user_json', jsonEncode(session.user.toJson()));
  }

  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('user_json');
  }

  void _showDesignMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _loadProducts() async {
    setState(() {
      _loadingProducts = true;
      _productsError = null;
    });
    try {
      final data = await _api.fetchProducts(limit: 500);
      setState(() {
        _products = data;
      });
      _buildCategories();
    } catch (e) {
      setState(() {
        _productsError = 'تعذر تحميل المنتجات، تم استخدام بيانات محلية.';
        _products = [];
      });
    } finally {
      if (mounted) {
        setState(() => _loadingProducts = false);
      }
    }
  }

  Future<void> _loadFavorites() async {
    if (_user == null) return;
    setState(() => _loadingFavorites = true);
    try {
      final favorites = await _api.fetchFavorites();
      setState(() {
        _favoriteIds
          ..clear()
          ..addAll(favorites.map((p) => p.id));
      });
    } catch (_) {
      // fallback to local state
    } finally {
      if (mounted) setState(() => _loadingFavorites = false);
    }
  }

  Future<void> _loadCart() async {
    if (_user == null) return;
    setState(() => _loadingCart = true);
    try {
      final items = await _api.fetchCart();
      setState(() {
        _cart
          ..clear()
          ..addAll(items);
      });
    } catch (_) {
      // ignore and keep local cart
    } finally {
      if (mounted) setState(() => _loadingCart = false);
    }
  }

  Future<void> _loadProfile() async {
    if (_user == null) return;
    setState(() => _loadingProfile = true);
    try {
      final profile = await _api.me();
      setState(() => _user = profile);
    } catch (_) {
      // keep old profile
    } finally {
      if (mounted) setState(() => _loadingProfile = false);
    }
  }

  Future<void> _loadOrders() async {
    if (_user == null) return;
    setState(() {
      _loadingOrders = true;
      _ordersError = null;
    });
    try {
      final data = await _api.fetchOrders();
      setState(() {
        _orders = data;
      });
    } catch (_) {
      setState(() {
        _ordersError = 'تعذر تحميل الطلبات';
      });
    } finally {
      if (mounted) setState(() => _loadingOrders = false);
    }
  }

  void _openCategory(CategoryNode node) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _CategoriesPage(
          categories: _categories,
          initialMain: node.main,
          products: _allProducts,
          onAddToCart: _addToCart,
          onToggleFavorite: _toggleFavorite,
          isFavorite: _isFavorite,
          api: _api,
          onViewProduct: (product) => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ProductDetailsPage(
                product: product,
                onAddToCart: _addToCart,
                api: _api,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _buildCategories() {
    final map = <String, Set<String>>{};
    for (final p in _allProducts) {
      final main = p.mainCategory?.trim();
      final sub = p.subCategory?.trim();
      if (main == null || main.isEmpty) continue;
      map.putIfAbsent(main, () => <String>{});
      if (sub != null && sub.isNotEmpty) {
        map[main]!.add(sub);
      }
    }

    final imageLookup = {for (final c in categories) c.value: c.image};

    final nodes =
        map.entries
            .map(
              (e) => CategoryNode(
                main: e.key,
                subs: e.value.toList()..sort(),
                image: imageLookup[e.key],
              ),
            )
            .toList()
          ..sort((a, b) => a.main.compareTo(b.main));

    if (nodes.isEmpty) {
      for (final c in categories) {
        nodes.add(CategoryNode(main: c.value, subs: [], image: c.image));
      }
    }

    setState(() {
      _categories = nodes;
    });
  }

  void _addToCart(ProductItem product) {
    if (_user != null) {
      _api.addToCart(product.id).catchError((_) => null);
    }
    setState(() {
      final index = _cart.indexWhere((item) => item.product.id == product.id);
      if (index >= 0) {
        _cart[index] = _cart[index].copyWith(
          quantity: _cart[index].quantity + 1,
        );
      } else {
        _cart.add(CartItem(product: product, quantity: 1));
      }
    });
    _showDesignMessage('أُضيف ${product.name} إلى السلة');
  }

  void _incrementCart(CartItem item) {
    _addToCart(item.product);
  }

  void _decrementCart(CartItem item) {
    setState(() {
      final index = _cart.indexWhere(
        (cartItem) => cartItem.product.id == item.product.id,
      );
      if (index >= 0) {
        final updated = _cart[index].quantity - 1;
        if (updated <= 0) {
          _cart.removeAt(index);
        } else {
          _cart[index] = _cart[index].copyWith(quantity: updated);
        }
      }
    });
  }

  void _goToCart() {
    setState(() => _navIndex = 3);
  }

  bool _isFavorite(ProductItem product) => _favoriteIds.contains(product.id);

  void _toggleFavorite(ProductItem product) {
    if (_user != null) {
      _api.toggleFavorite(product.id).catchError((_) => null);
    }
    setState(() {
      if (_favoriteIds.contains(product.id)) {
        _favoriteIds.remove(product.id);
        _showDesignMessage('أزيل ${product.name} من المفضلة');
      } else {
        _favoriteIds.add(product.id);
        _showDesignMessage('أُضيف ${product.name} إلى المفضلة');
      }
    });
  }

  Future<void> _handleLogin(String phone, String password) async {
    if (phone.isEmpty || password.isEmpty) {
      setState(() {
        _authError = 'أدخل رقم الجوال وكلمة المرور';
        _authSubmitting = false;
      });
      return;
    }
    setState(() {
      _authSubmitting = true;
      _authError = null;
    });
    try {
      final session = await _api.login(phone: phone, password: password);
      _api.setToken(session.token);
      await _persistSession(session);
      if (!mounted) return;
      setState(() => _user = session.user);
      await Future.wait([
        _loadFavorites(),
        _loadCart(),
        _loadProfile(),
        _loadOrders(),
      ]);
      if (mounted) _showDesignMessage('تم تسجيل الدخول بنجاح');
    } catch (e) {
      if (mounted) {
        if (e is ApiException && e.status == 403) {
          setState(() {
            _pendingUserId = e.data?['userId']?.toString() ?? _pendingUserId;
            _pendingPhone = e.data?['phone']?.toString() ?? _pendingPhone;
            _authError = e.message;
          });
        } else {
          setState(() {
            _authError = 'تعذر تسجيل الدخول. تأكد من البيانات أو الخادم.';
          });
        }
      }
    } finally {
      if (mounted) setState(() => _authSubmitting = false);
    }
  }

  Future<void> _logout() async {
    await _clearSession();
    _api.setToken(null);
    setState(() {
      _user = null;
      _favoriteIds.clear();
      _cart.clear();
    });
    _showDesignMessage('تم تسجيل الخروج');
  }

  Future<void> _openAuthSheet({_AuthMode mode = _AuthMode.login}) async {
    setState(() {
      _authError = null;
      _authSubmitting = false;
    });
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController(text: _pendingPhone ?? '');
    final passwordController = TextEditingController();
    final codeController = TextEditingController();
    final userIdController = TextEditingController(text: _pendingUserId ?? '');

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        var currentMode = mode;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            void switchMode(_AuthMode next) {
              setSheetState(() {
                currentMode = next;
                _authError = null;
              });
            }

            Widget buildActions() {
              if (currentMode == _AuthMode.login) {
                return ElevatedButton(
                  onPressed: _authSubmitting
                      ? null
                      : () async {
                          final navigator = Navigator.of(context);
                          await _handleLogin(
                            phoneController.text.trim(),
                            passwordController.text.trim(),
                          );
                          setSheetState(() {});
                          if (!_authSubmitting &&
                              _authError == null &&
                              mounted) {
                            navigator.pop();
                          }
                        },
                  child: _authSubmitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('دخول'),
                );
              }

              if (currentMode == _AuthMode.register) {
                return ElevatedButton(
                  onPressed: _authSubmitting
                      ? null
                      : () async {
                          await _handleRegister(
                            name: nameController.text.trim(),
                            email: emailController.text.trim(),
                            phone: phoneController.text.trim(),
                            password: passwordController.text.trim(),
                          );
                          setSheetState(() {
                            if (_pendingUserId != null) {
                              currentMode = _AuthMode.verify;
                            }
                          });
                        },
                  child: _authSubmitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('إنشاء حساب'),
                );
              }

              // Verify mode
              return ElevatedButton(
                onPressed: _authSubmitting
                    ? null
                    : () async {
                        final navigator = Navigator.of(context);
                        final userId =
                            _pendingUserId ?? userIdController.text.trim();
                        await _handleVerify(
                          userId: userId,
                          code: codeController.text.trim(),
                        );
                        setSheetState(() {});
                        if (!_authSubmitting && _authError == null && mounted) {
                          navigator.pop();
                        }
                      },
                child: _authSubmitting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('تأكيد الرمز'),
              );
            }

            String title;
            switch (currentMode) {
              case _AuthMode.register:
                title = 'إنشاء حساب جديد';
                break;
              case _AuthMode.verify:
                title = 'توثيق رقم الجوال';
                break;
              case _AuthMode.login:
                title = 'تسجيل الدخول';
            }

            return Directionality(
              textDirection: TextDirection.rtl,
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                      textAlign: TextAlign.right,
                    ),
                    const SizedBox(height: 12),
                    if (currentMode == _AuthMode.register)
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: 'الاسم'),
                      ),
                    if (currentMode != _AuthMode.verify) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'رقم الجوال',
                        ),
                      ),
                      if (currentMode == _AuthMode.register) ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'البريد الإلكتروني (اختياري)',
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextField(
                        controller: passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'كلمة المرور',
                        ),
                      ),
                    ],
                    if (currentMode == _AuthMode.verify) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: userIdController,
                        decoration: const InputDecoration(
                          labelText: 'معرّف المستخدم',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: codeController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'رمز التحقق',
                        ),
                      ),
                      TextButton(
                        onPressed: () => _handleSendSms(
                          userId: userIdController.text.trim().isNotEmpty
                              ? userIdController.text.trim()
                              : _pendingUserId,
                          phone: phoneController.text.trim().isNotEmpty
                              ? phoneController.text.trim()
                              : _pendingPhone,
                        ),
                        child: const Text('إعادة إرسال الرمز'),
                      ),
                    ],
                    if (_authError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _authError!,
                        style: TextStyle(color: Colors.red.shade700),
                        textAlign: TextAlign.right,
                      ),
                    ],
                    const SizedBox(height: 16),
                    buildActions(),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: currentMode == _AuthMode.login
                              ? () => switchMode(_AuthMode.register)
                              : () => switchMode(_AuthMode.login),
                          child: Text(
                            currentMode == _AuthMode.login
                                ? 'مستخدم جديد؟ أنشئ حسابًا'
                                : 'لديك حساب؟ تسجيل الدخول',
                          ),
                        ),
                        TextButton(
                          onPressed: () => switchMode(_AuthMode.verify),
                          child: const Text('لدي رمز تحقق'),
                        ),
                      ],
                    ),
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
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: _buildAppBar(context),
        body: SafeArea(child: _buildBody()),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _navIndex,
          height: 72,
          indicatorColor: Colors.black,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'الرئيسية',
            ),
            NavigationDestination(
              icon: Icon(Icons.grid_view_outlined),
              selectedIcon: Icon(Icons.grid_view_rounded),
              label: 'المنتجات',
            ),
            NavigationDestination(
              icon: Icon(Icons.favorite_outline),
              selectedIcon: Icon(Icons.favorite),
              label: 'مفضلة',
            ),
            NavigationDestination(
              icon: Icon(Icons.shopping_cart_outlined),
              selectedIcon: Icon(Icons.shopping_cart),
              label: 'السلة',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'حسابي',
            ),
          ],
          onDestinationSelected: (value) {
            setState(() => _navIndex = value);
          },
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_navIndex) {
      case 0:
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: _HomeContent(
                onAddToCart: _addToCart,
                isFavorite: _isFavorite,
                onToggleFavorite: _toggleFavorite,
                onBrowseAll: () => setState(() => _navIndex = 1),
                categories: _categories,
                onCategorySelected: _openCategory,
                products: _allProducts,
                isLoading: _loadingProducts,
                errorText: _productsError,
                onViewProduct: (product) => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ProductDetailsPage(
                      product: product,
                      onAddToCart: _addToCart,
                      api: _api,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      case 1:
        return _ProductsPage(
          products: _allProducts,
          onAddToCart: _addToCart,
          onToggleFavorite: _toggleFavorite,
          isFavorite: _isFavorite,
          loading: _loadingProducts,
          errorText: _productsError,
          onRetry: _loadProducts,
          onViewProduct: (product) => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ProductDetailsPage(
                product: product,
                onAddToCart: _addToCart,
                api: _api,
              ),
            ),
          ),
        );
      case 2:
        if (_user == null) {
          return _PlaceholderPage(
            title: 'سجّل الدخول',
            description: 'تسجيل الدخول يتيح حفظ المفضلة ومزامنتها.',
            icon: Icons.favorite_border,
          );
        }
        if (_loadingFavorites) {
          return const Center(child: CircularProgressIndicator());
        }
        return _FavoritesPage(
          products: _allProducts.where(_isFavorite).toList(),
          onRemove: _toggleFavorite,
          onAddToCart: _addToCart,
          onViewProduct: (product) => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ProductDetailsPage(
                product: product,
                onAddToCart: _addToCart,
                api: _api,
              ),
            ),
          ),
        );
      case 3:
        if (_loadingCart) {
          return const Center(child: CircularProgressIndicator());
        }
        return _CartPage(
          items: _cart,
          onIncrement: _incrementCart,
          onDecrement: _decrementCart,
          onCheckout: () => _showDesignMessage('إتمام الشراء قادم قريبًا'),
        );
      case 4:
        return _AccountPage(
          user: _user,
          loading: _loadingProfile || _authSubmitting,
          onLogin: () => _openAuthSheet(mode: _AuthMode.login),
          onRegister: () => _openAuthSheet(mode: _AuthMode.register),
          onLogout: _logout,
          orders: _orders,
          loadingOrders: _loadingOrders,
          ordersError: _ordersError,
          onRefreshOrders: _loadOrders,
        );
      default:
        return const _PlaceholderPage(
          title: 'قريبًا',
          description: 'سيتم تفعيل هذه الصفحة في الإصدار القادم.',
        );
    }
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      titleSpacing: 0,
      title: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Container(
              height: 42,
              width: 42,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text(
                  'D',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'ديكوري',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            IconButton(
              tooltip: 'الإشعارات',
              onPressed: () {
                _showDesignMessage('الإشعارات غير مفعلة في هذا النموذج');
              },
              icon: const Icon(Icons.notifications_none),
            ),
            IconButton(
              tooltip: 'السلة',
              onPressed: _goToCart,
              icon: const Icon(Icons.shopping_bag_outlined),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 8, right: 12),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
                onPressed: () => _showDesignMessage('تسجيل الدخول قادم قريبًا'),
                child: const Text('تسجيل الدخول'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({
    required this.onAddToCart,
    required this.onViewProduct,
    required this.onToggleFavorite,
    required this.isFavorite,
    required this.products,
    required this.isLoading,
    required this.errorText,
    required this.onBrowseAll,
    required this.categories,
    required this.onCategorySelected,
  });

  final void Function(ProductItem product) onAddToCart;
  final void Function(ProductItem product) onViewProduct;
  final void Function(ProductItem product) onToggleFavorite;
  final bool Function(ProductItem product) isFavorite;
  final List<ProductItem> products;
  final bool isLoading;
  final String? errorText;
  final VoidCallback onBrowseAll;
  final List<CategoryNode> categories;
  final void Function(CategoryNode node) onCategorySelected;

  @override
  Widget build(BuildContext context) {
    final primaryList = products.isNotEmpty ? products : suggestedProducts;
    final secondaryList = products.length > 8
        ? products.sublist(0, 8)
        : newArrivals;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HeroSection(
          onStartShopping: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('يتم عرض الشكل فقط حاليًا، سنضيف التصفح قريبًا'),
            ),
          ),
        ),
        const SizedBox(height: 16),
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
          onToggleFavorite: onToggleFavorite,
          isFavorite: isFavorite,
          isLoading: isLoading,
          errorText: errorText,
          onBrowseAll: onBrowseAll,
        ),
        const SizedBox(height: 24),
        _ProductsSection(
          title: 'وصل حديثًا',
          products: secondaryList,
          onViewProduct: onViewProduct,
          onAddToCart: onAddToCart,
          onToggleFavorite: onToggleFavorite,
          isFavorite: isFavorite,
          isLoading: isLoading,
          errorText: errorText,
          onBrowseAll: onBrowseAll,
        ),
        const SizedBox(height: 32),
        const _Footer(),
      ],
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({required this.onStartShopping});

  final VoidCallback onStartShopping;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          heroTitle,
          textAlign: TextAlign.right,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 32,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          heroSubtitle,
          textAlign: TextAlign.right,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Colors.grey.shade700,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton(
            onPressed: onStartShopping,
            child: const Text('ابدأ التسوّق الآن'),
          ),
        ),
      ],
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
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 0.8,
              ),
              itemCount: list.length,
              itemBuilder: (context, index) {
                final category = list[index];
                return _CategoryCard(
                  category: category,
                  onTap: () => onSelect(category),
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
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade200),
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
                    child: Image.network(
                      category.image ??
                          'https://placehold.co/200x200/png?text=Category',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.grey.shade100,
                        child: const Icon(Icons.image_not_supported_outlined),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              category.main,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
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
                childAspectRatio: 1.3,
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
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Icon(_iconForBenefit(), color: Colors.black),
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
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700),
              textAlign: TextAlign.right,
            ),
          ],
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

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.6,
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
                  onAdd: () => onAddToCart(product),
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
  });

  final List<ProductItem> products;
  final void Function(ProductItem) onAddToCart;
  final void Function(ProductItem) onToggleFavorite;
  final bool Function(ProductItem) isFavorite;
  final void Function(ProductItem) onViewProduct;
  final bool loading;
  final String? errorText;
  final Future<void> Function()? onRetry;

  @override
  State<_ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<_ProductsPage> {
  static const int _pageSize = 8;
  int _page = 0;

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
  Widget build(BuildContext context) {
    final isLoading = widget.loading;
    final totalPages = (isLoading || widget.products.isEmpty)
        ? 1
        : (widget.products.length / _pageSize).ceil();
    final safePage = _page.clamp(0, (totalPages - 1).clamp(0, totalPages - 1));
    final start = safePage * _pageSize;
    final currentProducts = isLoading
        ? <ProductItem>[]
        : widget.products.skip(start).take(_pageSize).toList();

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
                _ProductsSection(
                  title: 'جميع العناصر',
                  products: currentProducts,
                  onViewProduct: widget.onViewProduct,
                  onAddToCart: widget.onAddToCart,
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

  @override
  void initState() {
    super.initState();
    _selectedMain =
        widget.initialMain ??
        (widget.categories.isNotEmpty ? widget.categories.first.main : null);
  }

  List<ProductItem> get _filteredProducts {
    return widget.products.where((p) {
      if (_selectedMain != null && (p.mainCategory ?? '') != _selectedMain) {
        return false;
      }
      if (_selectedSub != null && _selectedSub!.isNotEmpty) {
        if ((p.subCategory ?? '') != _selectedSub) return false;
      }
      return true;
    }).toList();
  }

  List<String> get _subsForMain {
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
                Text(
                  'اختر فئة',
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
                  children: widget.categories
                      .map(
                        (c) => ChoiceChip(
                          label: Text(c.main),
                          selected: _selectedMain == c.main,
                          onSelected: (_) {
                            setState(() {
                              _selectedMain = c.main;
                              _selectedSub = null;
                            });
                          },
                        ),
                      )
                      .toList(),
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
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.end,
                    children: _subsForMain
                        .map(
                          (s) => ChoiceChip(
                            label: Text(s),
                            selected: _selectedSub == s,
                            onSelected: (_) {
                              setState(() {
                                _selectedSub = s;
                              });
                            },
                          ),
                        )
                        .toList(),
                  ),
                ],
                const SizedBox(height: 12),
                _ProductsSection(
                  title: 'المنتجات',
                  products: _filteredProducts,
                  onViewProduct: widget.onViewProduct,
                  onAddToCart: widget.onAddToCart,
                  onToggleFavorite: widget.onToggleFavorite,
                  isFavorite: widget.isFavorite,
                  isLoading:
                      widget.products.isEmpty && widget.categories.isEmpty,
                  errorText: null,
                  emptyMessage: 'لا توجد منتجات في هذا التصنيف.',
                  onBrowseAll: null,
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
    return InkWell(
      onTap: onView,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 3 / 4,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Image.network(
                            product.image,
                            fit: BoxFit.cover,
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
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700),
                  textAlign: TextAlign.right,
                )
              else
                Text(
                  'السعر عند الاختيار',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700),
                  textAlign: TextAlign.right,
                ),
              const Spacer(),
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
  }
}

class _ProductSkeleton extends StatelessWidget {
  const _ProductSkeleton();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
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
  }
}

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
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: 4 / 5,
                  child: Image.network(
                    image,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.image_not_supported_outlined),
                    ),
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
                      onPressed: () {
                        final toAdd = _selected != null
                            ? ProductItem(
                                id: widget.product.id,
                                name: widget.product.name,
                                price: displayPrice,
                                image: image,
                                description: widget.product.description,
                                variantLabel: _selected != null
                                    ? '${_selected!.measure} • ${_selected!.colorName}'
                                    : null,
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

class _FavoritesPage extends StatelessWidget {
  const _FavoritesPage({
    required this.products,
    required this.onRemove,
    required this.onAddToCart,
    required this.onViewProduct,
  });

  final List<ProductItem> products;
  final void Function(ProductItem) onRemove;
  final void Function(ProductItem) onAddToCart;
  final void Function(ProductItem) onViewProduct;

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

class _CartPage extends StatelessWidget {
  const _CartPage({
    required this.items,
    required this.onIncrement,
    required this.onDecrement,
    required this.onCheckout,
  });

  final List<CartItem> items;
  final void Function(CartItem) onIncrement;
  final void Function(CartItem) onDecrement;
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context) {
    final total = items.fold<double>(0, (sum, item) => sum + item.total);

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
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            height: 68,
                            width: 68,
                            color: Colors.grey.shade100,
                            child: Image.network(
                              item.product.image,
                              fit: BoxFit.cover,
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
                                    ?.copyWith(color: Colors.grey.shade700),
                                textAlign: TextAlign.right,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'المجموع: ${item.total.toStringAsFixed(2)} ₪',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: Colors.grey.shade600),
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
                            Text(
                              item.quantity.toString(),
                              style: Theme.of(context).textTheme.titleMedium,
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
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
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
                    onPressed: onCheckout,
                    child: const Text('إتمام الشراء'),
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

class _PlaceholderPage extends StatelessWidget {
  const _PlaceholderPage({
    required this.title,
    required this.description,
    this.icon = Icons.hourglass_empty,
  });

  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 64, color: Colors.grey.shade500),
              const SizedBox(height: 12),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountPage extends StatelessWidget {
  const _AccountPage({
    required this.user,
    required this.loading,
    required this.onLogin,
    required this.onRegister,
    required this.onLogout,
    required this.orders,
    required this.loadingOrders,
    required this.ordersError,
    required this.onRefreshOrders,
  });

  final UserProfile? user;
  final bool loading;
  final Future<void> Function() onLogin;
  final Future<void> Function() onRegister;
  final Future<void> Function() onLogout;
  final List<OrderSummary> orders;
  final bool loadingOrders;
  final String? ordersError;
  final Future<void> Function() onRefreshOrders;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'حسابي',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              textAlign: TextAlign.right,
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      user != null ? 'مرحبا، ${user!.name}' : 'مرحبا بعودتك',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      user != null
                          ? 'يمكنك متابعة طلباتك وحالة الشحن مباشرة.'
                          : 'سجّل الدخول لمراجعة طلباتك ومتابعة الشحن.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade700,
                      ),
                      textAlign: TextAlign.right,
                    ),
                    const SizedBox(height: 12),
                    if (loading)
                      const Center(child: CircularProgressIndicator())
                    else if (user == null)
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: onLogin,
                              child: const Text('تسجيل الدخول'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: onRegister,
                              child: const Text('إنشاء حساب'),
                            ),
                          ),
                        ],
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: onLogout,
                              child: const Text('تسجيل الخروج'),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: user != null ? onRefreshOrders : null,
                          icon: const Icon(Icons.refresh),
                          label: const Text('تحديث'),
                        ),
                        const Spacer(),
                        Text(
                          'طلباتي',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (user == null)
                      Text(
                        'سجّل الدخول لعرض طلباتك.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade700,
                        ),
                      )
                    else if (loadingOrders)
                      const Center(child: CircularProgressIndicator())
                    else if (ordersError != null)
                      Text(
                        ordersError!,
                        style: TextStyle(color: Colors.red.shade700),
                        textAlign: TextAlign.right,
                      )
                    else if (orders.isEmpty)
                      Text(
                        'لا توجد طلبات حالية.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade700,
                        ),
                      )
                    else
                      Column(
                        children: orders.take(5).map((order) {
                          final shortId = order.id.length > 6
                              ? order.id.substring(order.id.length - 6)
                              : order.id;
                          final date = order.createdAt.toLocal();
                          final dateLabel =
                              '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                          return Column(
                            children: [
                              Row(
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        'الطلب #$shortId',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'المجموع: ${order.total.toStringAsFixed(2)} ₪ — ${order.itemsCount} عنصر',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: Colors.grey.shade700,
                                            ),
                                      ),
                                      Text(
                                        'الحالة: ${order.status}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: Colors.grey.shade600,
                                            ),
                                      ),
                                    ],
                                  ),
                                  const Spacer(),
                                  Text(
                                    dateLabel,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                              const Divider(height: 20),
                            ],
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'الخدمات السريعة',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.end,
                      children: const [
                        _AccountChip(icon: Icons.receipt_long, label: 'طلباتي'),
                        _AccountChip(
                          icon: Icons.location_on_outlined,
                          label: 'عناويني',
                        ),
                        _AccountChip(icon: Icons.payment, label: 'طرق الدفع'),
                        _AccountChip(
                          icon: Icons.support_agent,
                          label: 'الدعم الفني',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountChip extends StatelessWidget {
  const _AccountChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      showCheckmark: false,
      selected: false,
      onSelected: (_) {},
      avatar: Icon(icon, size: 18),
      label: Text(label),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const Spacer(),
        if (action != null) action!,
      ],
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    final year = DateTime.now().year;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Divider(height: 32),
        Text(
          'جميع الحقوق محفوظة © $year متجر ديكوري',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700),
        ),
        const SizedBox(height: 8),
        Text(
          'للتواصل معنا: 0597 000 000',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700),
        ),
        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          children: [
            TextButton(onPressed: () {}, child: const Text('سياسة الخصوصية')),
            TextButton(onPressed: () {}, child: const Text('الشروط والأحكام')),
            TextButton(
              onPressed: () {},
              child: const Text('سياسة الإرجاع والاستبدال'),
            ),
          ],
        ),
      ],
    );
  }
}
