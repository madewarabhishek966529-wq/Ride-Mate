import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';
import '../../domain/models/friend.dart';
import '../../domain/models/ride.dart';
import '../../domain/models/vehicle.dart';
import '../../providers/providers.dart';
import '../../services/road_routing_service.dart';
import '../widgets/gradient_button.dart';
import '../widgets/real_route_map_widget.dart';

class RideTrackingScreen extends ConsumerStatefulWidget {
  const RideTrackingScreen({super.key});

  @override
  ConsumerState<RideTrackingScreen> createState() => _RideTrackingScreenState();
}

class _RideTrackingScreenState extends ConsumerState<RideTrackingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController(text: 'Ride');
  final _manualDistanceController = TextEditingController();
  final _mileageController = TextEditingController(text: '45.0');
  final _fuelPriceController = TextEditingController(text: '100.0');

  String? _selectedVehicleId;
  String _trackingMode = 'GPS'; // 'GPS' or 'Manual'
  bool _isRoundTrip = false; // One-Way vs Round-Trip (Return)
  String _paidBy = 'ME'; // 'ME' or friendId
  final Set<String> _selectedParticipantIds = {'ME'}; // 'ME' + friend IDs

  // Real GPS tracking state
  bool _isTracking = false;
  double _gpsDistanceKm = 0.0;
  final List<LatLng> _gpsRoutePoints = [];
  StreamSubscription<Position>? _positionStreamSub;
  LatLng? _currentLocation;

  // Diagnostic location state
  bool _isFetchingLocation = false;
  String _locationStatusMessage = 'Checking GPS...';
  bool _locationServiceEnabled = true;
  LocationPermission _locationPermission = LocationPermission.denied;

  // Manual Map selection state (Multi-Stop Waypoints)
  List<LatLng> _manualWaypoints = [];
  List<LatLng> _manualRoadPolyline = [];
  double _rawOneWayDistanceKm = 0.0;

  @override
  void initState() {
    super.initState();
    _checkInitialLocation();
  }

  @override
  void dispose() {
    _positionStreamSub?.cancel();
    _nameController.dispose();
    _manualDistanceController.dispose();
    _mileageController.dispose();
    _fuelPriceController.dispose();
    super.dispose();
  }

  Future<void> _checkInitialLocation() async {
    await _requestCurrentLocation(quiet: true);
  }

  /// Multi-tier robust location fetch strategy
  Future<void> _requestCurrentLocation({bool quiet = false}) async {
    if (!mounted) return;
    setState(() {
      _isFetchingLocation = true;
      _locationStatusMessage = 'Requesting GPS location...';
    });

    try {
      _locationServiceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!_locationServiceEnabled) {
        setState(() {
          _isFetchingLocation = false;
          _locationStatusMessage = 'GPS / Location services disabled on device.';
        });
        if (!quiet && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('GPS is turned off. Tap "Open Settings" to turn on location.'),
              backgroundColor: Colors.orange.shade800,
              action: SnackBarAction(
                label: 'SETTINGS',
                textColor: Colors.white,
                onPressed: () => Geolocator.openLocationSettings(),
              ),
            ),
          );
        }
        return;
      }

      _locationPermission = await Geolocator.checkPermission();
      if (_locationPermission == LocationPermission.denied) {
        _locationPermission = await Geolocator.requestPermission();
      }

      if (_locationPermission == LocationPermission.denied) {
        setState(() {
          _isFetchingLocation = false;
          _locationStatusMessage = 'Location permission denied by user.';
        });
        if (!quiet && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission denied.')),
          );
        }
        return;
      }

      if (_locationPermission == LocationPermission.deniedForever) {
        setState(() {
          _isFetchingLocation = false;
          _locationStatusMessage = 'Location permission permanently denied. Open App Settings.';
        });
        if (!quiet && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Location permission is permanently denied.'),
              action: SnackBarAction(
                label: 'APP SETTINGS',
                onPressed: () => Geolocator.openAppSettings(),
              ),
            ),
          );
        }
        return;
      }

      Position? pos = await Geolocator.getLastKnownPosition();

      if (pos == null) {
        try {
          pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: Duration(seconds: 6),
            ),
          );
        } catch (_) {
          try {
            pos = await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.lowest,
                timeLimit: Duration(seconds: 4),
              ),
            );
          } catch (e) {
            pos = null;
          }
        }
      }

      if (pos != null && mounted) {
        setState(() {
          _currentLocation = LatLng(pos!.latitude, pos.longitude);
          _isFetchingLocation = false;
          _locationStatusMessage =
              'GPS Active (${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)})';
        });
        if (!quiet) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location retrieved successfully!'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else if (mounted) {
        setState(() {
          _isFetchingLocation = false;
          _locationStatusMessage = 'GPS signal searching... Tap map or recenter button to try again.';
        });
        if (!quiet) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unable to acquire GPS signal. Try outdoors or tap map.')),
          );
        }
      }
    } on MissingPluginException {
      if (mounted) {
        setState(() {
          _isFetchingLocation = false;
          _locationStatusMessage =
              'App Restart Required: Please stop & re-run the app (flutter run) to link native GPS plugins.';
        });
        if (!quiet) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please stop and re-run the app (flutter run) to compile native GPS plugin.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isFetchingLocation = false;
          _locationStatusMessage = 'Location error: $e';
        });
        if (!quiet) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Location error: $e')),
          );
        }
      }
    }
  }

  void _showAddBikeDialog() {
    final bikeNameController = TextEditingController();
    final bikeMileageController = TextEditingController(text: '45.0');
    final bikePriceController = TextEditingController(text: '100.0');
    bool isDefaultBike = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Add New Bike Profile'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: bikeNameController,
                      decoration: const InputDecoration(
                        labelText: 'Bike Name (e.g. Pulsar 150)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.two_wheeler),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: bikeMileageController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Average Mileage (km/L)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.speed),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: bikePriceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: "Today's Petrol Rate (₹/L)",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.local_gas_station),
                      ),
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      title: const Text('Set as Default Bike'),
                      value: isDefaultBike,
                      onChanged: (val) {
                        setDialogState(() {
                          isDefaultBike = val ?? false;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final name = bikeNameController.text.trim();
                    final mileage = double.tryParse(bikeMileageController.text.trim()) ?? 45.0;
                    final price = double.tryParse(bikePriceController.text.trim()) ?? 100.0;

                    if (name.isEmpty) return;

                    final newBike = Vehicle(
                      id: const Uuid().v4(),
                      name: name,
                      mileage: mileage,
                      defaultFuelPrice: price,
                      isDefault: isDefaultBike,
                    );

                    await ref.read(vehicleListProvider.notifier).addVehicle(newBike);

                    if (dialogContext.mounted) {
                      setState(() {
                        _selectedVehicleId = newBike.id;
                        _mileageController.text = newBike.mileage.toString();
                        _fuelPriceController.text = newBike.defaultFuelPrice.toString();
                      });
                      Navigator.of(dialogContext).pop();
                    }
                  },
                  child: const Text('Save Bike'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _startGpsTracking() async {
    if (_currentLocation == null) {
      await _requestCurrentLocation(quiet: false);
    }

    if (_currentLocation == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot start live tracking without GPS location fix.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      setState(() {
        _isTracking = true;
        _gpsDistanceKm = 0.0;
        _gpsRoutePoints.clear();
        _gpsRoutePoints.add(_currentLocation!);
      });

      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 2, // Trigger update when moved 2 meters
      );

      _positionStreamSub?.cancel();
      _positionStreamSub = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
        (Position position) {
          if (!mounted || !_isTracking) return;

          final newLatLng = LatLng(position.latitude, position.longitude);

          setState(() {
            if (_gpsRoutePoints.isNotEmpty) {
              final last = _gpsRoutePoints.last;
              final metersMoved = Geolocator.distanceBetween(
                last.latitude,
                last.longitude,
                newLatLng.latitude,
                newLatLng.longitude,
              );

              if (metersMoved > 1.0) {
                _gpsDistanceKm += (metersMoved / 1000.0);
                _gpsRoutePoints.add(newLatLng);
              }
            } else {
              _gpsRoutePoints.add(newLatLng);
            }
            _currentLocation = newLatLng;
          });
        },
        onError: (err) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('GPS Tracking Error: $err')),
            );
          }
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start GPS stream: $e')),
        );
      }
    }
  }

  void _stopGpsTracking() {
    _positionStreamSub?.cancel();
    _positionStreamSub = null;
    setState(() {
      _isTracking = false;
    });
  }

  Future<void> _saveRide(List<Vehicle> vehicles, List<Friend> friends) async {
    // 1. Validate Form Fields (Ride Name, Mileage, Petrol Price)
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please fill out all required fields marked in red.'),
          backgroundColor: Colors.orange.shade800,
        ),
      );
      return;
    }

    final mileage = double.tryParse(_mileageController.text.trim()) ?? 45.0;
    final fuelPrice = double.tryParse(_fuelPriceController.text.trim()) ?? 100.0;

    final selectedBike = vehicles.firstWhere(
      (v) => v.id == _selectedVehicleId,
      orElse: () => Vehicle(
        id: 'default',
        name: 'Bike',
        mileage: mileage,
        defaultFuelPrice: fuelPrice,
      ),
    );

    // 2. Resolve Effective Distance across GPS or Manual Map / Text Entry
    double rawKm = 0.0;
    if (_trackingMode == 'GPS' && _gpsDistanceKm > 0) {
      rawKm = _gpsDistanceKm;
    } else {
      rawKm = double.tryParse(_manualDistanceController.text.trim()) ?? 0.0;
      if (rawKm <= 0 && _gpsDistanceKm > 0) {
        rawKm = _gpsDistanceKm;
      }
    }

    // Multiply by 2 if Round-Trip / Return Trip selected
    final totalDistanceKm = _isRoundTrip ? (rawKm * 2) : rawKm;

    if (totalDistanceKm <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Distance is 0.0 km. Please tap points on the map, enter distance, or start Live GPS tracking.'),
          backgroundColor: Colors.orange.shade900,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'MANUAL MAP',
            textColor: Colors.white,
            onPressed: () {
              setState(() => _trackingMode = 'Manual');
            },
          ),
        ),
      );
      return;
    }

    // 3. Ensure Participants Selected
    if (_selectedParticipantIds.isEmpty) {
      _selectedParticipantIds.add('ME');
    }

    try {
      final fuelCalc = ref.read(fuelCalculationServiceProvider);
      final splitCalc = ref.read(splitCalculationServiceProvider);

      final fuelUsed = fuelCalc.calculateFuelUsed(totalDistanceKm, mileage);
      final fuelCost = fuelCalc.calculateFuelCost(fuelUsed, fuelPrice);

      final participantList = _selectedParticipantIds.toList();
      final shares = splitCalc.calculateEvenShares(fuelCost, participantList);

      final newRide = Ride(
        id: const Uuid().v4(),
        name: _nameController.text.trim(),
        date: DateTime.now(),
        vehicleId: selectedBike.id,
        vehicleName: selectedBike.name,
        mileage: mileage,
        fuelPrice: fuelPrice,
        distanceKm: totalDistanceKm,
        fuelUsedLiters: fuelUsed,
        totalFuelCost: fuelCost,
        trackingMode: _trackingMode,
        isRoundTrip: _isRoundTrip,
        stopCount: _manualWaypoints.length > 1 ? _manualWaypoints.length : 1,
        paidBy: _paidBy,
        participantIds: participantList,
        participantShares: shares,
      );

      await ref.read(rideListProvider.notifier).addRide(newRide);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ride saved successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save ride: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }


  void _updateManualDistanceDisplay() {
    final effectiveKm = _isRoundTrip ? (_rawOneWayDistanceKm * 2) : _rawOneWayDistanceKm;
    _manualDistanceController.text = effectiveKm.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final vehicles = ref.watch(vehicleListProvider);
    final friends = ref.watch(friendListProvider);

    // Auto-select Default Bike on screen load
    if (_selectedVehicleId == null && vehicles.isNotEmpty) {
      final defaultBike = vehicles.firstWhere((v) => v.isDefault, orElse: () => vehicles.first);
      _selectedVehicleId = defaultBike.id;
      _mileageController.text = defaultBike.mileage.toString();
      _fuelPriceController.text = defaultBike.defaultFuelPrice.toString();
    }

    final effectiveDistanceKm = _trackingMode == 'GPS'
        ? (_isRoundTrip ? _gpsDistanceKm * 2 : _gpsDistanceKm)
        : (double.tryParse(_manualDistanceController.text.trim()) ?? 0.0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Track & Split Ride'),
        actions: [
          IconButton(
            icon: _isFetchingLocation
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.my_location),
            tooltip: 'Get Current Location',
            onPressed: () => _requestCurrentLocation(quiet: false),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Bike Selector & Quick Add Button
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedVehicleId,
                      decoration: const InputDecoration(
                        labelText: 'Select Bike',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.two_wheeler),
                      ),
                      items: vehicles.map((v) {
                        return DropdownMenuItem(
                          value: v.id,
                          child: Text('${v.name} (${v.mileage.toStringAsFixed(0)} km/L)'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          final bike = vehicles.firstWhere((v) => v.id == val);
                          setState(() {
                            _selectedVehicleId = val;
                            _mileageController.text = bike.mileage.toString();
                            _fuelPriceController.text = bike.defaultFuelPrice.toString();
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: _showAddBikeDialog,
                    icon: const Icon(Icons.add),
                    tooltip: 'Add New Bike',
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Ride Title / Destination Name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Ride Name / Destination',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Enter ride name' : null,
              ),
              const SizedBox(height: 16),

              // Trip Type (One-Way vs Return Trip)
              Row(
                children: [
                  Expanded(
                    child: SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(
                          value: false,
                          label: Text('One-Way'),
                          icon: Icon(Icons.arrow_forward),
                        ),
                        ButtonSegment(
                          value: true,
                          label: Text('Return Trip (2x)'),
                          icon: Icon(Icons.sync),
                        ),
                      ],
                      selected: {_isRoundTrip},
                      onSelectionChanged: (set) {
                        setState(() {
                          _isRoundTrip = set.first;
                          _updateManualDistanceDisplay();
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Mileage & Today's Petrol Rate Setup
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _mileageController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Bike Avg (km/L)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.speed),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Enter average';
                        final numVal = double.tryParse(val.trim());
                        if (numVal == null || numVal <= 0) return 'Valid > 0';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _fuelPriceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: "Today's Petrol Rate (₹/L)",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.local_gas_station),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Enter rate';
                        final numVal = double.tryParse(val.trim());
                        if (numVal == null || numVal <= 0) return 'Valid > 0';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Tracking Mode Selector
              const Text(
                'Tracking Mode',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'GPS', label: Text('Live GPS Track'), icon: Icon(Icons.gps_fixed)),
                  ButtonSegment(value: 'Manual', label: Text('Multi-Stop Map / Entry'), icon: Icon(Icons.map)),
                ],
                selected: {_trackingMode},
                onSelectionChanged: (set) => setState(() => _trackingMode = set.first),
              ),
              const SizedBox(height: 16),

              // Interactive Multi-Stop OpenStreetMap Widget
              RealRouteMapWidget(
                routePoints: _gpsRoutePoints,
                currentDistanceKm: effectiveDistanceKm,
                isLiveTracking: _isTracking,
                isManualMapMode: _trackingMode == 'Manual',
                manualWaypoints: _manualWaypoints,
                manualRoadPolyline: _manualRoadPolyline,
                userCurrentLocation: _currentLocation,
                onRequestLocation: () => _requestCurrentLocation(quiet: false),
                onPlaceSearched: (placeName, location) {
                  if (_nameController.text == 'Ride' || _nameController.text.trim().isEmpty) {
                    final shortName = placeName.split(',').first;
                    _nameController.text = shortName;
                  }
                },
                onManualWaypointsSelected: (waypoints, roadDistKm, polyline) {
                  setState(() {
                    _manualWaypoints = waypoints;
                    _manualRoadPolyline = polyline;
                    _rawOneWayDistanceKm = roadDistKm;
                    _updateManualDistanceDisplay();
                  });
                },
              ),
              const SizedBox(height: 8),

              // GPS Diagnostic Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _currentLocation != null
                      ? Colors.green.shade50
                      : (_locationServiceEnabled ? Colors.amber.shade50 : Colors.red.shade50),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _currentLocation != null
                        ? Colors.green.shade300
                        : (_locationServiceEnabled ? Colors.amber.shade300 : Colors.red.shade300),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          _currentLocation != null
                              ? Icons.check_circle
                              : (_locationServiceEnabled ? Icons.location_searching : Icons.location_off),
                          color: _currentLocation != null
                              ? Colors.green.shade800
                              : (_locationServiceEnabled ? Colors.amber.shade900 : Colors.red.shade800),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _locationStatusMessage,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _currentLocation != null
                                  ? Colors.green.shade900
                                  : (_locationServiceEnabled ? Colors.amber.shade900 : Colors.red.shade900),
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => _requestCurrentLocation(quiet: false),
                          style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                          child: const Text('REFRESH GPS'),
                        ),
                      ],
                    ),
                    if (!_locationServiceEnabled ||
                        (_locationPermission != LocationPermission.always &&
                            _locationPermission != LocationPermission.whileInUse)) ...[
                      const Divider(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          if (!_locationServiceEnabled)
                            OutlinedButton.icon(
                              onPressed: () => Geolocator.openLocationSettings(),
                              icon: const Icon(Icons.settings, size: 14),
                              label: const Text('Turn On GPS', style: TextStyle(fontSize: 11)),
                              style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                            ),
                          OutlinedButton.icon(
                            onPressed: () => Geolocator.openAppSettings(),
                            icon: const Icon(Icons.security, size: 14),
                            label: const Text('App Permissions', style: TextStyle(fontSize: 11)),
                            style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Quick Location Helper for Manual Map Mode
              if (_trackingMode == 'Manual') ...[
                OutlinedButton.icon(
                  onPressed: () async {
                    if (_currentLocation == null) {
                      await _requestCurrentLocation(quiet: false);
                    }
                    if (_currentLocation != null) {
                      setState(() {
                        if (_manualWaypoints.isEmpty) {
                          _manualWaypoints.add(_currentLocation!);
                        } else {
                          _manualWaypoints[0] = _currentLocation!;
                        }
                      });

                      if (_manualWaypoints.length >= 2) {
                        final routingService = RoadRoutingService();
                        final result = await routingService.getMultiStopRoadRoute(_manualWaypoints);
                        if (mounted) {
                          setState(() {
                            _manualRoadPolyline = result.polylinePoints;
                            _rawOneWayDistanceKm = result.distanceKm;
                            _updateManualDistanceDisplay();
                          });
                        }
                      }
                    }
                  },
                  icon: const Icon(Icons.my_location, size: 18),
                  label: const Text('Use Current Location as Start Point'),
                ),
                const SizedBox(height: 12),
              ],

              // Mode-specific Controls
              if (_trackingMode == 'GPS') ...[
                Card(
                  color: _isTracking ? Colors.green.shade50 : Colors.blue.shade50,
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Text(
                          '${effectiveDistanceKm.toStringAsFixed(2)} km',
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                            color: _isTracking ? Colors.green.shade800 : Colors.blue.shade900,
                          ),
                        ),
                        if (_isRoundTrip) ...[
                          const SizedBox(height: 4),
                          Chip(
                            avatar: const Icon(Icons.sync, size: 14, color: Colors.white),
                            label: Text('Return Trip Included (${_gpsDistanceKm.toStringAsFixed(2)} km x 2)'),
                            backgroundColor: Colors.blue.shade800,
                            labelStyle: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Text(
                          _isTracking
                              ? 'Tracking real-time GPS movement...'
                              : (_currentLocation != null
                                  ? 'GPS Ready (${_currentLocation!.latitude.toStringAsFixed(4)}, ${_currentLocation!.longitude.toStringAsFixed(4)})'
                                  : 'GPS Searching - Standby'),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 14),
                        ElevatedButton.icon(
                          onPressed: _isTracking ? _stopGpsTracking : _startGpsTracking,
                          icon: Icon(_isTracking ? Icons.stop : Icons.play_arrow),
                          label: Text(_isTracking ? 'Stop Ride' : 'Start Live GPS Ride'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isTracking ? Colors.red : Colors.green.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                TextFormField(
                  controller: _manualDistanceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Total Distance (km)',
                    hintText: 'Tap multiple stops on map or enter manually',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.straighten),
                    suffixText: _isRoundTrip ? 'km (Round Trip)' : 'km',
                  ),
                  onChanged: (val) {
                    setState(() {});
                  },
                  validator: (val) {
                    if (_trackingMode == 'Manual') {
                      if (val == null || val.trim().isEmpty) return 'Enter or select distance on map';
                      final numVal = double.tryParse(val.trim());
                      if (numVal == null || numVal <= 0) return 'Enter valid distance';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 24),

              // Participants & Split Section
              const Text(
                'Split with Friends',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                title: const Text('Include Me'),
                value: _selectedParticipantIds.contains('ME'),
                onChanged: (val) {
                  setState(() {
                    if (val == true) {
                      _selectedParticipantIds.add('ME');
                    } else {
                      if (_selectedParticipantIds.length > 1) {
                        _selectedParticipantIds.remove('ME');
                      }
                    }
                  });
                },
              ),
              ...friends.map((f) {
                return CheckboxListTile(
                  title: Text(f.name),
                  value: _selectedParticipantIds.contains(f.id),
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _selectedParticipantIds.add(f.id);
                      } else {
                        if (_selectedParticipantIds.length > 1) {
                          _selectedParticipantIds.remove(f.id);
                        }
                      }
                    });
                  },
                );
              }),
              const SizedBox(height: 16),

              // Paid By Selector
              const Text(
                'Paid By',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _paidBy,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.payment),
                ),
                items: [
                  const DropdownMenuItem(value: 'ME', child: Text('Me (User)')),
                  ...friends
                      .where((f) => _selectedParticipantIds.contains(f.id))
                      .map((f) => DropdownMenuItem(value: f.id, child: Text(f.name))),
                ],
                onChanged: (val) => setState(() => _paidBy = val ?? 'ME'),
              ),
              const SizedBox(height: 24),

              // Save Button
              GradientButton(
                text: 'Save & Calculate Ride',
                icon: Icons.check_circle,
                gradientColors: const [Color(0xFF6366F1), Color(0xFF3B82F6), Color(0xFF06B6D4)],
                onPressed: () => _saveRide(vehicles, friends),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
