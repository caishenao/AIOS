import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../surface/ui_node.dart';
import '../catalog_registry.dart';
import '../theme_tokens.dart';

/// Displays a premium media player with simulation of real playback, controls, and details.
///
/// Props:
/// - `streamUrl` (String?): Stream URL.
/// - `poster` (String?): Poster image URL.
/// - `type` (String): Media type — `"video"` or `"audio"`.
/// - `title` (String?): Media title.
/// - `variant` (String?): `"fullbleed"` for edge-to-edge, `"card"` for contained.
class CatalogMediaPlayer extends StatefulWidget {
  final Map<String, dynamic> props;
  final List<UiNode> children;
  final ThemeTokens? theme;
  final Map<String, String>? events;
  final EventCallback? onEvent;

  const CatalogMediaPlayer({
    super.key,
    required this.props,
    this.children = const [],
    this.theme,
    this.events,
    this.onEvent,
  });

  /// Registers this component in the [CatalogRegistry].
  static void register(CatalogRegistry registry) {
    registry.register('MediaPlayer', ({
      required Map<String, dynamic> props,
      required List<UiNode> children,
      Map<String, dynamic>? bindings,
      Map<String, String>? events,
      ThemeTokens? theme,
      required BuildContext context,
      EventCallback? onEvent,
    }) {
      return CatalogMediaPlayer(
        props: props,
        children: children,
        theme: theme,
        events: events,
        onEvent: onEvent,
      );
    });
  }

  @override
  State<CatalogMediaPlayer> createState() => _CatalogMediaPlayerState();
}

class _CatalogMediaPlayerState extends State<CatalogMediaPlayer> {
  bool _isPlaying = false;
  double _playbackPosition = 0.0; // 0.0 to 1.0
  double _volume = 0.8;
  bool _isMuted = false;
  int _currentTimeSeconds = 0;
  final int _totalDurationSeconds = 180; // 3 minutes simulated
  Timer? _playbackTimer;
  bool _isFullscreen = false;

  void _togglePlay() {
    setState(() {
      _isPlaying = !_isPlaying;
      if (_isPlaying) {
        _startPlaybackTimer();
        final action = widget.events?['onPlay'] ?? 'media.play';
        widget.onEvent?.call(action, widget.props);
      } else {
        _playbackTimer?.cancel();
        final action = widget.events?['onPause'] ?? 'media.pause';
        widget.onEvent?.call(action, widget.props);
      }
    });
  }

