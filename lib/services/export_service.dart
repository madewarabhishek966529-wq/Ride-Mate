import 'dart:io';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../domain/models/ride.dart';

class ExportService {
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm');

  /// Generates CSV string content for a list of rides.
  String generateCsvContent(List<Ride> rides, Map<String, String> friendNames) {
    final List<List<dynamic>> rows = [
      [
        'Date',
        'Ride Name',
        'Vehicle',
        'Mileage (km/L)',
        'Fuel Price (₹/L)',
        'Distance (km)',
        'Fuel Used (L)',
        'Fuel Cost (₹)',
        'Participants',
        'Per-Person Share (₹)',
        'Tracking Mode'
      ]
    ];

    for (final ride in rides) {
      final participantListStr = ride.participantIds.map((id) {
        if (id == 'ME') return 'Me';
        return friendNames[id] ?? id;
      }).join(', ');

      final perPersonShareStr = ride.participantShares.entries.map((e) {
        final name = e.key == 'ME' ? 'Me' : (friendNames[e.key] ?? e.key);
        return '$name: ₹${e.value.toStringAsFixed(2)}';
      }).join('; ');

      rows.add([
        _dateFormat.format(ride.date),
        ride.name,
        ride.vehicleName,
        ride.mileage,
        ride.fuelPrice,
        ride.distanceKm,
        ride.fuelUsedLiters,
        ride.totalFuelCost,
        participantListStr,
        perPersonShareStr,
        ride.trackingMode,
      ]);
    }

    return const ListToCsvConverter().convert(rows);
  }

  /// Generates PDF document bytes for a list of rides and date range.
  /// If [rides] is empty, returns an empty Uint8List or short-circuits gracefully without crash.
  Future<List<int>> generatePdfContent({
    required List<Ride> rides,
    required DateTime startDate,
    required DateTime endDate,
    required Map<String, String> friendNames,
  }) async {
    if (rides.isEmpty) {
      return <int>[];
    }

    final pdf = pw.Document();

    final totalDistance = rides.fold<double>(0, (sum, r) => sum + r.distanceKm);
    final totalFuelCost = rides.fold<double>(0, (sum, r) => sum + r.totalFuelCost);
    final totalRides = rides.length;
    final costPerKm = totalDistance > 0 ? totalFuelCost / totalDistance : 0.0;

    final dateRangeStr =
        '${DateFormat('MMM d, yyyy').format(startDate)} - ${DateFormat('MMM d, yyyy').format(endDate)}';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'RideMate Expense Report',
                  style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue900,
                  ),
                ),
                pw.Text(
                  dateRangeStr,
                  style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
                ),
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Divider(),
            pw.SizedBox(height: 16),

            // Summary Block
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _pdfStatItem('Total Distance', '${totalDistance.toStringAsFixed(1)} km'),
                  _pdfStatItem('Total Cost', '₹${totalFuelCost.toStringAsFixed(2)}'),
                  _pdfStatItem('Total Rides', '$totalRides'),
                  _pdfStatItem('Cost / km', '₹${costPerKm.toStringAsFixed(2)}'),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Rides Table
            pw.TableHelper.fromTextArray(
              headers: [
                'Date',
                'Ride',
                'Vehicle',
                'Dist (km)',
                'Cost (₹)',
                'Mode',
              ],
              data: rides.map((r) {
                return [
                  DateFormat('yyyy-MM-dd').format(r.date),
                  r.name,
                  r.vehicleName,
                  r.distanceKm.toStringAsFixed(1),
                  '₹${r.totalFuelCost.toStringAsFixed(2)}',
                  r.trackingMode,
                ];
              }).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
              rowDecoration: const pw.BoxDecoration(color: PdfColors.grey50),
              cellAlignment: pw.Alignment.centerLeft,
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _pdfStatItem(String label, String value) {
    return pw.Column(
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
        pw.SizedBox(height: 4),
        pw.Text(value, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
      ],
    );
  }

  /// Saves generated file locally and triggers system share sheet.
  Future<String> saveAndShareFile({
    required List<int> bytes,
    required String fileName,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsBytes(bytes);

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'RideMate Monthly Expense Report',
    );

    return file.path;
  }
}
