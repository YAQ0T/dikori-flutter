part of '../../main.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

enum _AuthMode { login, register, verify }

// Icons used in التصنيفات page; update values as needed.
const Map<String, IconData> kCategoryIcons = {
  'لوازم نجارين': Icons.handyman,
  'لوازم منجدين': Icons.chair_alt,
  'مقابض أبواب': Icons.meeting_room_outlined,
  'مقابض خزائن': Icons.kitchen_outlined,
  'اكسسوارات مطابخ': Icons.restaurant_menu,
  'اكسسوارات غرف نوم': Icons.bed_outlined,
  'عدة وأدوات': Icons.build_circle_outlined,
  'جوارير وسكك ومفصلات': Icons.storage_outlined,
  'أقمشة كنب': Icons.texture,
  'كبسات مسامير و براغي': Icons.hardware,
  'لوازم أبواب': Icons.door_back_door_outlined,
};

// Icons used for subcategories; add or override as needed.
const Map<String, IconData> kSubcategoryIcons = {
  'default': Icons.label_important_outline,
  // مشتركة بين أكثر من قسم.
  'أزرار': Icons.radio_button_checked,
  'زوايا': Icons.crop_square,
  'مفصلات': Icons.link,
  'جوارير': Icons.storage_outlined,
  'سلات': Icons.shopping_basket,
  'علاقات': Icons.checkroom,
  // مقابض خزائن
  'يد مخفي': Icons.horizontal_rule,
  'يد عادي': Icons.drag_handle,
  // مقابض أبواب
  'مقابض أبواب عادي': Icons.door_front_door_outlined,
  'مقابض ابواب مع سكرة كامل': Icons.lock_outline,
  'مقابض بوابات وباب سحاب': Icons.door_sliding_outlined,
  'يد باب مع شمسة': Icons.circle_outlined,
  // لوازم نجارين
  'أرجل طاولات': Icons.table_bar,
  'بروفيلات': Icons.straighten,
  'بلاستيكيات': Icons.layers_outlined,
  'خشبيات': Icons.nature,
  'دقرات': Icons.circle,
  'طقات': Icons.toggle_on,
  'عجال وجسور': Icons.tire_repair,
  'كنت': Icons.curtains,
  'مجابد وجكات تخوت': Icons.bed_outlined,
  'مواد جانبية': Icons.extension,
  // لوازم منجدين
  'أرجل كنب': Icons.event_seat,
  'حبال': Icons.cable,
  'قشاط و زك زاك وبريم': Icons.line_style,
  'لوازم كراسي و جكات': Icons.chair_alt,
  'مستلزمات': Icons.inventory_2_outlined,
  'مشابك': Icons.attach_file,
  // لوازم المنيوم
  'بلاستيكيات للالمنيوم': Icons.layers_outlined,
  'جكات': Icons.build,
  'سكاكر المنيوم': Icons.lock_outline,
  'عجال': Icons.tire_repair,
  // لوازم أبواب
  'جكات أبواب وجرارات حفر': Icons.door_front_door_outlined,
  'سكاركر وسيليندرات': Icons.lock,
  // كبسات مسامير و براغي
  'براغي': Icons.hardware,
  'كبسات': Icons.push_pin,
  // عدة وأدوات
  'أدوات حف': Icons.construction,
  'أدوات ومستلزمات': Icons.handyman,
  'ريش وبوز شد': Icons.build_circle_outlined,
  'شركات متفرقة': Icons.business,
  'صواني قص': Icons.content_cut,
  'فرود': Icons.blur_circular,
  'كمبريصة': Icons.air,
  'CNCs': Icons.precision_manufacturing,
  'Dewalt': Icons.build,
  'Makita': Icons.build_circle,
  'Total': Icons.construction,
  // جوارير وسكك ومفصلات
  'سكك': Icons.view_stream,
  // اكسسوارات مطابخ
  'تسوكل': Icons.border_bottom,
  'جكات مطابخ': Icons.kitchen_outlined,
};

class _HomePageState extends State<HomePage> {
  int _navIndex = 0;
  String? _pendingCategoryMain;
  final ApiClient _api = ApiClient(baseUrl: kDefaultApiBase);
  final List<CartItem> _cart = [];
  final Set<String> _favoriteIds = {
    ...suggestedProducts.take(2).map((p) => p.id),
  };

  List<ProductItem> _products = [];
  List<ProductItem> _recommendedProducts = [];
  List<ProductItem> _newArrivalProducts = [];
  bool _loadingProducts = true;
  String? _productsError;

