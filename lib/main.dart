import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api/api_client.dart';
import 'config.dart';
import 'data/home_content.dart';
import 'models/category_node.dart';

part 'app/app.dart';
part 'features/home/home_page.dart';
part 'features/home/sections.dart';
part 'features/products/products_page.dart';
part 'features/products/product_details_page.dart';
part 'features/favorites/favorites_page.dart';
part 'features/cart/cart_page.dart';
part 'features/account/account_page.dart';
part 'features/orders/orders_page.dart';
part 'features/shared/shared_widgets.dart';

void main() {
  runApp(const MadinaApp());
}
 