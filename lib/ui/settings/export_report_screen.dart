import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/providers.dart';

enum DateRangeOption { thisMonth, lastMonth, custom }
enum ExportFormat { csv, pdf }

class ExportReportScreen extends ConsumerStatefulWidget {
  const ExportReportScreen({super.key});

  @override
  ConsumerState<ExportReportScreen> createState() => _ExportReportScreenState();
}

class _ExportReportScreenState extends ConsumerState<ExportReportScreen> {
  DateRangeOption _dateRangeOption = DateRangeOption.thisMonth;
  ExportFormat _exportFormat = ExportFormat.csv;
  String? _selectedVehicleId; // null = All vehicles
  DateTime _customStartDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _customEndDate = DateTime.now();

  (DateTime, DateTime) _computeDateRange() {
    final now = DateTime.now();
    if (_dateRangeOption == DateRangeOption.thisMonth) {
      final start = DateTime(now.year, now.month, 1);
      final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
      return (start, end);
    } else if (_dateRangeOption == DateRangeOption.lastMonth) {
      final start = DateTime(now.year, now.month - 1, 1);
      final end = DateTime(now.year, now.month, 0, 23, 59, 59);
      return (start, end);
    } else {
      return (_customStartDate, _customEndDate);
    }
  }

  Future<void> _exportData() async {
    final (start, end) = _computeDateRange();
    final allRides = ref.read(rideListProvider);
    final friends = ref.read(friendListProvider);
    final exportService = ref.read(exportServiceProvider);

    final friendNameMap = {for (var f in friends) f.id: f.name};

    // Filter rides by date range and vehicle scope
    final filteredRides = allRides.where((r) {
      final inRange = (r.date.isAfter(start) || r.date.isAtSameMomentAs(start)) &&
          (r.date.isBefore(end) || r.date.isAtSameMomentAs(end));
      final matchesVehicle = _selectedVehicleId == null || r.vehicleId == _selectedVehicleId;
      return inRange && matchesVehicle;
    }).toList();

    if (filteredRides.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No rides in this period'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    if (_exportFormat == ExportFormat.csv) {
      final csvString = exportService.generateCsvContent(filteredRides, friendNameMap);
      final bytes = csvString.codeUnits;
      await exportService.saveAndShareFile(
        bytes: bytes,
        fileName: 'RideMate_Export_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv',
      );
    } else {
      final pdfBytes = await exportService.generatePdfContent(
        rides: filteredRides,
        startDate: start,
        endDate: end,
        friendNames: friendNameMap,
      );
      if (pdfBytes.isNotEmpty) {
        await exportService.saveAndShareFile(
          bytes: pdfBytes,
          fileName: 'RideMate_Export_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vehicles = ref.watch(vehicleListProvider);
    final (start, end) = _computeDateRange();
    final allRides = ref.watch(rideListProvider);

    final filteredCount = allRides.where((r) {
      final inRange = (r.date.isAfter(start) || r.date.isAtSameMomentAs(start)) &&
          (r.date.isBefore(end) || r.date.isAtSameMomentAs(end));
      final matchesVehicle = _selectedVehicleId == null || r.vehicleId == _selectedVehicleId;
      return inRange && matchesVehicle;
    }).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Export Expense Report'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Date Range Option
            const Text(
              'Date Range',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            SegmentedButton<DateRangeOption>(
              segments: const [
                ButtonSegment(
                  value: DateRangeOption.thisMonth,
                  label: Text('This Month'),
                ),
                ButtonSegment(
                  value: DateRangeOption.lastMonth,
                  label: Text('Last Month'),
                ),
                ButtonSegment(
                  value: DateRangeOption.custom,
                  label: Text('Custom'),
                ),
              ],
              selected: {_dateRangeOption},
              onSelectionChanged: (set) {
                setState(() {
                  _dateRangeOption = set.first;
                });
              },
            ),
            if (_dateRangeOption == DateRangeOption.custom) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.date_range),
                      label: Text('Start: ${DateFormat('yyyy-MM-dd').format(_customStartDate)}'),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _customStartDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setState(() {
                            _customStartDate = picked;
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.date_range),
                      label: Text('End: ${DateFormat('yyyy-MM-dd').format(_customEndDate)}'),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _customEndDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setState(() {
                            _customEndDate = picked;
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),

            // Format Option
            const Text(
              'Export Format',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            SegmentedButton<ExportFormat>(
              segments: const [
                ButtonSegment(
                  value: ExportFormat.csv,
                  label: Text('CSV Spreadsheet'),
                  icon: Icon(Icons.table_chart),
                ),
                ButtonSegment(
                  value: ExportFormat.pdf,
                  label: Text('PDF Report'),
                  icon: Icon(Icons.picture_as_pdf),
                ),
              ],
              selected: {_exportFormat},
              onSelectionChanged: (set) {
                setState(() {
                  _exportFormat = set.first;
                });
              },
            ),
            const SizedBox(height: 24),

            // Scope / Vehicle Filter
            const Text(
              'Vehicle Scope',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String?>(
              initialValue: _selectedVehicleId,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.directions_car),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('All Vehicles'),
                ),
                ...vehicles.map((v) {
                  return DropdownMenuItem<String?>(
                    value: v.id,
                    child: Text(v.name),
                  );
                }),
              ],
              onChanged: (val) {
                setState(() {
                  _selectedVehicleId = val;
                });
              },
            ),
            const SizedBox(height: 24),

            // Ride count preview banner
            Card(
              color: filteredCount == 0 ? Colors.orange.shade50 : Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Row(
                  children: [
                    Icon(
                      filteredCount == 0 ? Icons.warning_amber : Icons.info_outline,
                      color: filteredCount == 0 ? Colors.orange.shade800 : Colors.blue.shade800,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        filteredCount == 0
                            ? 'No rides in this period'
                            : '$filteredCount ride${filteredCount == 1 ? '' : 's'} matching selected criteria',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: filteredCount == 0 ? Colors.orange.shade900 : Colors.blue.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Export & Share Button
            ElevatedButton.icon(
              onPressed: filteredCount == 0 ? null : _exportData,
              icon: const Icon(Icons.share),
              label: Text(
                'Generate & Share ${_exportFormat == ExportFormat.csv ? "CSV" : "PDF"}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
