import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/destination_list.dart';
import '../../trip_planning/widgets/multi_city_field.dart';

/// Pick the group's destination: a country, then one or more of its cities
/// (the same picker as when planning a solo trip). Returns the saved text,
/// like "Tokyo → Kyoto → Osaka, Japan", or null if closed.
Future<String?> showDestinationPicker(
  BuildContext context, {
  String current = '',
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => _DestinationPicker(current: current),
  );
}

class _DestinationPicker extends StatefulWidget {
  const _DestinationPicker({required this.current});

  final String current;

  @override
  State<_DestinationPicker> createState() => _DestinationPickerState();
}

class _DestinationPickerState extends State<_DestinationPicker> {
  String? _value;

  @override
  void initState() {
    super.initState();
    final text = widget.current.trim();
    // A bare country such as "South Korea" cannot be edited as a city list.
    _value = text.isEmpty || !text.contains(',') && !text.contains('→') ? null : text;
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    final hasValue = (_value ?? '').trim().isNotEmpty;
    return SizedBox(
      height: height * 0.72,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Edit Destination',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Text(
              'Choose a country, then pick one or more cities. Suggestions follow every city you choose.',
              style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                child: MultiCityField(
                  hint: 'Choose a country and city',
                  value: _value,
                  onChanged: (v) => setState(() => _value = v),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: hasValue ? () => Navigator.pop(context, _value) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  disabledBackgroundColor: Colors.grey.shade300,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  hasValue ? 'Save Destination' : 'Pick a city',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
