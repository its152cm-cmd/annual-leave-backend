import 'package:flutter/material.dart';
import 'package:homempage/core/theme/app_theme.dart';
import '../../../models/destination_list.dart';
import '../../home/widgets/city_picker_sheet.dart';

/// Pick one or more destinations in visiting order (country -> city list).
/// [value] and [onChanged] use the saved text, e.g. "Tokyo → Kyoto → Osaka, Japan".
class MultiCityField extends StatelessWidget {
  const MultiCityField({
    super.key,
    required this.hint,
    required this.value,
    required this.onChanged,
    this.max = 6,
  });

  final String hint;
  final String? value;
  final ValueChanged<String?> onChanged;
  final int max;

  Future<void> _add(BuildContext context, List<String> stops) async {
    final picked = await showCityPicker(context);
    if (picked == null || picked.isEmpty) return;
    if (stops.any((s) => s.toLowerCase() == picked.toLowerCase())) return;
    onChanged(joinDestination([...stops, picked]));
  }

  @override
  Widget build(BuildContext context) {
    final stops = splitDestination(value ?? '');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < stops.length; i++)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.fromLTRB(12, 14, 4, 14),
            decoration: BoxDecoration(
              color: AppTheme.cardBackground,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 11,
                  backgroundColor: AppTheme.primaryGreen,
                  child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(stops[i], overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16)),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppTheme.textMuted),
                  onPressed: () {
                    final rest = [...stops]..removeAt(i);
                    onChanged(rest.isEmpty ? null : joinDestination(rest));
                  },
                ),
              ],
            ),
          ),
        if (stops.length < max)
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _add(context, stops),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
              decoration: BoxDecoration(
                color: AppTheme.cardBackground,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(stops.isEmpty ? Icons.location_on_outlined : Icons.add_circle_outline,
                      color: stops.isEmpty ? AppTheme.textMuted : AppTheme.primaryGreen),
                  const SizedBox(width: 12),
                  Text(
                    stops.isEmpty ? hint : 'Add another city',
                    style: TextStyle(
                      fontSize: 16,
                      color: stops.isEmpty ? AppTheme.textMuted : AppTheme.primaryGreen,
                      fontWeight: stops.isEmpty ? FontWeight.normal : FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (stops.length > 1)
          const Padding(
            padding: EdgeInsets.only(top: 6, left: 4),
            child: Text('Cities are visited in this order.',
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
          ),
      ],
    );
  }
}
