import 'package:flutter/material.dart';
import 'package:homempage/core/theme/app_theme.dart';
import '../../home/widgets/city_picker_sheet.dart';

/// A tappable location field: opens the country -> city picker and returns
/// "City, Country". No typing, so the value always matches a real place.
class LocationDropdownField extends StatelessWidget {
  final String hint;
  final String? value;
  final ValueChanged<String?> onChanged;

  const LocationDropdownField({
    super.key,
    required this.hint,
    required this.value,
    required this.onChanged,
    List<String> locations = const [], // kept so old callers still compile
  });

  @override
  Widget build(BuildContext context) {
    final has = value != null && value!.trim().isNotEmpty;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () async {
        final picked = await showCityPicker(context, current: has ? value! : '');
        if (picked != null && picked.isNotEmpty) onChanged(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        decoration: BoxDecoration(
          color: AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(Icons.location_on_outlined, color: AppTheme.textMuted),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                has ? value! : hint,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  color: has ? AppTheme.textDark : AppTheme.textMuted,
                ),
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }
}
