import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../services/road_routing_service.dart';

class RealRouteMapWidget extends StatefulWidget {
  final List<LatLng> routePoints;
  final double currentDistanceKm;
  final bool isLiveTracking;
  final bool isManualMapMode;
  final LatLng? manualStartPoint;
  final LatLng? manualEndPoint;
  final List<LatLng>? manualRoadPolyline;
  final Function(LatLng start, LatLng end, double calculatedRoadDistanceKm, List<LatLng> roadPolyline)?
      onManualPointsSelected;
  final LatLng? userCurrentLocation;
  final Future<void> Function()? onRequestLocation;

  const RealRouteMapWidget({
    super.key,
    required this.routePoints,
    required this.currentDistanceKm,
    this.isLiveTracking = false,
    this.isManualMapMode = false,
    this.manualStartPoint,
    this.manualEndPoint,
    this.manualRoadPolyline,
    this.onManualPointsSelected,
    this.userCurrentLocation,
    this.onRequestLocation,
  });

  @override
  State<RealRouteMapWidget> createState() => _RealRouteMapWidgetState();
}

class _RealRouteMapWidgetState extends State<RealRouteMapWidget> {
  late final MapController _mapController;
  LatLng? _manualStart;
  LatLng? _manualEnd;
  List<LatLng> _manualRoadPolyline = [];
  bool _isLocating = false;
  bool _isRouting = false;

