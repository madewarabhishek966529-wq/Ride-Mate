import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../services/location_search_service.dart';
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
  final Function(String placeName, LatLng location)? onPlaceSearched;
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
    this.onPlaceSearched,
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

  // Location search state
  final _searchController = TextEditingController();
  final _searchService = LocationSearchService();
  List<LocationSearchResult> _searchResults = [];
  bool _isSearching = false;
  Timer? _debounceTimer;

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
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
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

  void _onSearchQueryChanged(String query) {
    _debounceTimer?.cancel();
    if (query.trim().length < 2) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    _debounceTimer = Timer(const Duration(milliseconds: 400), () async {
      final results = await _searchService.searchPlaces(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    });
  }

  Future<void> _selectSearchedLocation(LocationSearchResult result) async {
    _searchController.text = result.displayName.split(',').first;
    setState(() {
      _searchResults = [];
    });

    _mapController.move(result.location, 16.0);
    widget.onPlaceSearched?.call(result.displayName, result.location);

    if (widget.isManualMapMode) {
      if (_manualStart == null || (_manualStart != null && _manualEnd != null)) {
        setState(() {
          _manualStart = result.location;
          _manualEnd = null;
          _manualRoadPolyline.clear();
        });
      } else {
        setState(() {
          _manualEnd = result.location;
          _isRouting = true;
        });

        final routingService = RoadRoutingService();
        final routeResult = await routingService.getRoadRoute(_manualStart!, _manualEnd!);

        if (mounted) {
          setState(() {
            _manualRoadPolyline = routeResult.polylinePoints;
            _isRouting = false;
          });
          widget.onManualPointsSelected?.call(
            _manualStart!,
            _manualEnd!,
            routeResult.distanceKm,
            routeResult.polylinePoints,
          );
        }
      }
    }
  }

  Future<void> _onMapTap(TapPosition tapPosition, LatLng point) async {
    // Dismiss search results if open
    if (_searchResults.isNotEmpty) {
      setState(() => _searchResults = []);
    }

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
          onPlaceSearched: widget.onPlaceSearched,
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

    final List<Marker> markers = [];

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
        markers.add(
          Marker(
            point: widget.routePoints.first,
            width: 36,
            height: 36,
            child: const Icon(Icons.trip_origin, color: Colors.green, size: 30),
          ),
        );
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
        height: 320,
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

            // Location Search Bar Overlay
            Positioned(
              top: 10,
              left: 10,
              right: 52,
              child: Column(
                children: [
                  Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey.shade900 : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black87),
                      onChanged: _onSearchQueryChanged,
                      decoration: InputDecoration(
                        hintText: 'Search city, street or location...',
                        hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                        prefixIcon: const Icon(Icons.search, size: 18),
                        suffixIcon: _isSearching
                            ? const Padding(
                                padding: EdgeInsets.all(10.0),
                                child: SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
                              )
                            : (_searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 16),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchResults = []);
                                    },
                                  )
                                : null),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  if (_searchResults.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      constraints: const BoxConstraints(maxHeight: 150),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey.shade900 : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6)],
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _searchResults.length,
                        separatorBuilder: (ctx, idx) => const Divider(height: 1),

                        itemBuilder: (context, index) {
                          final item = _searchResults[index];
                          return ListTile(
                            dense: true,
                            visualDensity: VisualDensity.compact,
                            leading: const Icon(Icons.location_on, size: 16, color: Colors.redAccent),
                            title: Text(
                              item.displayName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                            onTap: () => _selectSearchedLocation(item),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),

            // Full Screen Mode Button
            Positioned(
              top: 10,
              right: 10,
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

            // Distance HUD Badge
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
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isRouting) ...[
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      '${widget.currentDistanceKm.toStringAsFixed(2)} km',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),

              ),
            ),

            // Recenter Map FAB
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
  final Function(String placeName, LatLng location)? onPlaceSearched;
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
    this.onPlaceSearched,
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

  final _searchController = TextEditingController();
  final _searchService = LocationSearchService();
  List<LocationSearchResult> _searchResults = [];
  bool _isSearching = false;
  Timer? _debounceTimer;

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

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchQueryChanged(String query) {
    _debounceTimer?.cancel();
    if (query.trim().length < 2) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    _debounceTimer = Timer(const Duration(milliseconds: 400), () async {
      final results = await _searchService.searchPlaces(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    });
  }

  Future<void> _selectSearchedLocation(LocationSearchResult result) async {
    _searchController.text = result.displayName.split(',').first;
    setState(() {
      _searchResults = [];
    });

    _mapController.move(result.location, 16.0);
    widget.onPlaceSearched?.call(result.displayName, result.location);

    if (widget.isManualMapMode) {
      if (_manualStart == null || (_manualStart != null && _manualEnd != null)) {
        setState(() {
          _manualStart = result.location;
          _manualEnd = null;
          _manualRoadPolyline.clear();
        });
      } else {
        setState(() {
          _manualEnd = result.location;
          _isRouting = true;
        });

        final routingService = RoadRoutingService();
        final routeResult = await routingService.getRoadRoute(_manualStart!, _manualEnd!);

        if (mounted) {
          setState(() {
            _manualRoadPolyline = routeResult.polylinePoints;
            _distanceKm = routeResult.distanceKm;
            _isRouting = false;
          });
          widget.onManualPointsSelected?.call(
            _manualStart!,
            _manualEnd!,
            routeResult.distanceKm,
            routeResult.polylinePoints,
          );
        }
      }
    }
  }

  Future<void> _onMapTap(TapPosition tapPosition, LatLng point) async {
    if (_searchResults.isNotEmpty) {
      setState(() => _searchResults = []);
    }

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

          // Location Search Bar Overlay in Full Screen Mode
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Column(
              children: [
                Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade900 : Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 8)],
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black87),
                    onChanged: _onSearchQueryChanged,
                    decoration: InputDecoration(
                      hintText: 'Search city, street or location name...',
                      hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _isSearching
                          ? const Padding(
                              padding: EdgeInsets.all(12.0),
                              child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                            )
                          : (_searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchResults = []);
                                  },
                                )
                              : null),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                if (_searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    constraints: const BoxConstraints(maxHeight: 200),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey.shade900 : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 8)],
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _searchResults.length,
                      separatorBuilder: (ctx, idx) => const Divider(height: 1),

                      itemBuilder: (context, index) {
                        final item = _searchResults[index];
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.location_on, size: 18, color: Colors.redAccent),
                          title: Text(
                            item.displayName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                          onTap: () => _selectSearchedLocation(item),
                        );
                      },
                    ),
                  ),
              ],
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
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isRouting) ...[
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    '${_distanceKm.toStringAsFixed(2)} km',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
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
