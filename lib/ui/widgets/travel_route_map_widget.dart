import 'dart:math';
import 'package:flutter/material.dart';

class RoutePoint {
  final double lat;
  final double lon;
  final String? label;

  RoutePoint(this.lat, this.lon, {this.label});
}

class TravelRouteMapWidget extends StatelessWidget {
  final List<RoutePoint> routePoints;
  final double currentDistanceKm;
  final bool isLiveTracking;

  const TravelRouteMapWidget({
    super.key,
    required this.routePoints,
    required this.currentDistanceKm,
    this.isLiveTracking = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Stack(
        children: [
          // Map Canvas Painter
          SizedBox(
            height: 220,
            width: double.infinity,
            child: CustomPaint(
              painter: _MapRoutePainter(
                routePoints: routePoints,
                isDark: isDark,
              ),
            ),
          ),

          // Map Header Overlay
          Positioned(
            top: 10,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? Colors.black.withValues(alpha: 0.7) : Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isLiveTracking ? Icons.gps_fixed : Icons.map,
                    size: 16,
                    color: isLiveTracking ? Colors.green : Colors.blue,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isLiveTracking ? 'LIVE GPS TRACKING' : 'TRAVEL ROUTE MAP',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Distance HUD Overlay
          Positioned(
            bottom: 10,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.shade900,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 4)],
              ),
              child: Text(
                '${currentDistanceKm.toStringAsFixed(2)} km',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapRoutePainter extends CustomPainter {
  final List<RoutePoint> routePoints;
  final bool isDark;

  _MapRoutePainter({required this.routePoints, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw Map Background Grid & Roads
    final bgPaint = Paint()..color = isDark ? const Color(0xFF1E2638) : const Color(0xFFEBF1F5);
    canvas.drawRect(Offset.zero & size, bgPaint);

    final gridPaint = Paint()
      ..color = (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05))
      ..strokeWidth = 1.0;

    for (double i = 0; i < size.width; i += 30) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), gridPaint);
    }
    for (double j = 0; j < size.height; j += 30) {
      canvas.drawLine(Offset(0, j), Offset(size.width, j), gridPaint);
    }

    // Secondary Map Road network lines
    final roadPaint = Paint()
      ..color = (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white)
      ..strokeWidth = 8.0
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(0, size.height * 0.4), Offset(size.width, size.height * 0.6), roadPaint);
    canvas.drawLine(Offset(size.width * 0.3, 0), Offset(size.width * 0.7, size.height), roadPaint);

    if (routePoints.isEmpty) return;

    // 2. Plot Route Trail
    final path = Path();
    final points = _normalizePoints(routePoints, size);

    if (points.isNotEmpty) {
      path.moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
    }

    // Outer Glow / Route Border
    final routeBorderPaint = Paint()
      ..color = Colors.blue.shade900
      ..strokeWidth = 6.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, routeBorderPaint);

    // Inner Active Route Line
    final routePaint = Paint()
      ..color = Colors.cyanAccent
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, routePaint);

    // 3. Draw Route Markers (Start Pin, Checkpoints, End Pin)
    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      if (i == 0) {
        // Start Marker (Green)
        _drawMarkerPin(canvas, p, Colors.green, 'START');
      } else if (i == points.length - 1) {
        // Current / End Marker (Red)
        _drawMarkerPin(canvas, p, Colors.redAccent, 'CURRENT');
      } else if (i % 2 == 0) {
        // Checkpoint Dot
        canvas.drawCircle(p, 4, Paint()..color = Colors.amber);
      }
    }
  }

  void _drawMarkerPin(Canvas canvas, Offset offset, Color color, String label) {
    // Pin Shadow
    canvas.drawCircle(offset.translate(0, 2), 7, Paint()..color = Colors.black38);
    // Pin Outer
    canvas.drawCircle(offset, 6, Paint()..color = color);
    // Pin Inner Dot
    canvas.drawCircle(offset, 2.5, Paint()..color = Colors.white);
  }

  List<Offset> _normalizePoints(List<RoutePoint> points, Size size) {
    if (points.isEmpty) return [];
    if (points.length == 1) return [Offset(size.width / 2, size.height / 2)];

    double minLat = points.first.lat;
    double maxLat = points.first.lat;
    double minLon = points.first.lon;
    double maxLon = points.first.lon;

    for (var p in points) {
      minLat = min(minLat, p.lat);
      maxLat = max(maxLat, p.lat);
      minLon = min(minLon, p.lon);
      maxLon = max(maxLon, p.lon);
    }

    final latSpan = max(maxLat - minLat, 0.001);
    final lonSpan = max(maxLon - minLon, 0.001);

    const margin = 35.0;
    final usableW = size.width - (margin * 2);
    final usableH = size.height - (margin * 2);

    return points.map((p) {
      final x = margin + ((p.lon - minLon) / lonSpan) * usableW;
      final y = size.height - margin - (((p.lat - minLat) / latSpan) * usableH);
      return Offset(x, y);
    }).toList();
  }

  @override
  bool shouldRepaint(covariant _MapRoutePainter oldDelegate) => true;
}
