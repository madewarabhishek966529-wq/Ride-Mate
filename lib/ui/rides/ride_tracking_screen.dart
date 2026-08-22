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
    });

    try {
      _locationServiceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!_locationServiceEnabled) {
        setState(() {
          _isFetchingLocation = false;
        });
        if (!quiet && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('GPS is turned off. Tap "Settings" to turn on.'),
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
        });
        if (!quiet && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Location permission is permanently denied.'),
              action: SnackBarAction(
                label: 'SETTINGS',
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
        });
      }
    } on MissingPluginException {
      if (mounted) {
        setState(() {
          _isFetchingLocation = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isFetchingLocation = false;
        });
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

  void _showBikeSettingsSheet(List<Vehicle> vehicles) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Bike & Fuel Rates', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.add_circle, color: Colors.blue),
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                          _showAddBikeDialog();
                        },
                      ),
                    ],
                  ),
                  const Divider(),
                  DropdownButtonFormField<String>(
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
                        setSheetState(() {});
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _mileageController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Avg Mileage (km/L)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.speed),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _fuelPriceController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: "Petrol Rate (₹/L)",
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.local_gas_station),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), foregroundColor: Colors.white),
                    child: const Text('Done'),
                  ),
                ],
              ),
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
        distanceFilter: 2,
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
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please fill out required fields.'),
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

    double rawKm = 0.0;
    if (_trackingMode == 'GPS' && _gpsDistanceKm > 0) {
      rawKm = _gpsDistanceKm;
    } else {
      rawKm = double.tryParse(_manualDistanceController.text.trim()) ?? 0.0;
      if (rawKm <= 0 && _gpsDistanceKm > 0) {
        rawKm = _gpsDistanceKm;
      }
    }

    final totalDistanceKm = _isRoundTrip ? (rawKm * 2) : rawKm;

    if (totalDistanceKm <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Distance is 0.0 km. Please tap points on map, enter distance, or start Live GPS.'),
          backgroundColor: Colors.orange.shade900,
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

    if (_selectedVehicleId == null && vehicles.isNotEmpty) {
      final defaultBike = vehicles.firstWhere((v) => v.isDefault, orElse: () => vehicles.first);
      _selectedVehicleId = defaultBike.id;
      _mileageController.text = defaultBike.mileage.toString();
      _fuelPriceController.text = defaultBike.defaultFuelPrice.toString();
    }

    final selectedBike = vehicles.firstWhere(
      (v) => v.id == _selectedVehicleId,
      orElse: () => Vehicle(
        id: 'default',
        name: 'Default Bike',
        mileage: double.tryParse(_mileageController.text) ?? 45.0,
        defaultFuelPrice: double.tryParse(_fuelPriceController.text) ?? 100.0,
      ),
    );

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
            tooltip: 'Recenter GPS',
            onPressed: () => _requestCurrentLocation(quiet: false),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Ride Name Input Field
              TextFormField(
                controller: _nameController,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  labelText: 'Ride Name / Destination',
                  hintText: 'e.g. Office Commute, Lonavala Trip',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on, color: Color(0xFF6366F1)),
                  isDense: true,
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Enter ride name' : null,
              ),
              const SizedBox(height: 10),

              // Compact Feature Control Chips (Bike Info + Return Trip + Mode Toggle)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // Bike Info Chip
                    ActionChip(
                      avatar: const Icon(Icons.two_wheeler, size: 16, color: Color(0xFF6366F1)),
                      label: Text(
                        '${selectedBike.name} (${_mileageController.text}km/L • ₹${_fuelPriceController.text}/L)',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () => _showBikeSettingsSheet(vehicles),
                      backgroundColor: Colors.blue.withValues(alpha: 0.1),
                    ),
                    const SizedBox(width: 6),

                    // Return Trip Chip
                    FilterChip(
                      selected: _isRoundTrip,
                      avatar: Icon(Icons.sync, size: 14, color: _isRoundTrip ? Colors.white : Colors.purple),
                      label: Text(
                        _isRoundTrip ? 'Return (2x)' : 'One-Way',
                        style: TextStyle(
                          fontSize: 12,
                          color: _isRoundTrip ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      selectedColor: Colors.purple.shade700,
                      onSelected: (val) {
                        setState(() {
                          _isRoundTrip = val;
                          _updateManualDistanceDisplay();
                        });
                      },
                    ),
                    const SizedBox(width: 6),

                    // Tracking Mode Chip
                    FilterChip(
                      selected: _trackingMode == 'GPS',
                      avatar: Icon(
                        _trackingMode == 'GPS' ? Icons.gps_fixed : Icons.map,
                        size: 14,
                        color: _trackingMode == 'GPS' ? Colors.white : Colors.blue,
                      ),
                      label: Text(
                        _trackingMode == 'GPS' ? 'Live GPS' : 'Manual Map',
                        style: TextStyle(
                          fontSize: 12,
                          color: _trackingMode == 'GPS' ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      selectedColor: const Color(0xFF10B981),
                      onSelected: (val) {
                        setState(() {
                          _trackingMode = val ? 'GPS' : 'Manual';
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Interactive Multi-Stop Map Widget
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

              // Mode Action Banner
              if (_trackingMode == 'GPS') ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: _isTracking ? Colors.green.shade50 : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _isTracking ? Colors.green.shade300 : Colors.blue.shade300,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${effectiveDistanceKm.toStringAsFixed(2)} km',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: _isTracking ? Colors.green.shade900 : Colors.blue.shade900,
                              ),
                            ),
                            Text(
                              _isTracking
                                  ? 'Tracking Live GPS...'
                                  : (_currentLocation != null ? 'GPS Fix Acquired' : 'GPS Standby'),
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _isTracking ? _stopGpsTracking : _startGpsTracking,
                        icon: Icon(_isTracking ? Icons.stop : Icons.play_arrow, size: 16),
                        label: Text(_isTracking ? 'Stop' : 'Start GPS'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isTracking ? Colors.red : Colors.green.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                TextFormField(
                  controller: _manualDistanceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Total Distance (km)',
                    hintText: 'Tap stops on map or enter km',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.straighten),
                    suffixText: _isRoundTrip ? 'km (2x Return)' : 'km',
                    isDense: true,
                  ),
                  onChanged: (val) => setState(() {}),
                ),
              ],
              const SizedBox(height: 12),

              // Split Section (Compact Horizontal Chips)
              Card(
                margin: EdgeInsets.zero,
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Split Expenses With',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          Text(
                            'Paid by: ${_paidBy == 'ME' ? 'Me' : friends.firstWhere((f) => f.id == _paidBy, orElse: () => friends.first).name}',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF6366F1), fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          FilterChip(
                            label: const Text('Me', style: TextStyle(fontSize: 12)),
                            selected: _selectedParticipantIds.contains('ME'),
                            onSelected: (val) {
                              setState(() {
                                if (val) {
                                  _selectedParticipantIds.add('ME');
                                } else if (_selectedParticipantIds.length > 1) {
                                  _selectedParticipantIds.remove('ME');
                                }
                              });
                            },
                          ),
                          ...friends.map((f) {
                            final isSel = _selectedParticipantIds.contains(f.id);
                            return FilterChip(
                              label: Text(f.name, style: const TextStyle(fontSize: 12)),
                              selected: isSel,
                              onSelected: (val) {
                                setState(() {
                                  if (val) {
                                    _selectedParticipantIds.add(f.id);
                                  } else if (_selectedParticipantIds.length > 1) {
                                    _selectedParticipantIds.remove(f.id);
                                  }
                                });
                              },
                            );
                          }),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Save & Calculate Button
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
