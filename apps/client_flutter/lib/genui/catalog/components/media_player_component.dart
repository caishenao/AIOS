import 'package:flutter/material.dart';
import '../catalog_registry.dart';
import '../theme_tokens.dart';

class MediaPlayerComponent extends StatelessWidget {
  final String streamUrl;
  final String? poster;
  final String? type;
  final ThemeTokens theme;

  const MediaPlayerComponent({
    super.key,
    required this.streamUrl,
    this.poster,
    this.type,
    required this.theme,
  });

  static void register(CatalogRegistry registry) {
    registry.register('MediaPlayer', ({
      required props,
      required children,
      bindings,
      events,
      theme,
      required context,
      onEvent,
    }) {
      final t = theme ?? ThemeTokens.minimal;
      final url = props['streamUrl'] as String? ?? 'Unknown Stream';
      final posterUrl = props['poster'] as String?;
      final mediaType = props['type'] as String?;

      return MediaPlayerComponent(
        streamUrl: url,
        poster: posterUrl,
        type: mediaType,
        theme: t,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(theme.cardRadius),
        image: poster != null
            ? DecorationImage(
                image: NetworkImage(poster!),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(Colors.black.withAlpha(100), BlendMode.darken),
              )
            : null,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Play button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(150),
              shape: BoxShape.circle,
            ),
            child: Icon(
              type == 'audio' ? Icons.audiotrack : Icons.play_arrow,
              color: Colors.white,
              size: 48,
            ),
          ),
          // Stream info
          Positioned(
            bottom: 12,
            left: 16,
            right: 16,
            child: Text(
              streamUrl,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
