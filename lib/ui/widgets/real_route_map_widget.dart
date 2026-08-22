import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class RealRouteMapWidget extends StatefulWidget {
  final List<LatLng> routePoints;
  final double currentDistanceKm;
  final bool isLiveTracking;
  final bool isManualMapMode;
  final LatLng? manualStartPoint;
  final LatLng? manualEndPoint;
  final Function(LatLng start, LatLng end, double calculatedDistanceKm)? onManualPointsSelected;
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
  bool _isLocating = false;

  // Default fallback center (New Delhi / India center fallback if GPS not yet retrieved)
  static const LatLng _defaultCenter = LatLng(28.6139, 77.2090);

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _manualStart = widget.manualStartPoint;
    _manualEnd = widget.manualEndPoint;
  }

  @override
  void didUpdateWidget(covariant RealRouteMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _manualStart = widget.manualStartPoint;
    _manualEnd = widget.manualEndPoint;

    if (widget.userCurrentLocation != null && oldWidget.userCurrentLocation != widget.userCurrentLocation) {
      _mapController.move(widget.userCurrentLocation!, _mapController.camera.zoom);
    }
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    if (!widget.isManualMapMode) return;

    setState(() {
      if (_manualStart == null || (_manualStart != null && _manualEnd != null)) {
        _manualStart = point;
        _manualEnd = null;
      } else {
        _manualEnd = point;
        final distMeters = Geolocator.distanceBetween(
          _manualStart!.latitude,
          _manualStart!.longitude,
          _manualEnd!.latitude,
          _manualEnd!.longitude,
        );
        final distKm = distMeters / 1000.0;
        widget.onManualPointsSelected?.call(_manualStart!, _manualEnd!, distKm);
      }
    });
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
      polylines.add(
        Polyline(
          points: [_manualStart!, _manualEnd!],
          strokeWidth: 4.0,
          color: Colors.blue.shade700,
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
                    Icon(
                      widget.isLiveTracking
                          ? Icons.gps_fixed
                          : (widget.isManualMapMode ? Icons.add_location_alt : Icons.map),
                      size: 16,
                      color: widget.isLiveTracking ? Colors.green : Colors.blue,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      widget.isLiveTracking
                          ? 'LIVE GPS TRACKING'
                          : (widget.isManualMapMode
                              ? (_manualStart == null
                                  ? 'TAP MAP FOR START POINT'
                                  : (_manualEnd == null ? 'TAP MAP FOR END POINT' : 'ROUTE SELECTED'))
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