  bool _loadingFavorites = false;
  bool _loadingCart = false;
  bool _placingOrder = false;

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
  List<CategoryNode> _homeCategories = [];
  SiteSettingsData? _siteSettings;
  SiteAdData? _siteAd;
  bool _showingSiteAdDialog = false;
  bool _siteAdDismissedInView = false;
  String _siteAdViewToken = '';
  static final Set<String> _dismissedSiteAdSession = <String>{};
  List<AppNotification> _notifications = [];
  bool _loadingNotifications = false;
  String? _notificationsError;

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
        _loadNotifications(),
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

  String get _heroTitleText {
    final title = _siteSettings?.hero.title.preferred();
    return title != null && title.isNotEmpty ? title : heroTitle;
  }

  String get _heroKickerText {
    final kicker = _siteSettings?.hero.kicker.preferred();
    return kicker != null && kicker.isNotEmpty ? kicker : 'ديكوري';
  }

  String get _heroSubtitleText {
    final subtitle = _siteSettings?.hero.subtitle.preferred();
    return subtitle != null && subtitle.isNotEmpty ? subtitle : heroSubtitle;
  }

  String get _heroPrimaryCtaText {
    final cta = _siteSettings?.hero.primaryCtaLabel.preferred();
    return cta != null && cta.isNotEmpty ? cta : 'ابدأ التسوّق الآن';
  }

  String get _heroSecondaryCtaText {
    final cta = _siteSettings?.hero.secondaryCtaLabel.preferred();
    return cta != null && cta.isNotEmpty ? cta : 'تصفّح الفئات';
  }

  String get _heroCalloutLabelText {
    final callout = _siteSettings?.hero.calloutLabel.preferred();
    return callout != null && callout.isNotEmpty ? callout : 'ثقة العملاء';
  }

  String get _heroCalloutValueText {
    final callout = _siteSettings?.hero.calloutValue.preferred();
    return callout != null && callout.isNotEmpty ? callout : 'منتجات أصلية 100٪';
  }

  String get _heroImageUrl {
    final imageUrl = _siteSettings?.hero.imageUrl.trim();
    if (imageUrl != null && imageUrl.isNotEmpty) return imageUrl;

    for (final node in _homeCategories) {
      final image = node.image?.trim() ?? '';
      if (image.isNotEmpty) return image;
    }
    for (final c in categories) {
      if (c.image.trim().isNotEmpty) return c.image;
    }
    return 'https://placehold.co/900x1125/png?text=Hero';
  }

  int get _unreadNotificationsCount =>
      _notifications.where((n) => !n.isRead).length;

  bool get _isCustomerView {
    final role = (_user?.role ?? '').trim().toLowerCase();
    return role != 'admin' && role != 'dealer';
  }

  String _localizedSiteText(SiteLocalizedText text, {String fallback = ''}) {
    final languageCode = Localizations.localeOf(context).languageCode;
    final localized = text.preferred(locale: languageCode);
    if (localized.isNotEmpty) return localized;
    return fallback;
  }

  void _resetSiteAdViewIfNeeded() {
    final dismissKey = _siteAd?.dismissKey ?? '';
    final nextViewToken = 'tab:$_navIndex|$dismissKey';
    if (_siteAdViewToken != nextViewToken) {
      _siteAdViewToken = nextViewToken;
      _siteAdDismissedInView = false;
    }
  }

  void _dismissSiteAd({required SiteAdData ad}) {
    if (ad.showMode == SiteAdShowMode.oncePerSession &&
        ad.dismissKey.isNotEmpty) {
      _dismissedSiteAdSession.add(ad.dismissKey);
    }
    _siteAdDismissedInView = true;
  }