  // Default fallback center (New Delhi / India center fallback if GPS not yet retrieved)
  static const LatLng _defaultCenter = LatLng(28.6139, 77.2090);

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _manualStart = widget.manualStartPoint;
    _manualEnd = widget.manualEndPoint;
    _manualRoadPolyline = widget.manualRoadPolyline ?? [];
  }

  @override
  void didUpdateWidget(covariant RealRouteMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _manualStart = widget.manualStartPoint;
    _manualEnd = widget.manualEndPoint;
    if (widget.manualRoadPolyline != null) {
      _manualRoadPolyline = widget.manualRoadPolyline!;
    }

    if (widget.userCurrentLocation != null && oldWidget.userCurrentLocation != widget.userCurrentLocation) {
      _mapController.move(widget.userCurrentLocation!, _mapController.camera.zoom);
    }
  }

  Future<void> _onMapTap(TapPosition tapPosition, LatLng point) async {
    if (!widget.isManualMapMode) return;

    if (_manualStart == null || (_manualStart != null && _manualEnd != null)) {
      setState(() {
        _manualStart = point;
        _manualEnd = null;
        _manualRoadPolyline.clear();
      });
    } else {
      setState(() {
        _manualEnd = point;
        _isRouting = true;
      });

      final routingService = RoadRoutingService();
      final result = await routingService.getRoadRoute(_manualStart!, _manualEnd!);

      if (mounted) {
        setState(() {
          _manualRoadPolyline = result.polylinePoints;
          _isRouting = false;
        });
        widget.onManualPointsSelected?.call(
          _manualStart!,
          _manualEnd!,
          result.distanceKm,
          result.polylinePoints,
        );
      }
    }
  }

  LatLng _getCenterLocation() {
    if (widget.userCurrentLocation != null) return widget.userCurrentLocation!;
    if (widget.routePoints.isNotEmpty) return widget.routePoints.last;
    if (_manualStart != null) return _manualStart!;
    return _defaultCenter;
  }

  Future<void> _handleRecenter() async {
    setState(() => _isLocating = true);
    try {
      if (widget.onRequestLocation != null) {
        await widget.onRequestLocation!();
      }
      if (widget.userCurrentLocation != null) {
        _mapController.move(widget.userCurrentLocation!, 16.0);
      } else {
        _mapController.move(_getCenterLocation(), 15.0);
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  void _openFullScreenMap(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FullScreenMapScreen(
          routePoints: widget.routePoints,
          currentDistanceKm: widget.currentDistanceKm,
          isLiveTracking: widget.isLiveTracking,
          isManualMapMode: widget.isManualMapMode,
          manualStartPoint: _manualStart,
          manualEndPoint: _manualEnd,
          manualRoadPolyline: _manualRoadPolyline,
          userCurrentLocation: widget.userCurrentLocation,
          onRequestLocation: widget.onRequestLocation,
          onManualPointsSelected: (start, end, roadDistKm, polyline) {
            setState(() {
              _manualStart = start;
              _manualEnd = end;
              _manualRoadPolyline = polyline;
            });
            widget.onManualPointsSelected?.call(start, end, roadDistKm, polyline);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final center = _getCenterLocation();

    // Determine markers
    final List<Marker> markers = [];

    // Current User Location Marker (Pulsing / Blue dot)
    if (widget.userCurrentLocation != null) {
      markers.add(
        Marker(
          point: widget.userCurrentLocation!,
          width: 48,
          height: 48,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                ),
              ),
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: Colors.blue.shade600,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 4)],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (widget.isManualMapMode) {
      if (_manualStart != null) {
        markers.add(
          Marker(
            point: _manualStart!,
            width: 40,
            height: 40,
            child: const Icon(Icons.location_on, color: Colors.green, size: 38),
          ),
        );
      }
      if (_manualEnd != null) {
        markers.add(
          Marker(
            point: _manualEnd!,
            width: 40,
            height: 40,
            child: const Icon(Icons.flag, color: Colors.redAccent, size: 36),
          ),
        );
      }
    } else {
      if (widget.routePoints.isNotEmpty) {
        // Start marker
        markers.add(
          Marker(
            point: widget.routePoints.first,
            width: 36,
            height: 36,
            child: const Icon(Icons.trip_origin, color: Colors.green, size: 30),
          ),
        );
        // Current / End location marker
        markers.add(
          Marker(
            point: widget.routePoints.last,
            width: 44,
            height: 44,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.blueAccent,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6)],
              ),
              child: const Icon(Icons.navigation, color: Colors.white, size: 24),
            ),
          ),
        );
      }
    }

    // Determine Polyline
    final List<Polyline> polylines = [];
    if (widget.isManualMapMode && _manualStart != null && _manualEnd != null) {
      final polylinePoints = _manualRoadPolyline.isNotEmpty
          ? _manualRoadPolyline
          : [_manualStart!, _manualEnd!];

      polylines.add(
        Polyline(
          points: polylinePoints,
          strokeWidth: 4.5,
          color: Colors.blue.shade700,
          borderStrokeWidth: 1.5,
          borderColor: Colors.blue.shade900,
        ),
      );
    } else if (widget.routePoints.length >= 2) {
      polylines.add(
        Polyline(
          points: widget.routePoints,
          strokeWidth: 4.5,
          color: Colors.cyanAccent,
          borderStrokeWidth: 2.0,
          borderColor: Colors.blue.shade900,
        ),
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        height: 300,
        child: Stack(
          children: [
            // OpenStreetMap Interactive Canvas
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: center,
                initialZoom: 15.0,
                onTap: _onMapTap,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.ridemate.app',
                  maxZoom: 19,
                ),
                if (polylines.isNotEmpty) PolylineLayer(polylines: polylines),
                if (markers.isNotEmpty) MarkerLayer(markers: markers),
              ],
            ),

            // Top Status Header Badge
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black87 : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isRouting)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      Icon(
                        widget.isLiveTracking
                            ? Icons.gps_fixed
                            : (widget.isManualMapMode ? Icons.alt_route : Icons.map),
                        size: 16,
                        color: widget.isLiveTracking ? Colors.green : Colors.blue,
                      ),
                    const SizedBox(width: 6),
                    Text(
                      widget.isLiveTracking
                          ? 'LIVE GPS TRACKING'
                          : (widget.isManualMapMode
                              ? (_isRouting
                                  ? 'CALCULATING ROAD ROUTE...'
                                  : (_manualStart == null
                                      ? 'TAP MAP FOR START POINT'
                                      : (_manualEnd == null
                                          ? 'TAP MAP FOR END POINT'
                                          : 'ROAD ROUTE CALCULATED')))
                              : (widget.userCurrentLocation != null ? 'CURRENT LOCATION' : 'OPENSTREETMAP')),
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

            // Full Screen Mode Floating Button
            Positioned(
              top: 12,
              right: 12,
              child: InkWell(
                onTap: () => _openFullScreenMap(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black87 : Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                  ),
                  child: Icon(
                    Icons.fullscreen,
                    size: 20,
                    color: Colors.blue.shade800,
                  ),
                ),
              ),
            ),

            // Distance HUD Overlay Badge
            Positioned(
              bottom: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade900,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 4)],
                ),
                child: Text(
                  '${widget.currentDistanceKm.toStringAsFixed(2)} km',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ),

            // Recenter Map Floating Button
            Positioned(
              bottom: 12,
              left: 12,
              child: FloatingActionButton.small(
                heroTag: 'recenter_map_btn',
                backgroundColor: isDark ? Colors.grey.shade800 : Colors.white,
                foregroundColor: Colors.blue,
                onPressed: _handleRecenter,
                child: _isLocating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : const Icon(Icons.my_location),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FullScreenMapScreen extends StatefulWidget {
  final List<LatLng> routePoints;
  final double currentDistanceKm;
  final bool isLiveTracking;
  final bool isManualMapMode;
  final LatLng? manualStartPoint;
  final LatLng? manualEndPoint;
  final List<LatLng>? manualRoadPolyline;
  final Function(LatLng start, LatLng end, double calculatedRoadDistanceKm, List<LatLng> roadPolyline)?
      onManualPointsSelected;
  final LatLng? userCurrentLocation;
  final Future<void> Function()? onRequestLocation;

  const FullScreenMapScreen({
    super.key,
    required this.routePoints,
    required this.currentDistanceKm,
    required this.isLiveTracking,
    required this.isManualMapMode,
    this.manualStartPoint,
    this.manualEndPoint,
    this.manualRoadPolyline,
    this.onManualPointsSelected,
    this.userCurrentLocation,
    this.onRequestLocation,
  });

  @override
  State<FullScreenMapScreen> createState() => _FullScreenMapScreenState();
}

class _FullScreenMapScreenState extends State<FullScreenMapScreen> {
  late final MapController _mapController;
  LatLng? _manualStart;
  LatLng? _manualEnd;
  List<LatLng> _manualRoadPolyline = [];
  double _distanceKm = 0.0;
  bool _isLocating = false;
  bool _isRouting = false;

  static const LatLng _defaultCenter = LatLng(28.6139, 77.2090);

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _manualStart = widget.manualStartPoint;
    _manualEnd = widget.manualEndPoint;
    _manualRoadPolyline = widget.manualRoadPolyline ?? [];
    _distanceKm = widget.currentDistanceKm;
  }

  Future<void> _onMapTap(TapPosition tapPosition, LatLng point) async {
    if (!widget.isManualMapMode) return;

    if (_manualStart == null || (_manualStart != null && _manualEnd != null)) {
      setState(() {
        _manualStart = point;
        _manualEnd = null;
        _manualRoadPolyline.clear();
      });
    } else {
      setState(() {
        _manualEnd = point;
        _isRouting = true;
      });

      final routingService = RoadRoutingService();
      final result = await routingService.getRoadRoute(_manualStart!, _manualEnd!);

      if (mounted) {
        setState(() {
          _manualRoadPolyline = result.polylinePoints;
          _distanceKm = result.distanceKm;
          _isRouting = false;
        });
        widget.onManualPointsSelected?.call(
          _manualStart!,
          _manualEnd!,
          result.distanceKm,
          result.polylinePoints,
        );
      }
    }
  }

  LatLng _getCenterLocation() {
    if (widget.userCurrentLocation != null) return widget.userCurrentLocation!;
    if (widget.routePoints.isNotEmpty) return widget.routePoints.last;
    if (_manualStart != null) return _manualStart!;
    return _defaultCenter;
  }

  Future<void> _handleRecenter() async {
    setState(() => _isLocating = true);
    try {
      if (widget.onRequestLocation != null) {
        await widget.onRequestLocation!();
      }
      if (widget.userCurrentLocation != null) {
        _mapController.move(widget.userCurrentLocation!, 16.0);
      } else {
        _mapController.move(_getCenterLocation(), 15.0);
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final center = _getCenterLocation();

    final List<Marker> markers = [];

    if (widget.userCurrentLocation != null) {
      markers.add(
        Marker(
          point: widget.userCurrentLocation!,
          width: 52,
          height: 52,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                ),
              ),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.blue.shade600,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 4)],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (widget.isManualMapMode) {
      if (_manualStart != null) {
        markers.add(
          Marker(
            point: _manualStart!,
            width: 44,
            height: 44,
            child: const Icon(Icons.location_on, color: Colors.green, size: 42),
          ),
        );
      }
      if (_manualEnd != null) {
        markers.add(
          Marker(
            point: _manualEnd!,
            width: 44,
            height: 44,
            child: const Icon(Icons.flag, color: Colors.redAccent, size: 40),
          ),
        );
      }
    } else {
      if (widget.routePoints.isNotEmpty) {
        markers.add(
          Marker(
            point: widget.routePoints.first,
            width: 40,
            height: 40,
            child: const Icon(Icons.trip_origin, color: Colors.green, size: 34),
          ),
        );
        markers.add(
          Marker(
            point: widget.routePoints.last,
            width: 48,
            height: 48,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.blueAccent,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6)],
              ),
              child: const Icon(Icons.navigation, color: Colors.white, size: 28),
            ),
          ),
        );
      }
    }

    final List<Polyline> polylines = [];
    if (widget.isManualMapMode && _manualStart != null && _manualEnd != null) {
      final polylinePoints = _manualRoadPolyline.isNotEmpty
          ? _manualRoadPolyline
          : [_manualStart!, _manualEnd!];

      polylines.add(
        Polyline(
          points: polylinePoints,
          strokeWidth: 5.5,
          color: Colors.blue.shade700,
          borderStrokeWidth: 2.0,
          borderColor: Colors.blue.shade900,
        ),
      );
    } else if (widget.routePoints.length >= 2) {
      polylines.add(
        Polyline(
          points: widget.routePoints,
          strokeWidth: 5.5,
          color: Colors.cyanAccent,
          borderStrokeWidth: 2.0,
          borderColor: Colors.blue.shade900,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isLiveTracking
              ? 'Full Screen Live GPS Map'
              : (widget.isManualMapMode ? 'Full Screen Road Route Picker' : 'Full Screen Map'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: 'Done',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 15.5,
              onTap: _onMapTap,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.ridemate.app',
                maxZoom: 19,
              ),
              if (polylines.isNotEmpty) PolylineLayer(polylines: polylines),
              if (markers.isNotEmpty) MarkerLayer(markers: markers),
            ],
          ),

          // Header Status Badge
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? Colors.black87 : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isRouting)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Icon(
                      widget.isLiveTracking
                          ? Icons.gps_fixed
                          : (widget.isManualMapMode ? Icons.alt_route : Icons.map),
                      size: 18,
                      color: widget.isLiveTracking ? Colors.green : Colors.blue,
                    ),
                  const SizedBox(width: 8),
                  Text(
                    widget.isLiveTracking
                        ? 'LIVE GPS TRACKING'
                        : (widget.isManualMapMode
                            ? (_isRouting
                                ? 'CALCULATING ROAD ROUTE...'
                                : (_manualStart == null
                                    ? 'TAP MAP TO PLACE START PIN'
                                    : (_manualEnd == null
                                        ? 'TAP MAP TO PLACE DESTINATION PIN'
                                        : 'ROAD ROUTE CALCULATED')))
                            : 'FULL SCREEN MAP'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Distance HUD Badge
          Positioned(
            bottom: 20,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.blue.shade900,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6)],
              ),
              child: Text(
                '${_distanceKm.toStringAsFixed(2)} km',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ),

          // Recenter FAB
          Positioned(
            bottom: 20,
            left: 16,
            child: FloatingActionButton(
              heroTag: 'fullscreen_recenter_fab',
              backgroundColor: isDark ? Colors.grey.shade800 : Colors.white,
              foregroundColor: Colors.blue,
              onPressed: _handleRecenter,
              child: _isLocating
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : const Icon(Icons.my_location),
            ),
          ),
        ],
      ),
    );
  }
}
