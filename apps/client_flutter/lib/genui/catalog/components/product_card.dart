import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../catalog_registry.dart';
import '../theme_tokens.dart';

class ProductCardComponent extends StatelessWidget {
  final String title;
  final double price;
  final String description;
  final String imageUrl;
  final String buyUrl;
  final String buttonText;
  final ThemeTokens theme;
  final Map<String, String>? events;
  final EventCallback? onEvent;

  const ProductCardComponent({
    super.key,
    required this.title,
    required this.price,
    required this.description,
    required this.imageUrl,
    required this.buyUrl,
    required this.buttonText,
    required this.theme,
    this.events,
    this.onEvent,
  });

  static void register(CatalogRegistry registry) {
    registry.register('ProductCard', ({
      required props,
      required children,
      bindings,
      events,
      theme,
      required context,
      onEvent,
    }) {
      return ProductCardComponent(
        title: props['title'] as String? ?? '商品名称',
        price: (props['price'] as num?)?.toDouble() ?? 0.0,
        description: props['description'] as String? ?? '商品描述信息。',
        imageUrl: props['imageUrl'] as String? ?? 'https://images.unsplash.com/photo-1523275335684-37898b6baf30?w=500&auto=format&fit=crop',
        buyUrl: props['buyUrl'] as String? ?? 'https://item.jd.com',
        buttonText: props['buttonText'] as String? ?? '立即购买',
        theme: theme ?? ThemeTokens.minimal,
        events: events,
        onEvent: onEvent,
      );
    });
  }

  Future<void> _launchBuyUrl(BuildContext context) async {
    final Uri url = Uri.parse(buyUrl);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('无法解析跳转链接');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('无法跳转购买: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: t.surface.withAlpha(220),
        borderRadius: BorderRadius.circular(t.cardRadius),
        border: Border.all(color: t.accent.withAlpha(40)),
        boxShadow: [
          BoxShadow(
            color: t.accent.withAlpha(15),
            blurRadius: 16,
            offset: const Offset(0, 8),
          )
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Product Image
          AspectRatio(
            aspectRatio: 1.6,
            child: Image.network(
              imageUrl,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: t.accent,
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.white.withAlpha(5),
                  child: Icon(Icons.shopping_bag_outlined, color: t.accent.withAlpha(100), size: 48),
                );
              },
            ),
          ),
          // Product Details
          Padding(
            padding: EdgeInsets.all(t.baseSpacing),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          color: t.onSurface,
                          fontWeight: FontWeight.bold,
                          fontSize: 16 * t.fontScale,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '¥${price.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: t.accent,
                        fontWeight: FontWeight.bold,
                        fontSize: 18 * t.fontScale,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: t.baseSpacing * 0.5),
                Text(
                  description,
                  style: TextStyle(
                    color: t.onSurface.withAlpha(150),
                    fontSize: 12 * t.fontScale,
                    height: 1.4,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const Divider(height: 24, color: Colors.white10),
                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: Text(buttonText),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: t.accent,
                          foregroundColor: Colors.black,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => _launchBuyUrl(context),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.psychology, size: 16),
                      label: const Text('咨询 AI'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: t.onSurface,
                        side: BorderSide(color: t.onSurface.withAlpha(40)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        // Fire AI query event
                        final action = events?['onConsultProduct'] ?? 'product.consult';
                        onEvent?.call(action, {
                          'productTitle': title,
                          'price': price,
                          'queryText': '我想了解这件商品 "$title" 的详细信息和购买评测。',
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