  Future<void> _openSiteAdUrl(String urlValue) async {
    final urlText = urlValue.trim();
    if (urlText.isEmpty) return;

    final uri = Uri.tryParse(urlText);
    if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) {
      _showDesignMessage('رابط الإعلان غير صالح.');
      return;
    }

    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        _showDesignMessage('تعذر فتح الرابط.');
      }
    } catch (_) {
      if (mounted) {
        _showDesignMessage('تعذر فتح الرابط.');
      }
    }
  }

  Future<void> _openSiteAdProduct(String productId) async {
    final id = productId.trim();
    if (id.isEmpty) return;

    ProductItem? product;
    for (final item in _allProducts) {
      if (item.id == id) {
        product = item;
        break;
      }
    }
    product ??= await _api.fetchProductById(id);

    if (!mounted) return;
    if (product == null) {
      _showDesignMessage('المنتج غير متوفر حاليًا.');
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductDetailsPage(
          product: product!,
          onAddToCart: _addToCart,
          api: _api,
        ),
      ),
    );
  }

  Future<void> _openSiteAdDialog(SiteAdData ad) async {
    final title = _localizedSiteText(ad.title, fallback: 'إعلان جديد');
    final bodyText = _localizedSiteText(ad.text);
    final hasAction =
        (ad.targetType == SiteAdTargetType.product ||
            ad.targetType == SiteAdTargetType.url) &&
        ad.targetValue.trim().isNotEmpty;
    final actionLabel = ad.targetType == SiteAdTargetType.product
        ? 'عرض المنتج'
        : 'فتح الرابط';

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        Future<void> closeOnly() async {
          Navigator.of(dialogContext).pop();
          _dismissSiteAd(ad: ad);
        }

        Future<void> handleAction() async {
          Navigator.of(dialogContext).pop();
          _dismissSiteAd(ad: ad);

          final value = ad.targetValue.trim();
          if (ad.targetType == SiteAdTargetType.product) {
            await _openSiteAdProduct(value);
            return;
          }
          if (ad.targetType == SiteAdTargetType.url) {
            await _openSiteAdUrl(value);
          }
        }

        return Directionality(
          textDirection: TextDirection.rtl,
          child: WillPopScope(
            onWillPop: () async {
              _dismissSiteAd(ad: ad);
              return true;
            },
            child: Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 22,
                vertical: 24,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (ad.imageUrl.trim().isNotEmpty)
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(22),
                          ),
                          child: AspectRatio(
                            aspectRatio: 16 / 10,
                            child: Image.network(
                              ad.imageUrl.trim(),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                    color: _appSoftSurface(context),
                                    child: const Icon(
                                      Icons.image_not_supported_outlined,
                                      size: 36,
                                    ),
                                  ),
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              title,
                              textAlign: TextAlign.right,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            if (bodyText.trim().isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                bodyText,
                                textAlign: TextAlign.right,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: _appMuted(context),
                                      height: 1.5,
                                    ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                OutlinedButton(
                                  onPressed: closeOnly,
                                  child: const Text('تخطي'),
                                ),
                                const SizedBox(width: 10),
                                if (hasAction)
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: handleAction,
                                      child: Text(actionLabel),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _maybeShowSiteAd() {
    if (!mounted || _showingSiteAdDialog) return;
    final ad = _siteAd;
    if (ad == null || !ad.enabled || !_isCustomerView) return;

    _resetSiteAdViewIfNeeded();

    if (_siteAdDismissedInView) return;
    if (ad.showMode == SiteAdShowMode.oncePerSession &&
        ad.dismissKey.isNotEmpty &&
        _dismissedSiteAdSession.contains(ad.dismissKey)) {
      return;
    }

    _showingSiteAdDialog = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        _showingSiteAdDialog = false;
        return;
      }
      await _openSiteAdDialog(ad);
      _showingSiteAdDialog = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _restoreSession();
    await Future.wait([
      _loadSiteSettings(),
      _loadSiteAd(),
      _loadProducts(),
      _loadHomeCollections(),
      _loadFavorites(),
      _loadCart(),
      _loadProfile(),
      _loadOrders(),
      _loadNotifications(),
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

  Future<void> _loadSiteSettings() async {
    try {
      final data = await _api.fetchSiteSettings();
      if (!mounted) return;
      setState(() {
        _siteSettings = data;
      });
    } catch (_) {
      // Keep static fallback values.
    } finally {
      _buildCategories();
    }
  }

  Future<void> _loadSiteAd() async {
    try {
      final data = await _api.fetchSiteAd();
      if (!mounted) return;
      setState(() {
        _siteAd = data;
      });
    } catch (_) {
      // Keep no-ad fallback.
    } finally {
      _maybeShowSiteAd();
    }
  }

  Future<void> _loadProducts() async {
    setState(() {
      _loadingProducts = true;
      _productsError = null;
    });
    try {
      final data = await _api.fetchProducts(limit: 500);
      if (!mounted) return;
      setState(() {
        _products = data;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _productsError = 'تعذر تحميل المنتجات، تم استخدام بيانات محلية.';
        _products = [];
      });
    } finally {
      _buildCategories();
      if (mounted) {
        setState(() => _loadingProducts = false);
      }
    }
  }

  Future<void> _loadHomeCollections() async {
    try {
      final results = await Future.wait<List<ProductItem>>([
        _api.fetchHomeRecommended(),
        _api.fetchHomeNewArrivals(),
      ]);
      if (!mounted) return;
      setState(() {
        _recommendedProducts = results[0];
        _newArrivalProducts = results[1];
      });
    } catch (_) {
      // Keep local fallback lists inside home sections.
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
      data.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (mounted) {
        setState(() {
          _orders = data;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _ordersError = 'تعذر تحميل الطلبات';
        });
      }
    } finally {
      if (mounted) setState(() => _loadingOrders = false);
    }
  }

  void _showOrderDetails(OrderSummary order) {
    String formatDate(DateTime date) {
      final local = date.toLocal();
      final dateLabel =
          '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
      final timeLabel =
          '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
      return '$dateLabel • $timeLabel';
    }

    final shortId = order.id.length > 6
        ? order.id.substring(order.id.length - 6)
        : order.id;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final bottom = MediaQuery.of(ctx).viewInsets.bottom;
        final items = order.items;
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, bottom + 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'تفاصيل الطلب #$shortId',
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.right,
                  ),
                  const SizedBox(height: 12),
                  _OrderDetailRow(label: 'المعرّف', value: order.id),
                  _OrderDetailRow(
                    label: 'التاريخ',
                    value: formatDate(order.createdAt),
                  ),
                  _OrderDetailRow(
                    label: 'الإجمالي',
                    value: '${order.total.toStringAsFixed(2)} ₪',
                  ),
                  _OrderDetailRow(
                    label: 'عدد العناصر',
                    value: order.itemsCount.toString(),
                  ),
                  _OrderDetailRow(label: 'الحالة', value: order.status),
                  const SizedBox(height: 16),
                  Text(
                    'عناصر الطلب',
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.right,
                  ),
                  const SizedBox(height: 8),
                  if (items.isEmpty)
                    Text(
                      'لا توجد عناصر في هذا الطلب.',
                      style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                        color: _appMuted(ctx),
                      ),
                      textAlign: TextAlign.right,
                    )
                  else
                    for (final item in items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _OrderLineItemTile(item: item),
                      ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('حسناً'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _openOrdersPage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _OrdersPage(
          ordersProvider: () => _orders,
          loadingProvider: () => _loadingOrders,
          ordersErrorProvider: () => _ordersError,
          onRefreshOrders: _loadOrders,
          onViewOrder: _showOrderDetails,
        ),
      ),
    );
  }

  Future<void> _loadNotifications({VoidCallback? onUpdated}) async {
    if (_user == null) {
      setState(() {
        _notifications = [];
        _notificationsError = null;
        _loadingNotifications = false;
      });
      onUpdated?.call();
      return;
    }
    setState(() {
      _loadingNotifications = true;
      _notificationsError = null;
    });
    try {
      final data = await _api.fetchNotifications();
      if (mounted) {
        setState(() {
          _notifications = data;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _notificationsError = 'تعذر تحميل الإشعارات';
        });
      }
    } finally {
      if (mounted) setState(() => _loadingNotifications = false);
      onUpdated?.call();
    }
  }

  Future<void> _markNotificationAsRead(
    String id, {
    VoidCallback? onUpdated,
  }) async {
    try {
      final updated = await _api.markNotificationRead(id);
      if (!mounted) return;
      setState(() {
        final index = _notifications.indexWhere((n) => n.id == id);
        if (index >= 0) {
          _notifications[index] =
              updated ?? _notifications[index].copyWith(isRead: true);
        }
      });
      onUpdated?.call();
    } catch (_) {
      // ignore errors for marking as read
    }
  }

  void _showCategories({String? initialMain}) {
    setState(() {
      _pendingCategoryMain = initialMain;
      _navIndex = 1;
    });
    _maybeShowSiteAd();
    if (initialMain != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_pendingCategoryMain == initialMain) {
          setState(() => _pendingCategoryMain = null);
        }
      });
    }
  }

  void _openCategory(CategoryNode node) {
    _showCategories(initialMain: node.main);
  }

  void _buildCategories() {
    final map = <String, Set<String>>{};
    final productMainImages = <String, String>{};
    final productSubImages = <String, Map<String, String>>{};
    for (final p in _allProducts) {
      final main = p.mainCategory?.trim();
      final sub = p.subCategory?.trim();
      if (main == null || main.isEmpty) continue;
      map.putIfAbsent(main, () => <String>{});
      final productImage = p.image.trim();
      if (productImage.isNotEmpty && !productMainImages.containsKey(main)) {
        productMainImages[main] = productImage;
      }
      if (sub != null && sub.isNotEmpty) {
        map[main]!.add(sub);
        if (productImage.isNotEmpty) {
          final byMain = productSubImages.putIfAbsent(main, () => <String, String>{});
          byMain.putIfAbsent(sub, () => productImage);
        }
      }
    }

    final settings = _siteSettings;
    final homeItems = settings?.sortedHomeCategories ?? const <SiteCategoryItem>[];
    final menuMainItems =
        settings?.sortedCategoryMenuMain ?? const <SiteCategoryItem>[];
    final menuSubItems =
        settings?.sortedCategoryMenuSub ?? const <SiteSubCategoryItem>[];

    for (final item in homeItems) {
      if (item.value.isNotEmpty) {
        map.putIfAbsent(item.value, () => <String>{});
      }
    }

    for (final item in menuMainItems) {
      if (item.value.isNotEmpty) {
        map.putIfAbsent(item.value, () => <String>{});
      }
    }

    for (final item in menuSubItems) {
      if (item.main.isEmpty || item.value.isEmpty) continue;
      map.putIfAbsent(item.main, () => <String>{});
      map[item.main]!.add(item.value);
    }

    final orderedMains = <String>[];
    void addMain(String value) {
      final normalized = value.trim();
      if (normalized.isEmpty || orderedMains.contains(normalized)) return;
      orderedMains.add(normalized);
    }

    for (final item in homeItems) {
      addMain(item.value);
    }
    for (final item in menuMainItems) {
      addMain(item.value);
    }

    final remainingMains = map.keys.where((key) => !orderedMains.contains(key)).toList()
      ..sort();
    for (final value in remainingMains) {
      addMain(value);
    }

    if (orderedMains.isEmpty) {
      for (final item in categories) {
        addMain(item.value);
      }
    }

    final fallbackImages = {for (final c in categories) c.value: c.image};
    final fallbackLabels = {for (final c in categories) c.value: c.label};
    final homeImages = {
      for (final item in homeItems)
        if (item.value.isNotEmpty && item.imageUrl.isNotEmpty)
          item.value: item.imageUrl,
    };
    final menuMainImages = {
      for (final item in menuMainItems)
        if (item.value.isNotEmpty && item.imageUrl.isNotEmpty)
          item.value: item.imageUrl,
    };
    final homeLabels = {
      for (final item in homeItems)
        if (item.value.isNotEmpty && item.label.preferred().isNotEmpty)
          item.value: item.label.preferred(),
    };
    final menuMainLabels = {
      for (final item in menuMainItems)
        if (item.value.isNotEmpty && item.label.preferred().isNotEmpty)
          item.value: item.label.preferred(),
    };
    final menuSubLabelsByMain = <String, Map<String, String>>{};
    final menuSubImagesByMain = <String, Map<String, String>>{};
    final menuSubOrderByMain = <String, Map<String, int>>{};
    var menuSubOrderIndex = 0;
    for (final item in menuSubItems) {
      if (item.main.isEmpty || item.value.isEmpty) continue;

      if (item.label.preferred().isNotEmpty) {
        final byMain = menuSubLabelsByMain.putIfAbsent(
          item.main,
          () => <String, String>{},
        );
        byMain[item.value] = item.label.preferred();
      }

      if (item.imageUrl.isNotEmpty) {
        final byMain = menuSubImagesByMain.putIfAbsent(
          item.main,
          () => <String, String>{},
        );
        byMain[item.value] = item.imageUrl;
      }

      final byMain = menuSubOrderByMain.putIfAbsent(
        item.main,
        () => <String, int>{},
      );
      byMain.putIfAbsent(item.value, () => menuSubOrderIndex++);
    }

    final nodesByMain = <String, CategoryNode>{};
    for (final main in orderedMains) {
      final subs = (map[main] ?? <String>{}).toList();
      final orderMap = menuSubOrderByMain[main] ?? const <String, int>{};
      subs.sort((a, b) {
        final aOrder = orderMap[a];
        final bOrder = orderMap[b];
        if (aOrder != null && bOrder != null) {
          return aOrder.compareTo(bOrder);
        }
        if (aOrder != null) return -1;
        if (bOrder != null) return 1;
        return a.compareTo(b);
      });

      final subImages = <String, String>{};
      final menuSubImages = menuSubImagesByMain[main] ?? const <String, String>{};
      final productSubs = productSubImages[main] ?? const <String, String>{};
      for (final sub in subs) {
        final fromMenu = menuSubImages[sub]?.trim() ?? '';
        if (fromMenu.isNotEmpty) {
          subImages[sub] = fromMenu;
          continue;
        }
        final fromProduct = productSubs[sub]?.trim() ?? '';
        if (fromProduct.isNotEmpty) {
          subImages[sub] = fromProduct;
        }
      }

      final label =
          (homeLabels[main] ?? menuMainLabels[main] ?? fallbackLabels[main] ?? main).trim();

      nodesByMain[main] = CategoryNode(
        main: main,
        subs: subs,
        image:
            homeImages[main] ??
            menuMainImages[main] ??
            productMainImages[main] ??
            fallbackImages[main],
        label: label.isNotEmpty ? label : main,
        subLabels: menuSubLabelsByMain[main] ?? const <String, String>{},
        subImages: subImages,
      );
    }

    final categoryNodes = orderedMains
        .map((main) => nodesByMain[main])
        .whereType<CategoryNode>()
        .toList();

    final homeNodes = <CategoryNode>[];
    if (homeItems.isNotEmpty) {
      for (final item in homeItems) {
        final node = nodesByMain[item.value];
        if (node != null) homeNodes.add(node);
      }
    }

    if (!mounted) return;
    setState(() {
      _categories = categoryNodes;
      _homeCategories = homeNodes.isNotEmpty ? homeNodes : categoryNodes;
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

  void _setCartQuantity(CartItem item, int quantity) {
    setState(() {
      final index = _cart.indexWhere(
        (cartItem) => cartItem.product.id == item.product.id,
      );
      if (index < 0) return;

      if (quantity <= 0) {
        _cart.removeAt(index);
        return;
      }

      _cart[index] = _cart[index].copyWith(quantity: quantity);
    });
  }

  Future<String?> _placeOrder({
    required String name,
    required String phone,
    required String address,
    String? note,
  }) async {
    if (_cart.isEmpty) return 'السلة فارغة.';
    setState(() => _placingOrder = true);
    try {
      final order = await _api.createOrder(
        items: _cart,
        customerName: name,
        customerPhone: phone,
        address: address,
        note: note,
      );
      if (mounted) {
        setState(() {
          _cart.clear();
          if (order != null) {
            _orders = [order, ..._orders]
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          }
        });
      }
      await _loadOrders();
      if (mounted) {
        _showDesignMessage('تم إنشاء الطلب بنجاح');
        setState(() => _navIndex = 4);
      }
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'تعذر إتمام الشراء. حاول مرة أخرى.';
    } finally {
      if (mounted) setState(() => _placingOrder = false);
    }
  }

  Future<void> _startCheckout() async {
    if (_cart.isEmpty) {
      _showDesignMessage('السلة فارغة.');
      return;
    }
    if (_user == null) {
      _showDesignMessage('سجّل الدخول لإتمام الشراء');
      setState(() => _navIndex = 4);
      return;
    }

    final total = _cart
        .fold<double>(0, (sum, item) => sum + item.total)
        .toStringAsFixed(2);
    final nameController = TextEditingController(text: _user?.name ?? '');
    final phoneController = TextEditingController(text: _user?.phone ?? '');
    final addressController = TextEditingController();
    final noteController = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        bool submitting = false;
        String? error;
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            Future<void> submit() async {
              final name = nameController.text.trim();
              final phone = phoneController.text.trim();
              final address = addressController.text.trim();
              final note = noteController.text.trim();
              if (name.isEmpty || phone.isEmpty || address.isEmpty) {
                setModalState(() => error = 'أدخل الاسم ورقم الجوال والعنوان.');
                return;
              }
              setModalState(() {
                submitting = true;
                error = null;
              });
              final result = await _placeOrder(
                name: name,
                phone: phone,
                address: address,
                note: note.isEmpty ? null : note,
              );
              if (!ctx.mounted) return;
              if (result == null) {
                Navigator.of(ctx).pop();
              } else {
                setModalState(() {
                  submitting = false;
                  error = result;
                });
              }
            }

            final bottom = MediaQuery.of(ctx).viewInsets.bottom;
            return Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, bottom + 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'إتمام الشراء',
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.right,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameController,
                    textAlign: TextAlign.right,
                    decoration: const InputDecoration(
                      labelText: 'الاسم الكامل',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneController,
                    textAlign: TextAlign.right,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'رقم الجوال'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: addressController,
                    textAlign: TextAlign.right,
                    decoration: const InputDecoration(
                      labelText: 'العنوان',
                      hintText: 'المدينة، الشارع، تفاصيل إضافية',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteController,
                    textAlign: TextAlign.right,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'ملاحظة (اختياري)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'الإجمالي: $total ₪',
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.right,
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      error!,
                      style: TextStyle(color: _appError(ctx)),
                      textAlign: TextAlign.right,
                    ),
                  ],
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: submitting ? null : submit,
                    child: submitting
                        ? SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Theme.of(ctx).colorScheme.onPrimary,
                            ),
                          )
                        : const Text('تأكيد الطلب'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _goToCart() {
    setState(() => _navIndex = 3);
  }

  Future<void> _openNotifications() async {
    if (_user == null) {
      await _openAuthSheet(mode: _AuthMode.login);
      return;
    }
    await _loadNotifications();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final unread = _unreadNotificationsCount;

            void refreshSheet() => setModalState(() {});

            return Directionality(
              textDirection: TextDirection.rtl,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'الإشعارات',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const Spacer(),
                          if (_loadingNotifications)
                            const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            IconButton(
                              tooltip: 'تحديث',
                              onPressed: () async {
                                await _loadNotifications(
                                  onUpdated: refreshSheet,
                                );
                              },
                              icon: const Icon(Icons.refresh),
                            ),
                        ],
                      ),
                      if (unread > 0)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            '$unread إشعار غير مقروء',
                            style: TextStyle(color: _appMuted(context)),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      if (_notificationsError != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _notificationsError!,
                                  style: TextStyle(color: _appError(context)),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                              TextButton(
                                onPressed: () async {
                                  await _loadNotifications(
                                    onUpdated: refreshSheet,
                                  );
                                },
                                child: const Text('إعادة المحاولة'),
                              ),
                            ],
                          ),
                        )
                      else if (_loadingNotifications)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_notifications.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Column(
                            children: [
                              const Icon(Icons.notifications_none, size: 40),
                              const SizedBox(height: 8),
                              Text(
                                'لا توجد إشعارات بعد',
                                style: TextStyle(color: _appMuted(context)),
                              ),
                            ],
                          ),
                        )
                      else
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.5,
                          child: ListView.separated(
                            itemCount: _notifications.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final n = _notifications[index];
                              final created = n.createdAt;
                              final dateText = created != null
                                  ? '${created.year}/${created.month.toString().padLeft(2, '0')}/${created.day.toString().padLeft(2, '0')}'
                                  : '';
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 2,
                                ),
                                leading: Icon(
                                  n.isRead
                                      ? Icons.notifications_outlined
                                      : Icons.markunread_outlined,
                                ),
                                title: Text(
                                  n.title,
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(n.message, textAlign: TextAlign.right),
                                    if (dateText.isNotEmpty)
                                      Text(
                                        dateText,
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                          color: _appMuted(context),
                                          fontSize: 12,
                                        ),
                                      ),
                                  ],
                                ),
                                onTap: () async {
                                  await _markNotificationAsRead(
                                    n.id,
                                    onUpdated: refreshSheet,
                                  );
                                },
                                trailing: n.isRead
                                    ? null
                                    : TextButton(
                                        onPressed: () async {
                                          await _markNotificationAsRead(
                                            n.id,
                                            onUpdated: refreshSheet,
                                          );
                                        },
                                        child: const Text('تمييز كمقروء'),
                                      ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  bool _isFavorite(ProductItem product) => _favoriteIds.contains(product.id);

  Future<void> _toggleFavorite(ProductItem product) async {
    if (_user == null) {
      _showDesignMessage('سجّل الدخول لحفظ المفضلة');
      setState(() => _navIndex = 4);
      return;
    }

    final wasFavorite = _favoriteIds.contains(product.id);
    setState(() {
      if (wasFavorite) {
        _favoriteIds.remove(product.id);
      } else {
        _favoriteIds.add(product.id);
      }
    });

    try {
      await _api.toggleFavorite(product.id);
      if (!mounted) return;
      _showDesignMessage(
        wasFavorite
            ? 'أزيل ${product.name} من المفضلة'
            : 'أُضيف ${product.name} إلى المفضلة',
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (wasFavorite) {
          _favoriteIds.add(product.id);
        } else {
          _favoriteIds.remove(product.id);
        }
      });
      _showDesignMessage('تعذر تحديث المفضلة. حاول مرة أخرى.');
    }
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
        _loadNotifications(),
      ]);
      if (mounted) {
        _showDesignMessage('تم تسجيل الدخول بنجاح');
        _maybeShowSiteAd();
      }
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
      _notifications.clear();
    });
    _showDesignMessage('تم تسجيل الخروج');
    _maybeShowSiteAd();
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
                        style: TextStyle(color: _appError(context)),
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
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'الرئيسية',
            ),
            NavigationDestination(
              icon: Icon(Icons.category_outlined),
              selectedIcon: Icon(Icons.category),
              label: 'التصنيفات',
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
            if (value == 1) {
              _showCategories();
            } else {
              setState(() => _navIndex = value);
              _maybeShowSiteAd();
            }
          },
        ),
      ),
    );
  }

  Widget _buildBody() {
    Widget favoritesPage;
    if (_user == null) {
      favoritesPage = const _PlaceholderPage(
        title: 'سجّل الدخول',
        description: 'تسجيل الدخول يتيح حفظ المفضلة ومزامنتها.',
        icon: Icons.favorite_border,
      );
    } else if (_loadingFavorites) {
      favoritesPage = const Center(child: CircularProgressIndicator());
    } else {
      favoritesPage = _FavoritesPage(
        products: _allProducts.where(_isFavorite).toList(),
        onRemove: _toggleFavorite,
        onAddToCart: _addToCart,
        fetchVariants: _api.fetchVariants,
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
    }

    Widget cartPage;
    if (_loadingCart) {
      cartPage = const Center(child: CircularProgressIndicator());
    } else {
      cartPage = _CartPage(
        items: _cart,
        onIncrement: _incrementCart,
        onDecrement: _decrementCart,
        onSetQuantity: _setCartQuantity,
        onCheckout: _startCheckout,
        placingOrder: _placingOrder,
      );
    }

    return IndexedStack(
      index: _navIndex,
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: _HomeContent(
                onAddToCart: _addToCart,
                isFavorite: _isFavorite,
                onToggleFavorite: _toggleFavorite,
                onBrowseAll: () => _showCategories(),
                categories: _homeCategories.isNotEmpty
                    ? _homeCategories
                    : _categories,
                onCategorySelected: _openCategory,
                onStartShopping: () => _showCategories(),
                onExploreCategories: () => _showCategories(),
                heroKicker: _heroKickerText,
                heroTitle: _heroTitleText,
                heroSubtitle: _heroSubtitleText,
                heroPrimaryCtaLabel: _heroPrimaryCtaText,
                heroSecondaryCtaLabel: _heroSecondaryCtaText,
                heroCalloutLabel: _heroCalloutLabelText,
                heroCalloutValue: _heroCalloutValueText,
                heroImageUrl: _heroImageUrl,
                products: _allProducts,
                recommendedProducts: _recommendedProducts,
                newArrivalProducts: _newArrivalProducts,
                isLoading: _loadingProducts,
                errorText: _productsError,
                fetchVariants: _api.fetchVariants,
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
        ),
        _CategoriesPage(
          categories: _categories,
          products: _allProducts,
          onAddToCart: _addToCart,
          onToggleFavorite: _toggleFavorite,
          isFavorite: _isFavorite,
          initialMain: _pendingCategoryMain,
          onViewProduct: (product) => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ProductDetailsPage(
                product: product,
                onAddToCart: _addToCart,
                api: _api,
              ),
            ),
          ),
          api: _api,
        ),
        favoritesPage,
        cartPage,
        _AccountPage(
          user: _user,
          loading: _loadingProfile || _authSubmitting,
          onLogin: () => _openAuthSheet(mode: _AuthMode.login),
          onRegister: () => _openAuthSheet(mode: _AuthMode.register),
          onLogout: _logout,
          orders: _orders,
          loadingOrders: _loadingOrders,
          ordersError: _ordersError,
          onRefreshOrders: _loadOrders,
          onViewAllOrders: _openOrdersPage,
          onViewOrder: _showOrderDetails,
        ),
      ],
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    final user = _user;
    return AppBar(
      titleSpacing: 0,
      title: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: [
            SizedBox(
              height: 48,
              width: 48,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.asset('lib/logo.png', fit: BoxFit.contain),
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
            Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  tooltip: 'الإشعارات',
                  onPressed: _openNotifications,
                  icon: const Icon(Icons.notifications_none),
                ),
                if (_unreadNotificationsCount > 0)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _appError(context),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _unreadNotificationsCount > 9
                            ? '9+'
                            : _unreadNotificationsCount.toString(),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onError,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            IconButton(
              tooltip: 'السلة',
              onPressed: _goToCart,
              icon: const Icon(Icons.shopping_bag_outlined),
            ),
            if (user == null)
              Padding(
                padding: const EdgeInsets.only(left: 8, right: 12),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                  ),
                  onPressed: () => _openAuthSheet(mode: _AuthMode.login),
                  child: const Text('تسجيل الدخول'),
                ),
              )
            else
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(left: 8, right: 12),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      user.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
