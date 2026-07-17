import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../catalog_registry.dart';
import '../theme_tokens.dart';

class MapNavigationComponent extends StatefulWidget {
  final String startLocation;
  final String endLocation;
  final String? currentStep;
  final List<dynamic> steps;
  final int etaMinutes;
  final double distanceKm;
  final List<dynamic>? coordinates;
  final ThemeTokens theme;
  final Map<String, String>? events;
  final EventCallback? onEvent;

  const MapNavigationComponent({
    super.key,
    required this.startLocation,
    required this.endLocation,
    this.currentStep,
    required this.steps,
    required this.etaMinutes,
    required this.distanceKm,
    this.coordinates,
    required this.theme,
    this.events,
    this.onEvent,
  });

  static void register(CatalogRegistry registry) {
    registry.register('MapNavigation', ({
      required props,
      required children,
      bindings,
      events,
      theme,
      required context,
      onEvent,
    }) {
      return MapNavigationComponent(
        startLocation: props['startLocation'] as String? ?? 'Origin',
        endLocation: props['endLocation'] as String? ?? 'Destination',
        currentStep: props['currentStep'] as String?,
        steps: props['steps'] as List<dynamic>? ?? [],
        etaMinutes: props['etaMinutes'] as int? ?? 10,
        distanceKm: (props['distanceKm'] as num?)?.toDouble() ?? 5.0,
        coordinates: props['coordinates'] as List<dynamic>?,
        theme: theme ?? ThemeTokens.minimal,
        events: events,
        onEvent: onEvent,
      );
    });
  }

  @override
  State<MapNavigationComponent> createState() => _MapNavigationComponentState();
}

class _MapNavigationComponentState extends State<MapNavigationComponent> with SingleTickerProviderStateMixin {
  late AnimationController _progressController;
  Timer? _simulationTimer;
  int _currentStepIndex = 0;
  double _simulatedSpeed = 60.0; // km/h
  double _distanceRemaining = 0.0;
  int _etaRemaining = 0;
  bool _isNavigating = true;

  @override
  void initState() {
    super.initState();
    _distanceRemaining = widget.distanceKm;
    _etaRemaining = widget.etaMinutes;

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    );

