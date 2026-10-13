class FlightOption {
  final String id;
  final String airlineName;
  final String airlineLogoUrl;
  final String departureTime;
  final String arrivalTime;
  final String duration;
  final String flightType;
  final String terminal;
  final String priceFormatted;
  final String bookingUrl;
  final String route;
  final String stops;
  final String baggage;
  bool isFavourite;

  FlightOption({
    required this.id,
    required this.airlineName,
    required this.airlineLogoUrl,
    required this.departureTime,
    required this.arrivalTime,
    required this.duration,
    required this.flightType,
    required this.terminal,
    required this.priceFormatted,
    required this.bookingUrl,
    this.route = '',
    this.stops = '',
    this.baggage = '',
    this.isFavourite = false,
  });

  factory FlightOption.fromJson(Map<String, dynamic> json) {
    return FlightOption(
      id: json['id'] as String? ?? '',
      airlineName: json['airline_name'] as String? ?? '',
      airlineLogoUrl: json['airline_logo_url'] as String? ?? '',
      departureTime: json['departure_time'] as String? ?? '',
      arrivalTime: json['arrival_time'] as String? ?? '',
      duration: json['duration'] as String? ?? '',
      flightType: json['flight_type'] as String? ?? '',
      terminal: json['terminal'] as String? ?? '',
      priceFormatted: json['price_formatted'] as String? ?? '',
      bookingUrl: json['booking_url'] as String? ?? '',
      route: json['route'] as String? ?? '',
      stops: json['stops'] as String? ?? '',
      baggage: json['baggage'] as String? ?? '',
      isFavourite: json['is_favourite'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'airline_name': airlineName,
    'airline_logo_url': airlineLogoUrl,
    'departure_time': departureTime,
    'arrival_time': arrivalTime,
    'duration': duration,
    'flight_type': flightType,
    'terminal': terminal,
    'price_formatted': priceFormatted,
    'booking_url': bookingUrl,
    'route': route,
    'stops': stops,
    'baggage': baggage,
    'is_favourite': isFavourite,
  };
}

class FlightDateChip {
  final String dateString;
  final String priceFormatted;
  final bool isSelected;

  FlightDateChip({
    required this.dateString,
    required this.priceFormatted,
    this.isSelected = false,
  });

  factory FlightDateChip.fromJson(Map<String, dynamic> json) {
    return FlightDateChip(
      dateString: json['date_string'] as String? ?? '',
      priceFormatted: json['price_formatted'] as String? ?? '',
      isSelected: json['is_selected'] as bool? ?? false,
    );
  }
}
