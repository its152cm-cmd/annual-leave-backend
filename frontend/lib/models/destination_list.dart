/// A trip can visit several cities. They are saved in the trip's destination
/// text, in visiting order, like "Tokyo → Kyoto → Osaka, Japan".
const String destinationSeparator = ' → ';

/// Full "City, Country" for every stop, in order. A stop without a country
/// ("Tokyo" in "Tokyo → Kyoto → Osaka, Japan") takes the country of the next
/// stop that has one.
List<String> splitDestination(String destination) {
  final parts = [
    for (final p in destination.split('→'))
      if (p.trim().isNotEmpty) p.trim(),
  ];
  final out = List<String>.from(parts);
  String country = '';
  for (var i = out.length - 1; i >= 0; i--) {
    final comma = out[i].indexOf(',');
    if (comma >= 0) {
      country = out[i].substring(comma + 1).trim();
    } else if (country.isNotEmpty) {
      out[i] = '${out[i]}, $country';
    }
  }
  return out;
}

/// Saves the stops as text. Neighbouring stops in the same country share it:
/// ["Tokyo, Japan", "Kyoto, Japan"] -> "Tokyo → Kyoto, Japan".
String joinDestination(List<String> stops) {
  final cities = <String>[];
  final countries = <String>[];
  for (final s in stops) {
    final comma = s.indexOf(',');
    cities.add(comma >= 0 ? s.substring(0, comma).trim() : s.trim());
    countries.add(comma >= 0 ? s.substring(comma + 1).trim() : '');
  }
  final buf = <String>[];
  for (var i = 0; i < cities.length; i++) {
    final sameAsNext = i + 1 < cities.length && countries[i] == countries[i + 1];
    buf.add(sameAsNext || countries[i].isEmpty ? cities[i] : '${cities[i]}, ${countries[i]}');
  }
  return buf.join(destinationSeparator);
}

/// Just the city names of a multi-city trip (["Tokyo", "Kyoto", "Osaka"]),
/// or an empty list when the trip has one city.
List<String> tripCities(String destination) {
  final stops = splitDestination(destination);
  if (stops.length < 2) return const [];
  return [
    for (final s in stops) s.split(',').first.trim(),
  ];
}