  void _startPlaybackTimer() {
    _playbackTimer?.cancel();
    _playbackTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_currentTimeSeconds >= _totalDurationSeconds) {
          _currentTimeSeconds = 0;
          _playbackPosition = 0.0;
          _isPlaying = false;
          _playbackTimer?.cancel();
        } else {
          _currentTimeSeconds++;
          _playbackPosition = _currentTimeSeconds / _totalDurationSeconds;
        }
      });
    });
  }

  String _formatTime(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme ?? ThemeTokens.minimal;
    final type = widget.props['type'] as String? ?? 'video';
    final title = widget.props['title'] as String? ?? 'Cyber Stream Video';
    final poster = widget.props['poster'] as String?;
    final variant = widget.props['variant'] as String? ?? 'card';
    final isFullbleed = variant == 'fullbleed';
    final isAudio = type == 'audio';

    final double aspectRatio = isAudio ? 3.5 : 16.0 / 9.0;
    final streamUrl = widget.props['streamUrl'] as String? ?? '';

    return GestureDetector(
      onTap: () {
        if (widget.onEvent != null) {
          final action = widget.events?['onTap'] ?? 'media.select';
          widget.onEvent!(action, {
            'title': title,
            'streamUrl': streamUrl,
          });
        }
      },
      child: Container(
        margin: isFullbleed
            ? EdgeInsets.zero
            : EdgeInsets.symmetric(vertical: t.baseSpacing / 2),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: isFullbleed ? null : BorderRadius.circular(t.cardRadius),
        border: isFullbleed ? null : Border.all(color: t.accent.withAlpha(40)),
        boxShadow: isFullbleed
            ? null
            : [
                BoxShadow(
                  color: t.accent.withAlpha(15),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Video Player Screen Area
          AspectRatio(
            aspectRatio: aspectRatio,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Background video screen simulation
                if (poster != null)
                  Image.network(
                    poster,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildScreenPlaceholder(t, isAudio),
                  )
                else
                  _buildScreenPlaceholder(t, isAudio),

                // Pulsing glow when playing video
                if (_isPlaying && !isAudio)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: t.accent.withAlpha(30),
                              blurRadius: 30,
                              spreadRadius: -10,
                            )
                          ],
                        ),
                      ),
                    ),
                  ),

                // Ambient scanlines overlay
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withAlpha(30),
                            Colors.transparent,
                            Colors.black.withAlpha(120),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),
                ),

                // Center Play Button Overlay (fades out when playing)
                if (!_isPlaying)
                  Center(
                    child: GestureDetector(
                      onTap: _togglePlay,
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: t.accent.withAlpha(220),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: t.accent.withAlpha(80),
                              blurRadius: 20,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: Icon(
                          isAudio ? Icons.music_note : Icons.play_arrow,
                          color: t.onAccent,
                          size: 32,
                        ),
                      ),
                    ),
                  ),

                // Title Overlay (Top Left)
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(150),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: t.accent.withAlpha(80)),
                        ),
                        child: Text(
                          isAudio ? '音频流' : '直播视频',
                          style: TextStyle(
                            color: t.accent,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14 * t.fontScale,
                            fontWeight: FontWeight.bold,
                            shadows: const [
                              Shadow(color: Colors.black, blurRadius: 4, offset: Offset(1, 1))
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Player Control Bar
          Container(
            padding: EdgeInsets.symmetric(horizontal: t.baseSpacing, vertical: 8),
            color: Colors.black.withAlpha(200),
            child: Column(
              children: [
                // Timeline progress bar
                Row(
                  children: [
                    Text(
                      _formatTime(_currentTimeSeconds),
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                    Expanded(
                      child: SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 2.0,
                          activeTrackColor: t.accent,
                          inactiveTrackColor: Colors.white24,
                          thumbColor: t.accent,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                        ),
                        child: Slider(
                          value: _playbackPosition,
                          onChanged: (val) {
                            setState(() {
                              _playbackPosition = val;
                              _currentTimeSeconds = (val * _totalDurationSeconds).round();
                            });
                          },
                        ),
                      ),
                    ),
                    Text(
                      _formatTime(_totalDurationSeconds),
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),

                // Button controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            _isPlaying ? Icons.pause : Icons.play_arrow,
                            color: Colors.white,
                          ),
                          onPressed: _togglePlay,
                        ),
                        IconButton(
                          icon: const Icon(Icons.skip_next, color: Colors.white70),
                          onPressed: () {
                            setState(() {
                              _currentTimeSeconds = min(_currentTimeSeconds + 10, _totalDurationSeconds);
                              _playbackPosition = _currentTimeSeconds / _totalDurationSeconds;
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(
                            _isMuted ? Icons.volume_off : Icons.volume_up,
                            color: Colors.white70,
                          ),
                          onPressed: () {
                            setState(() {
                              _isMuted = !_isMuted;
                            });
                          },
                        ),
                        SizedBox(
                          width: 80,
                          child: SliderTheme(
                            data: SliderThemeData(
                              trackHeight: 2.0,
                              activeTrackColor: Colors.white,
                              inactiveTrackColor: Colors.white24,
                              thumbColor: Colors.white,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
                            ),
                            child: Slider(
                              value: _isMuted ? 0.0 : _volume,
                              onChanged: (val) {
                                setState(() {
                                  _volume = val;
                                  _isMuted = val == 0.0;
                                });
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            _isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                            color: Colors.white70,
                          ),
                          onPressed: () {
                            setState(() {
                              _isFullscreen = !_isFullscreen;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(
                                    _isFullscreen
                                        ? '全屏模式已启用 (模拟)'
                                        : '全屏模式已关闭',
                                  ),
                              ),
                            );
                          },
                        ),
                      ],
                    )
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ));
  }

  Widget _buildScreenPlaceholder(ThemeTokens t, bool isAudio) {
    if (isAudio) {
      return Container(
        color: const Color(0xFF141416).withAlpha(220),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.music_note, color: t.accent.withAlpha(180), size: 36),
              const SizedBox(height: 8),
              Text(
                'AIOS 音频流播放器',
                style: TextStyle(color: t.onSurface.withAlpha(120), fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      color: Colors.grey.withAlpha(40),
      child: Center(
        child: Icon(
          Icons.videocam,
          color: t.onSurface.withAlpha(40),
          size: 48,
        ),
      ),
    );
  }
}
