import '../core/api/api_client.dart';
import '../models/itinerary.dart';

/// How to get from the previous stop to this one (real map distance and time).
class TransferLeg {
  const TransferLeg({
    required this.fromId,
    required this.toId,
    required this.method,
    required this.minutes,
    required this.km,
    required this.label,
    required this.estimated,
  });

  final String fromId;
  final String toId;
  final String method; // walk, taxi or transit
  final int minutes;
  final double km;
  final String label;
  final bool estimated;

  factory TransferLeg.fromJson(Map<String, dynamic> json) => TransferLeg(
        fromId: '${json['fromId'] ?? ''}',
        toId: '${json['toId'] ?? ''}',
        method: '${json['method'] ?? 'taxi'}',
        minutes: (json['minutes'] as num?)?.round() ?? 0,
        km: (json['km'] as num?)?.toDouble() ?? 0,
        label: '${json['label'] ?? ''}',
        estimated: json['estimated'] as bool? ?? false,
      );
}

class RouteService {
  RouteService({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();

  final ApiClient _api;

  /// Legs between neighbouring stops, keyed by the id of the stop you arrive at.
  Future<Map<String, TransferLeg>> legs(
    String city,
    List<ItineraryDetailItem> items,
  ) async {
    if (items.length < 2) return {};
    final r = await _api.post('/api/routes/legs', {
      'city': city,
      'places': [
        for (final i in items.take(14))
          {'id': i.id, 'title': i.title, 'type': i.type},
      ],
    });
    final list = (r as Map)['legs'] as List? ?? const [];
    return {
      for (final l in list)
        if (l is Map)
          '${l['toId']}':
              TransferLeg.fromJson(Map<String, dynamic>.from(l)),
    };
  }

  /// The day's stops with coordinates, and the route line between them.
  Future<DayMapData> dayMap(String city, List<ItineraryDetailItem> items) async {
    final r = await _api.post('/api/routes/map', {
      'city': city,
      'places': [
        for (final i in items.take(14))
          {'id': i.id, 'title': i.title, 'type': i.type},
      ],
    });
    return DayMapData.fromJson(Map<String, dynamic>.from(r as Map));
  }
}

class MapPoint {
  const MapPoint({
    required this.id,
    required this.title,
    required this.number,
    required this.lat,
    required this.lon,
  });

  final String id;
  final String title;
  final int number;
  final double lat;
  final double lon;
}

class MapLine {
  const MapLine({required this.method, required this.label, required this.path});

  final String method;
  final String label;
  final List<List<double>> path; // [lat, lon]
}

class DayMapData {
  const DayMapData({required this.points, required this.lines, required this.googleUrl});

  final List<MapPoint> points;
  final List<MapLine> lines;
  final String googleUrl;

  factory DayMapData.fromJson(Map<String, dynamic> json) => DayMapData(
        points: [
          for (final p in (json['points'] as List? ?? const []))
            if (p is Map)
              MapPoint(
                id: '${p['id']}',
                title: '${p['title']}',
                number: (p['number'] as num?)?.toInt() ?? 0,
                lat: (p['lat'] as num).toDouble(),
                lon: (p['lon'] as num).toDouble(),
              ),
        ],
        lines: [
          for (final l in (json['lines'] as List? ?? const []))
            if (l is Map)
              MapLine(
                method: '${l['method']}',
                label: '${l['label']}',
                path: [
                  for (final c in (l['path'] as List? ?? const []))
                    if (c is List && c.length >= 2)
                      [(c[0] as num).toDouble(), (c[1] as num).toDouble()],
                ],
              ),
        ],
        googleUrl: '${json['googleUrl'] ?? ''}',
      );
}