    if (_isNavigating) {
      _startSimulation();
    }
  }

  void _startSimulation() {
    _progressController.repeat();
    _simulationTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted || !_isNavigating) return;
      setState(() {
        // Decrease distance slowly
        _distanceRemaining -= 0.005 * (_simulatedSpeed / 60.0);
        if (_distanceRemaining <= 0) {
          _distanceRemaining = 0;
          _etaRemaining = 0;
          _isNavigating = false;
          _progressController.stop();
          _simulationTimer?.cancel();
          // Fire completed event
          final action = widget.events?['onNavigationComplete'] ?? 'navigation.complete';
          widget.onEvent?.call(action, {'status': 'arrived'});
        } else {
          // Update ETA
          _etaRemaining = (_distanceRemaining * 60 / _simulatedSpeed).round();
          
          // Rotate steps based on progress
          final totalSteps = widget.steps.length;
          if (totalSteps > 0) {
            double progress = 0.0;
            if (widget.distanceKm > 0) {
              progress = (1.0 - (_distanceRemaining / widget.distanceKm)).clamp(0.0, 1.0);
              if (progress.isNaN || progress.isInfinite) progress = 0.0;
            }
            _currentStepIndex = min((progress * totalSteps).floor(), totalSteps - 1);
          }
        }
      });
    });
  }

  Future<void> _launchExternalMap() async {
    final destination = Uri.encodeComponent(widget.endLocation);
    // High coverage routing url scheme/web urls
    final amapUrl = 'https://uri.amap.com/navigation?to=$destination&mode=car';
    final googleUrl = 'https://www.google.com/maps/dir/?api=1&destination=$destination';

    final Uri url = Uri.parse(amapUrl);
    final Uri fallbackUrl = Uri.parse(googleUrl);
    
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(fallbackUrl)) {
        await launchUrl(fallbackUrl, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('无法解析导航跳转链接');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('无法唤起外部导航软件: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _progressController.dispose();
    _simulationTimer?.cancel();
    super.dispose();
  }

  String _getStaticMapUrl() {
    final baseUrl = "https://static-maps.yandex.ru/1.x/?l=map&size=600,350";
    if (widget.coordinates != null && widget.coordinates!.isNotEmpty) {
      final points = <String>[];
      for (final pt in widget.coordinates!) {
        if (pt is List && pt.length >= 2) {
          final lon = pt[0];
          final lat = pt[1];
          points.add("$lon,$lat");
        }
      }
      if (points.isNotEmpty) {
        final pathParam = "color:0x7C5CFFff,width:5,${points.join(',')}";
        final firstPt = points.first;
        final lastPt = points.last;
        final pushpins = "pt=$firstPt,pm2bld1~$lastPt,pm2ard2";
        return "$baseUrl&pl=$pathParam&$pushpins";
      }
    }
    // Default fallback coordinates (Shanghai center) if coordinates not provided
    return "$baseUrl&ll=121.4737,31.2304&z=13";
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    double progress = 0.0;
    if (widget.distanceKm > 0) {
      progress = (1.0 - (_distanceRemaining / widget.distanceKm)).clamp(0.0, 1.0);
      if (progress.isNaN || progress.isInfinite) progress = 0.0;
    }

    return Container(
      decoration: BoxDecoration(
        color: t.surface.withAlpha(220),
        borderRadius: BorderRadius.circular(t.cardRadius),
        border: Border.all(color: t.accent.withAlpha(40)),
        boxShadow: [
          BoxShadow(
            color: t.accent.withAlpha(20),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Navigating Info Header
          Padding(
            padding: EdgeInsets.all(t.baseSpacing),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: t.accent.withAlpha(30),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.navigation, color: t.accent, size: 24),
                ),
                SizedBox(width: t.baseSpacing * 0.8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '导航至 ${widget.endLocation}',
                        style: TextStyle(
                          color: t.onSurface,
                          fontWeight: FontWeight.bold,
                          fontSize: 16 * t.fontScale,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '出发地: ${widget.startLocation}',
                        style: TextStyle(
                          color: t.onSurface.withAlpha(120),
                          fontSize: 12 * t.fontScale,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Cyber-painted map container
          AspectRatio(
            aspectRatio: 1.8,
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: t.baseSpacing),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(180),
                borderRadius: BorderRadius.circular(t.cardRadius - 4),
                border: Border.all(color: t.onSurface.withAlpha(15)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(t.cardRadius - 5),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Grid & Map Path custom painter
                    Image.network(
                      _getStaticMapUrl(),
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF00F0FF),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return AnimatedBuilder(
                          animation: _progressController,
                          builder: (context, _) {
                            return CustomPaint(
                              painter: NavigationMapPainter(
                                progress: progress,
                                accentColor: t.accent,
                                onSurfaceColor: t.onSurface,
                              ),
                            );
                          },
                        );
                      },
                    ),

                    // Top Left Turn indicator
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(200),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: t.accent.withAlpha(80)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.turn_left, color: t.accent, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              '在350米后',
                              style: TextStyle(
                                color: t.onSurface,
                                fontWeight: FontWeight.bold,
                                fontSize: 12 * t.fontScale,
                              ),
                            )
                          ],
                        ),
                      ),
                    ),

                    // Speed display
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(200),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: t.onSurface.withAlpha(30)),
                        ),
                        child: Text(
                          '${_simulatedSpeed.round()} KM/H',
                          style: TextStyle(
                            color: t.accent,
                            fontWeight: FontWeight.bold,
                            fontSize: 12 * t.fontScale,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Steps & Instructions
          Padding(
            padding: EdgeInsets.all(t.baseSpacing),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Direction text
                Container(
                  padding: EdgeInsets.all(t.baseSpacing * 0.8),
                  decoration: BoxDecoration(
                    color: t.accent.withAlpha(12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: t.accent.withAlpha(30)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.assistant_direction, color: t.accent),
                      SizedBox(width: t.baseSpacing * 0.6),
                      Expanded(
                        child: Text(
                          widget.steps.isNotEmpty
                              ? widget.steps[_currentStepIndex]
                              : widget.currentStep ?? '沿主干道直行',
                          style: TextStyle(
                            color: t.onSurface,
                            fontWeight: FontWeight.bold,
                            fontSize: 14 * t.fontScale,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: t.baseSpacing),

                // Metrics Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildMetricCol('预计用时', '$_etaRemaining 分钟', t),
                    _buildMetricCol('剩余距离', '${_distanceRemaining.toStringAsFixed(1)} 公里', t),
                    _buildMetricCol('路线进度', '${(progress * 100).round()}%', t),
                  ],
                ),
                
                const Divider(height: 24),

                // Control panel
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton.icon(
                          icon: Icon(_isNavigating ? Icons.pause : Icons.play_arrow, color: t.accent),
                          label: Text(
                            _isNavigating ? '暂停' : '继续',
                            style: TextStyle(color: t.accent),
                          ),
                          onPressed: () {
                            setState(() {
                              _isNavigating = !_isNavigating;
                              if (_isNavigating) {
                                _startSimulation();
                              } else {
                                _progressController.stop();
                                _simulationTimer?.cancel();
                              }
                            });
                          },
                        ),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.open_in_new, size: 14),
                          label: const Text('外部导航', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: t.accent.withAlpha(30),
                            foregroundColor: t.accent,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: _launchExternalMap,
                        ),
                        TextButton(
                          style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                          onPressed: () {
                            final action = widget.events?['onCancelNavigation'] ?? 'navigation.cancel';
                            widget.onEvent?.call(action, {});
                            _progressController.stop();
                            _simulationTimer?.cancel();
                            setState(() {
                              _isNavigating = false;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('导航已取消')),
                            );
                          },
                          child: const Text('取消'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '模拟驾驶控制',
                          style: TextStyle(color: t.onSurface.withAlpha(100), fontSize: 11),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline, size: 18),
                              tooltip: '减速',
                              onPressed: () {
                                setState(() {
                                  _simulatedSpeed = max(20.0, _simulatedSpeed - 15.0);
                                });
                              },
                            ),
                            Text(
                              '${_simulatedSpeed.round()} KM/H',
                              style: TextStyle(color: t.accent, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline, size: 18),
                              tooltip: '加速',
                              onPressed: () {
                                setState(() {
                                  _simulatedSpeed = min(150.0, _simulatedSpeed + 15.0);
                                });
                              },
                            ),
                          ],
                        ),
                      ],
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

  Widget _buildMetricCol(String label, String val, ThemeTokens t) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: t.onSurface.withAlpha(100),
            fontSize: 10 * t.fontScale,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          val,
          style: TextStyle(
            color: t.onSurface,
            fontSize: 18 * t.fontScale,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class NavigationMapPainter extends CustomPainter {
  final double progress;
  final Color accentColor;
  final Color onSurfaceColor;

  NavigationMapPainter({
    required this.progress,
    required this.accentColor,
    required this.onSurfaceColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw Grid Background
    final gridPaint = Paint()
      ..color = onSurfaceColor.withAlpha(10)
      ..strokeWidth = 1.0;

    double spacing = 20.0;
    for (double i = 0; i < size.width; i += spacing) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), gridPaint);
    }
    for (double i = 0; i < size.height; i += spacing) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), gridPaint);
    }

    // 2. Define route nodes (futuristic zig-zag route)
    final nodes = [
      Offset(size.width * 0.1, size.height * 0.8),
      Offset(size.width * 0.25, size.height * 0.8),
      Offset(size.width * 0.25, size.height * 0.45),
      Offset(size.width * 0.55, size.height * 0.45),
      Offset(size.width * 0.55, size.height * 0.2),
      Offset(size.width * 0.9, size.height * 0.2),
    ];

    // Draw full road layout
    final roadPaint = Paint()
      ..color = onSurfaceColor.withAlpha(20)
      ..strokeWidth = 8.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path()..moveTo(nodes[0].dx, nodes[0].dy);
    for (int i = 1; i < nodes.length; i++) {
      path.lineTo(nodes[i].dx, nodes[i].dy);
    }
    canvas.drawPath(path, roadPaint);

    // Draw active navigation path (colored neon line)
    final routePaint = Paint()
      ..color = accentColor.withAlpha(220)
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final activePath = Path()..moveTo(nodes[0].dx, nodes[0].dy);

    // Calculate position along path segments
    double totalPathLength = 0;
    List<double> segmentLengths = [];
    for (int i = 0; i < nodes.length - 1; i++) {
      double len = _distanceBetween(nodes[i], nodes[i + 1]);
      segmentLengths.add(len);
      totalPathLength += len;
    }

    double currentLengthLimit = progress * totalPathLength;
    double currentAccumulated = 0;
    Offset currentDotPosition = nodes[0];

    for (int i = 0; i < nodes.length - 1; i++) {
      double segLen = segmentLengths[i];
      if (currentAccumulated + segLen <= currentLengthLimit) {
        activePath.lineTo(nodes[i + 1].dx, nodes[i + 1].dy);
        currentAccumulated += segLen;
      } else {
        // interpolate segment
        double remainingRatio = (currentLengthLimit - currentAccumulated) / segLen;
        double dx = nodes[i].dx + (nodes[i + 1].dx - nodes[i].dx) * remainingRatio;
        double dy = nodes[i].dy + (nodes[i + 1].dy - nodes[i].dy) * remainingRatio;
        currentDotPosition = Offset(dx, dy);
        activePath.lineTo(dx, dy);
        break;
      }
    }

    // Draw active colored route path
    canvas.drawPath(activePath, routePaint);

    // Draw start & finish markers
    final flagPaint = Paint()..color = Colors.greenAccent;
    canvas.drawCircle(nodes[0], 5, flagPaint); // Start dot

    final destPaint = Paint()
      ..color = Colors.redAccent
      ..style = PaintingStyle.fill;
    canvas.drawCircle(nodes.last, 6, destPaint); // Destination dot

    // Draw destination outer glowing ring
    final glowPaint = Paint()
      ..color = Colors.redAccent.withAlpha(100)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(nodes.last, 12, glowPaint);

    // Draw vehicle / user dot indicator
    final vehiclePaint = Paint()..color = accentColor;
    canvas.drawCircle(currentDotPosition, 6, vehiclePaint);

    // Vehicle outer aura
    final vehicleAuraPaint = Paint()
      ..color = accentColor.withAlpha(60)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(currentDotPosition, 14, vehicleAuraPaint);
  }

  double _distanceBetween(Offset p1, Offset p2) {
    return sqrt(pow(p2.dx - p1.dx, 2) + pow(p2.dy - p1.dy, 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
