import 'collaborator.dart';

class Trip {
  final String id;
  final String destination;
  final String dateRange;
  final String duration;
  final String budget;
  final String imageUrl;
  final String status;
  final bool generatedFromGroupChat;
  final int travellerCount;
  final double minimumBudget;
  final double plannedBudget;
  final String originCity;
  final double? estimatedBudget;
  final Map<String, double>? budgetBreakdown;
  final List<String> bookedItemIds;
  final List<Collaborator> collaborators;

  Trip({
    required this.id,
    required this.destination,
    required this.dateRange,
    required this.duration,
    required this.budget,
    required this.imageUrl,
    required this.status,
    this.generatedFromGroupChat = false,
    this.travellerCount = 4,
    this.minimumBudget = 0,
    this.plannedBudget = 2000,
    this.originCity = 'Kuala Lumpur',
    this.estimatedBudget,
    this.budgetBreakdown,
    this.bookedItemIds = const [],
    this.collaborators = const [],
  });

  factory Trip.fromJson(Map<String, dynamic> json) {
    final budget = json['budget'] as String? ?? '';
    final amounts = _budgetAmountsFromLabel(budget);
    final plannedBudget =
        (json['planned_budget'] as num?)?.toDouble() ??
        (amounts.isEmpty ? 2000 : amounts.last);

    return Trip(
      id: json['id'] as String? ?? '',
      destination: json['destination'] as String? ?? '',
      dateRange: json['date_range'] as String? ?? '',
      duration: json['duration'] as String? ?? '',
      budget: budget,
      imageUrl: json['image_url'] as String? ?? '',
      status: json['status'] as String? ?? '',
      generatedFromGroupChat:
          json['generated_from_group_chat'] as bool? ?? false,
      travellerCount: json['traveller_count'] as int? ?? 4,
      minimumBudget:
          (json['minimum_budget'] as num?)?.toDouble() ??
          (amounts.isEmpty ? plannedBudget : amounts.first),
      plannedBudget: plannedBudget,
      originCity: json['origin_city'] as String? ?? 'Kuala Lumpur',
      estimatedBudget: (json['estimated_budget'] as num?)?.toDouble(),
      budgetBreakdown: _parseBudgetBreakdown(json['budget_breakdown']),
      bookedItemIds: (json['booked_item_ids'] as List<dynamic>? ?? const [])
          .map((id) => id.toString())
          .toList(),
      collaborators: (json['collaborators'] as List<dynamic>? ?? const [])
          .map((entry) => Collaborator.fromJson(Map<String, dynamic>.from(entry as Map)))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'destination': destination,
      'date_range': dateRange,
      'duration': duration,
      'budget': budget,
      'image_url': imageUrl,
      'status': status,
      'generated_from_group_chat': generatedFromGroupChat,
      'traveller_count': travellerCount,
      'minimum_budget': minimumBudget,
      'planned_budget': plannedBudget,
      'origin_city': originCity,
      'estimated_budget': estimatedBudget,
      'budget_breakdown': budgetBreakdown,
      'booked_item_ids': bookedItemIds,
      'collaborators': collaborators.map((collaborator) => collaborator.toJson()).toList(),
    };
  }

  Trip copyWith({
    String? id,
    String? destination,
    String? dateRange,
    String? duration,
    String? budget,
    String? imageUrl,
    String? status,
    bool? generatedFromGroupChat,
    int? travellerCount,
    double? minimumBudget,
    double? plannedBudget,
    String? originCity,
    double? estimatedBudget,
    Map<String, double>? budgetBreakdown,
    List<String>? bookedItemIds,
    List<Collaborator>? collaborators,
  }) {
    return Trip(
      id: id ?? this.id,
      destination: destination ?? this.destination,
      dateRange: dateRange ?? this.dateRange,
      duration: duration ?? this.duration,
      budget: budget ?? this.budget,
      imageUrl: imageUrl ?? this.imageUrl,
      status: status ?? this.status,
      generatedFromGroupChat:
          generatedFromGroupChat ?? this.generatedFromGroupChat,
      travellerCount: travellerCount ?? this.travellerCount,
      minimumBudget: minimumBudget ?? this.minimumBudget,
      plannedBudget: plannedBudget ?? this.plannedBudget,
      originCity: originCity ?? this.originCity,
      estimatedBudget: estimatedBudget ?? this.estimatedBudget,
      budgetBreakdown: budgetBreakdown ?? this.budgetBreakdown,
      bookedItemIds: bookedItemIds ?? this.bookedItemIds,
      collaborators: collaborators ?? this.collaborators,
    );
  }

  static List<double> _budgetAmountsFromLabel(String label) =>
      RegExp(r'\d[\d,]*(?:\.\d+)?')
          .allMatches(label)
          .map((match) => double.tryParse(match.group(0)!.replaceAll(',', '')))
          .whereType<double>()
          .toList();

  static Map<String, double>? _parseBudgetBreakdown(dynamic value) {
    if (value is! Map) return null;
    return {
      for (final entry in value.entries)
        if (entry.value is num)
          entry.key.toString(): (entry.value as num).toDouble(),
    };
  }
}
