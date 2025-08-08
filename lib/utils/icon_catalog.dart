import 'package:flutter/material.dart';

class IconCatalog {
  static const Map<String, IconData> icons = {
    // Food & Drink
    'fastfood': Icons.fastfood,
    'restaurant': Icons.restaurant,
    'restaurant_menu': Icons.restaurant_menu,
    'local_cafe': Icons.local_cafe,
    'local_drink': Icons.local_drink,
    'local_bar': Icons.local_bar,
    'wine_bar': Icons.wine_bar,
    'free_breakfast': Icons.free_breakfast,
    'bakery_dining': Icons.bakery_dining,
    'icecream': Icons.icecream,
    'emoji_food_beverage': Icons.emoji_food_beverage,
    'local_pizza': Icons.local_pizza,
    'local_dining': Icons.local_dining,

    // Retail & Items
    'local_grocery_store': Icons.local_grocery_store,
    'shopping_bag': Icons.shopping_bag,
    'shopping_basket': Icons.shopping_basket,
    'shopping_cart': Icons.shopping_cart,
    'store': Icons.store,
    'storefront': Icons.storefront,
    'category': Icons.category,
    'inventory_2': Icons.inventory_2,
    'inventory': Icons.inventory,
    'sell': Icons.sell,
    'local_offer': Icons.local_offer,
    'tag': Icons.tag,

    // Household & Misc
    'kitchen': Icons.kitchen,
    'blender': Icons.blender,
    'chair': Icons.chair,
    'weekend': Icons.weekend,
    'light': Icons.lightbulb_outline,

    // Electronics
    'phone_iphone': Icons.phone_iphone,
    'laptop_mac': Icons.laptop_mac,
    'watch': Icons.watch,
    'headphones': Icons.headphones,

    // Apparel
    'checkroom': Icons.checkroom,
    'work': Icons.work,
    'backpack': Icons.backpack,

    // Beauty & Health
    'spa': Icons.spa,
    'sanitizer': Icons.sanitizer,
    'soap': Icons.soap,
  };

  static IconData iconFor(String? name) {
    if (name == null) return Icons.fastfood;
    return icons[name] ?? Icons.fastfood;
  }
}
