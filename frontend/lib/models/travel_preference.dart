class TravelPreference {
  final String transcript;
  final String pace; // Relaxed, Balanced, Packed
  final String accessibility; // Standard, Prefer accessible, Wheelchair-friendly
  final String restroomPriority; // Low, Medium, High
  final String startTime; // e.g. "08:00 AM"
  final String endTime; // e.g. "09:00 PM"

  TravelPreference({
    required this.transcript,
    required this.pace,
    required this.accessibility,
    required this.restroomPriority,
    required this.startTime,
    required this.endTime,
  });

  factory TravelPreference.fromJson(Map<String, dynamic> json) {
    return TravelPreference(
      transcript: json['transcript'] ?? '',
      pace: json['pace'] ?? 'Balanced',
      accessibility: json['accessibility'] ?? 'Standard',
      restroomPriority: json['restroom_priority'] ?? 'Medium',
      startTime: json['start_time'] ?? '08:00 AM',
      endTime: json['end_time'] ?? '09:00 PM',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'transcript': transcript,
      'pace': pace,
      'accessibility': accessibility,
      'restroom_priority': restroomPriority,
      'start_time': startTime,
      'end_time': endTime,
    };
  }

  TravelPreference copyWith({
    String? transcript,
    String? pace,
    String? accessibility,
    String? restroomPriority,
    String? startTime,
    String? endTime,
  }) {
    return TravelPreference(
      transcript: transcript ?? this.transcript,
      pace: pace ?? this.pace,
      accessibility: accessibility ?? this.accessibility,
      restroomPriority: restroomPriority ?? this.restroomPriority,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }
}

class TravelPreferenceCategory {
  const TravelPreferenceCategory({
    required this.name,
    required this.options,
    this.singleSelect = false,
  });

  final String name;
  final List<TravelPreferenceOption> options;
  final bool singleSelect;

  factory TravelPreferenceCategory.fromJson(Map<String, dynamic> json) =>
      TravelPreferenceCategory(
        name: json['name'] as String? ?? '',
        singleSelect: json['single_select'] as bool? ?? false,
        options: (json['options'] as List<dynamic>? ?? const [])
            .map(
              (option) => TravelPreferenceOption.fromJson(
                Map<String, dynamic>.from(option as Map),
              ),
            )
            .toList(),
      );

  Map<String, dynamic> toJson() => {
    'name': name,
    'single_select': singleSelect,
    'options': options.map((option) => option.toJson()).toList(),
  };

  TravelPreferenceCategory copyWith({List<TravelPreferenceOption>? options}) =>
      TravelPreferenceCategory(
        name: name,
        singleSelect: singleSelect,
        options: options ?? this.options,
      );
}

class TravelPreferenceOption {
  const TravelPreferenceOption({required this.label, this.selected = false});

  final String label;
  final bool selected;

  factory TravelPreferenceOption.fromJson(Map<String, dynamic> json) =>
      TravelPreferenceOption(
        label: json['label'] as String? ?? '',
        selected: json['selected'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {'label': label, 'selected': selected};

  TravelPreferenceOption copyWith({bool? selected}) => TravelPreferenceOption(
    label: label,
    selected: selected ?? this.selected,
  );
}
