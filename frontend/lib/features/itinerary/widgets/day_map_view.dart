import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/itinerary.dart';
import '../../../services/route_service.dart';

/// One day on a map: numbered pins in timeline order and the walking / taxi route between them.
/// Map pictures. For launch, build with your Geoapify key so the free OpenStreetMap server is not overloaded:
///   flutter build web --dart-define=MAP_KEY=your_geoapify_key
/// Without the key (local development) the free OpenStreetMap tiles are used.
const String _mapKey = String.fromEnvironment('MAP_KEY');
final String _tileUrl = _mapKey.isEmpty
    ? 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'
    : 'https://maps.geoapify.com/v1/tile/osm-bright/{z}/{x}/{y}.png?apiKey=$_mapKey';

class DayMapView extends StatefulWidget {
  const DayMapView({
    super.key,
    required this.city,
    required this.items,
    required this.onOpen,
  });

  final String city;
  final List<ItineraryDetailItem> items;
  final void Function(ItineraryDetailItem item) onOpen;

  @override
  State<DayMapView> createState() => _DayMapViewState();
}

class _DayMapViewState extends State<DayMapView> {
  late Future<DayMapData> _future;

  @override
  void initState() {
    super.initState();
    _future = RouteService().dayMap(widget.city, widget.items);
  }

  static Color _color(String method) => switch (method) {
        'walk' => const Color(0xFF1B9A3A),
        'transit' => const Color(0xFF1D5FA8),
        _ => const Color(0xFFE08A00),
      };

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DayMapData>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
        }
        final data = snap.data;
        if (snap.hasError || data == null || data.points.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'The map could not find the places of this day yet. Add a few places, or try again in a moment.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textMuted),
              ),
            ),
          );
        }
        final latLngs = [for (final p in data.points) LatLng(p.lat, p.lon)];
        final single = latLngs.length == 1;
        return Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: latLngs.first,
                  initialZoom: 15,
                  initialCameraFit: single
                      ? null
                      : CameraFit.bounds(
                          bounds: LatLngBounds.fromPoints(latLngs),
                          padding: const EdgeInsets.all(56),
                        ),
                ),
                children: [
                  TileLayer(
                    urlTemplate: _tileUrl,
                    userAgentPackageName: 'com.deployers.annualleave',
                  ),
                  PolylineLayer(
                    polylines: [
                      for (final l in data.lines)
                        Polyline(
                          points: [for (final c in l.path) LatLng(c[0], c[1])],
                          strokeWidth: 5,
                          color: _color(l.method),
                        ),
                    ],
                  ),
                  MarkerLayer(
                    markers: [
                      for (final p in data.points)
                        Marker(
                          point: LatLng(p.lat, p.lon),
                          width: 34,
                          height: 34,
                          child: GestureDetector(
                            onTap: () {
                              for (final i in widget.items) {
                                if (i.id == p.id) widget.onOpen(i);
                              }
                            },
                            child: Tooltip(
                              message: p.title,
                              child: Container(
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                                ),
                                child: Text(
                                  '${p.number}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const RichAttributionWidget(
                    attributions: [TextSourceAttribution('© OpenStreetMap contributors')],
                  ),
                ],
              ),
            ),
            Positioned(
              left: 12,
              top: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  _Key(Color(0xFF1B9A3A), 'Walk'),
                  SizedBox(width: 10),
                  _Key(Color(0xFFE08A00), 'Taxi'),
                  SizedBox(width: 10),
                  _Key(Color(0xFF1D5FA8), 'Train'),
                ]),
              ),
            ),
            if (data.googleUrl.isNotEmpty)
              Positioned(
                left: 12,
                right: 12,
                bottom: 28,
                child: Center(
                  child: ElevatedButton.icon(
                    onPressed: () => launchUrl(
                      Uri.parse(data.googleUrl),
                      mode: LaunchMode.externalApplication,
                    ),
                    icon: const Icon(Icons.directions, size: 18),
                    label: const Text('Open route in Google Maps'),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Key extends StatelessWidget {
  const _Key(this.color, this.label);

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 14, height: 4, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 11)),
    ]);
  }
}
