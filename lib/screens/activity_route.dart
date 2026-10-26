import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../services/activity_service.dart';

class ActivityRouteScreen extends StatelessWidget {
  const ActivityRouteScreen({
    required this.title,
    required this.route,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.steps,
    required this.startedAt,
    super.key,
  });

  final String title;
  final List<ActivityRoutePoint> route;
  final double? distanceMeters;
  final int durationSeconds;
  final int? steps;
  final DateTime? startedAt;

  List<List<LatLng>> get _segments {
    final segments = <List<LatLng>>[];
    for (final point in route) {
      if (segments.isEmpty || point.segmentStart) segments.add([]);
      segments.last.add(LatLng(point.latitude, point.longitude));
    }
    return segments.where((segment) => segment.isNotEmpty).toList();
  }

  String get _duration =>
      '${(durationSeconds ~/ 3600).toString().padLeft(2, '0')}:'
      '${((durationSeconds % 3600) ~/ 60).toString().padLeft(2, '0')}:'
      '${(durationSeconds % 60).toString().padLeft(2, '0')}';

  Future<void> _print(BuildContext context) async {
    try {
      final font = pw.Font.ttf(
        await rootBundle.load('assets/fonts/roboto-regular.ttf'),
      );
      final document = pw.Document();
      document.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          theme: pw.ThemeData.withFont(base: font),
          build: (context) => pw.Padding(
            padding: const pw.EdgeInsets.all(24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(title, style: pw.TextStyle(fontSize: 24)),
                pw.SizedBox(height: 10),
                pw.Text(
                  'Thời điểm: ${startedAt?.toLocal().toString() ?? 'Không có dữ liệu'}',
                ),
                pw.Text(
                  'Thời lượng: $_duration · Quãng đường GPS: '
                  '${distanceMeters == null ? 'Chưa đo được' : '${(distanceMeters! / 1000).toStringAsFixed(2)} km'}'
                  '${steps == null ? '' : ' · $steps bước'}',
                ),
                pw.SizedBox(height: 16),
                pw.Expanded(
                  child: pw.Container(
                    width: double.infinity,
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey400),
                    ),
                    child: pw.CustomPaint(
                      painter: (canvas, size) {
                        final minLat = route
                            .map((point) => point.latitude)
                            .reduce(math.min);
                        final maxLat = route
                            .map((point) => point.latitude)
                            .reduce(math.max);
                        final minLon = route
                            .map((point) => point.longitude)
                            .reduce(math.min);
                        final maxLon = route
                            .map((point) => point.longitude)
                            .reduce(math.max);
                        final latSpan = math.max(maxLat - minLat, 0.000001);
                        final lonSpan = math.max(maxLon - minLon, 0.000001);
                        const inset = 24.0;
                        final usableWidth = math.max(size.x - inset * 2, 1);
                        final usableHeight = math.max(size.y - inset * 2, 1);
                        canvas
                          ..setStrokeColor(PdfColors.blue700)
                          ..setLineWidth(3);
                        for (final point in route) {
                          final x = inset +
                              (point.longitude - minLon) / lonSpan * usableWidth;
                          final y = inset +
                              (point.latitude - minLat) / latSpan * usableHeight;
                          if (point.segmentStart) {
                            canvas.moveTo(x, y);
                          } else {
                            canvas.lineTo(x, y);
                          }
                        }
                        canvas.strokePath();
                      },
                    ),
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Sơ đồ tuyến từ các điểm GPS đã ghi (không theo tỷ lệ bản đồ). '
                  '© OpenStreetMap contributors cho bản đồ xem trong ứng dụng.',
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ],
            ),
          ),
        ),
      );
      await Printing.layoutPdf(
        onLayout: (_) => document.save(),
        name: 'lo-trinh-${startedAt?.toLocal().toIso8601String() ?? 'buoi-tap'}.pdf',
      );
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể in lộ trình: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final points = route
        .map((point) => LatLng(point.latitude, point.longitude))
        .toList();
    final bounds = points.length > 1 ? LatLngBounds.fromPoints(points) : null;
    final center = points.isEmpty
        ? const LatLng(0, 0)
        : points[points.length ~/ 2];
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'In hoặc lưu PDF',
            onPressed: route.isEmpty ? null : () => _print(context),
            icon: const Icon(Icons.print_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SizedBox(
            height: 380,
            child: route.isEmpty
                ? const Center(child: Text('Buổi tập không có điểm GPS để vẽ.'))
                : FlutterMap(
                    options: MapOptions(
                      initialCenter: center,
                      initialZoom: 15,
                      initialCameraFit: bounds == null
                          ? null
                          : CameraFit.bounds(
                              bounds: bounds,
                              padding: const EdgeInsets.all(42),
                            ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.aigym.app',
                      ),
                      PolylineLayer(
                        polylines: [
                          for (final segment in _segments)
                            if (segment.length > 1)
                              Polyline(
                                points: segment,
                                strokeWidth: 5,
                                color: Colors.deepPurple,
                              ),
                        ],
                      ),
                      if (points.isNotEmpty)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: points.first,
                              width: 36,
                              height: 36,
                              child: const Icon(
                                Icons.trip_origin,
                                color: Colors.green,
                              ),
                            ),
                            if (points.length > 1)
                              Marker(
                                point: points.last,
                                width: 36,
                                height: 36,
                                child: const Icon(
                                  Icons.location_on,
                                  color: Colors.red,
                                ),
                              ),
                          ],
                        ),
                      const RichAttributionWidget(
                        attributions: [
                          TextSourceAttribution('© OpenStreetMap contributors'),
                        ],
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 12),
          Text(
            'Thời điểm: ${startedAt?.toLocal().toString() ?? 'Không có dữ liệu'}',
          ),
          Text('Thời lượng: $_duration'),
          Text(
            'Quãng đường GPS: ${distanceMeters == null ? 'Chưa đo được' : '${(distanceMeters! / 1000).toStringAsFixed(2)} km'}',
          ),
          Text('Số bước: ${steps?.toString() ?? 'Cảm biến không khả dụng'}'),
          Text('Điểm GPS hợp lệ đã lưu: ${route.length}'),
          const Text(
            'Bản đồ tải từ OpenStreetMap khi có kết nối mạng; đường màu tím là dữ liệu GPS đã ghi, không phải tuyến chỉ đường.',
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: route.isEmpty ? null : () => _print(context),
            icon: const Icon(Icons.print_outlined),
            label: const Text('In / lưu lộ trình PDF'),
          ),
        ],
      ),
    );
  }
}
