part of '../../main.dart';

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
    required this.onViewAllOrders,
    required this.onViewOrder,
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
  final VoidCallback onViewAllOrders;
  final void Function(OrderSummary order) onViewOrder;

  @override
  Widget build(BuildContext context) {
    void showPrivacyPolicy(BuildContext ctx) {
      showModalBottomSheet<void>(
        context: ctx,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        isScrollControlled: true,
        builder: (bottomCtx) {
          final bottom = MediaQuery.of(bottomCtx).viewInsets.bottom;
          return Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, bottom + 24),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'سياسة الخصوصية',
                      style: Theme.of(bottomCtx).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                      textAlign: TextAlign.right,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'خصوصيتك مهمة لنا. في ديكوري، نلتزم بحماية بياناتك الشخصية واستخدامها فقط للأغراض الموضّحة أدناه.\n\n'
                      'البيانات التي نجمعها\n'
                      'معلومات الحساب: الاسم، البريد الإلكتروني، رقم الهاتف.\n'
                      'معلومات الطلب والشحن: العنوان والتفاصيل اللازمة لإتمام الطلب.\n'
                      'بيانات الاستخدام: مثل الصفحات التي تزورها والمنتجات التي تتصفحها.\n\n'
                      'كيف نستخدم بياناتك\n'
                      'معالجة الطلبات والدفع والتسليم وخدمة العملاء.\n'
                      'تحسين تجربة التسوق وتخصيص العروض.\n'
                      'الأمان ومنع الاحتيال، بما في ذلك استخدام خدمات مثل Google reCAPTCHA للتحقق ومنع النشاطات الضارة.\n\n'
                      'مشاركة البيانات\n'
                      'قد نشارك بعض البيانات مع مزوّدي الخدمات (بوابة الدفع/شركة الشحن/أنظمة التحليلات) بالقدر اللازم لتقديم الخدمة. لا نبيع بياناتك لطرف ثالث.\n\n'
                      'حقوقك\n'
                      'طلب الوصول لبياناتك أو تصحيحها أو حذفها ضمن الحدود القانونية.\n'
                      'الانسحاب من الرسائل التسويقية في أي وقت.\n\n'
                      'التغييرات على السياسة\n'
                      'قد نقوم بتحديث هذه السياسة من وقت لآخر. سيتم نشر أي تعديل على هذه الصفحة.',
                      textAlign: TextAlign.right,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => Navigator.of(bottomCtx).pop(),
                      child: const Text('إغلاق'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }

    void showReturnPolicy(BuildContext ctx) {
      showModalBottomSheet<void>(
        context: ctx,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        isScrollControlled: true,
        builder: (bottomCtx) {
          final bottom = MediaQuery.of(bottomCtx).viewInsets.bottom;
          return Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, bottom + 24),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'سياسة الإرجاع والاستبدال',
                      style: Theme.of(bottomCtx).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                      textAlign: TextAlign.right,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'نسعى في ديكوري لتقديم تجربة تسوّق موثوقة وسلسة. الرجاء قراءة سياسة الإرجاع والاستبدال التالية بعناية قبل إتمام عملية الشراء.\n\n'
                      'شروط القبول\n'
                      'مشكلة من المصدر: في حال كان المنتج معيبًا أو تالفًا أو هناك خطأ منّا في التنفيذ/التجهيز، نقبل الإرجاع أو الاستبدال بدون أي رسوم إضافية.\n'
                      'عدم مطابقة المنتج المطلوب: إذا كان المنتج المستلم لا يطابق المواصفات المطلوبة في الطلب (النوع/اللون/المقاس)، تتوفر آلية إرجاع أو استبدال وفقًا للحالة.\n'
                      'استخدام أو فتح المنتج: في حال تم فتح المنتج أو استخدامه أو إزالة التغليف الأصلي غير القابل للإرجاع، لا يُقبل الإرجاع إلا في الحالات المصنعية المعيبة المثبتة.\n\n'
                      'الإطار الزمني\n'
                      'يجب إبلاغنا بطلب الإرجاع/الاستبدال خلال 48 ساعة من استلام الطلب، مع إرفاق صور واضحة تبين المشكلة.\n'
                      'يجب إعادة شحن المنتج خلال 3 أيام عمل من موافقة فريق خدمة العملاء على الطلب.\n\n'
                      'حالة المنتج المرتجع\n'
                      'غير مستخدم (إلا في العيوب المصنعية المثبتة).\n'
                      'بالعبوة الأصلية وبكامل الملحقات والفواتير إن وجدت.\n'
                      'خالي من الروائح أو الآثار أو الأضرار الناتجة عن سوء الاستخدام.\n\n'
                      'الرسوم والتكاليف\n'
                      'في الحالات التي تكون المشكلة من المصدر أو عدم مطابقة المنتج، تتحمّل ديكوري تكاليف الشحن والإرجاع/الاستبدال.\n'
                      'في الحالات الأخرى المقبولة (إن وُجدت)، قد يتحمّل المشتري رسوم الشحن/المناولة وفقًا لتقييم خدمة العملاء.\n\n'
                      'طريقة الإرجاع\n'
                      'التواصل معنا خلال المدة المحددة عبر وسائل الاتصال المتاحة مع إرفاق رقم الطلب وشرح المشكلة وصور واضحة.\n'
                      'يراجع فريقنا الطلب ويقيّم الحالة ويزوّدك بخيارات الاستبدال/الإرجاع وتفاصيل الشحن.\n'
                      'بعد استلام المنتج وفحصه، يتم إرسال بديل أو إصدار رصيد/استرجاع بحسب ما يتم الاتفاق عليه.\n\n'
                      'استثناءات عامة\n'
                      'المنتجات المخصّصة/حسب الطلب قد لا تقبل الإرجاع إلا لعيب مصنعي.\n'
                      'بطاقات الهدايا أو المنتجات القابلة للاستهلاك قد تُستثنى.\n'
                      'أي تلاعب أو استعمال خاطئ يلغي أهلية الإرجاع.\n'
                      'تحتفظ ديكوري بالحق في تحديث هذه السياسة بما يتوافق مع القوانين والمعايير التجارية. آخر تحديث يتم نشره على هذه الصفحة.',
                      textAlign: TextAlign.right,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => Navigator.of(bottomCtx).pop(),
                      child: const Text('إغلاق'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }

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
                        color: _appMuted(context),
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
                          color: _appMuted(context),
                        ),
                      )
                    else if (loadingOrders)
                      const Center(child: CircularProgressIndicator())
                    else if (ordersError != null)
                      Text(
                        ordersError!,
                        style: TextStyle(color: _appError(context)),
                        textAlign: TextAlign.right,
                      )
                    else if (orders.isEmpty)
                      Text(
                        'لا توجد طلبات حالية.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: _appMuted(context),
                        ),
                      )
                    else
                      Builder(
                        builder: (context) {
                          final ordered = [
                            ...orders,
                          ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
                          final preview = ordered.take(6).toList();
                          final hasMore = ordered.length > preview.length;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (var i = 0; i < preview.length; i++) ...[
                                _OrderTile(
                                  order: preview[i],
                                  onTap: () => onViewOrder(preview[i]),
                                ),
                                if (i != preview.length - 1)
                                  const Divider(height: 20),
                              ],
                              if (hasMore) ...[
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    onPressed: onViewAllOrders,
                                    icon: const Icon(Icons.list_alt_outlined),
                                    label: const Text('عرض كل الطلبات'),
                                  ),
                                ),
                              ],
                            ],
                          );
                        },
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
                      children: [
                        _AccountChip(
                          icon: Icons.receipt_long,
                          label: 'طلباتي',
                          onTap: onViewAllOrders,
                        ),
                        _AccountChip(
                          icon: Icons.privacy_tip_outlined,
                          label: 'سياسة الخصوصية',
                          onTap: () => showPrivacyPolicy(context),
                        ),
                        _AccountChip(
                          icon: Icons.autorenew_outlined,
                          label: 'سياسة التبديل والترجيع',
                          onTap: () => showReturnPolicy(context),
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
