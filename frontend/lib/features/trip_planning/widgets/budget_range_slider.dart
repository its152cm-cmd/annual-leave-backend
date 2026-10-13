import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:homempage/core/theme/app_theme.dart';

class BudgetRangeSlider extends StatefulWidget {
  final RangeValues range;
  final ValueChanged<RangeValues> onChanged;
  final bool readOnly;
  final String title;

  const BudgetRangeSlider({
    super.key,
    required this.range,
    required this.onChanged,
    this.readOnly = false,
    this.title = 'Budget',
  });

  @override
  State<BudgetRangeSlider> createState() => _BudgetRangeSliderState();
}

class _BudgetRangeSliderState extends State<BudgetRangeSlider> {
  late final TextEditingController _minimumController;
  late final TextEditingController _maximumController;
  late final FocusNode _minimumFocus;
  late final FocusNode _maximumFocus;

  @override
  void initState() {
    super.initState();
    _minimumController = TextEditingController(
      text: widget.range.start.round().toString(),
    );
    _maximumController = TextEditingController(
      text: widget.range.end.round().toString(),
    );
    _minimumFocus = FocusNode()..addListener(_normalizeMinimum);
    _maximumFocus = FocusNode()..addListener(_normalizeMaximum);
  }

  @override
  void didUpdateWidget(covariant BudgetRangeSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_minimumFocus.hasFocus) {
      _setControllerValue(_minimumController, widget.range.start);
    }
    if (!_maximumFocus.hasFocus) {
      _setControllerValue(_maximumController, widget.range.end);
    }
  }

  @override
  void dispose() {
    _minimumFocus
      ..removeListener(_normalizeMinimum)
      ..dispose();
    _maximumFocus
      ..removeListener(_normalizeMaximum)
      ..dispose();
    _minimumController.dispose();
    _maximumController.dispose();
    super.dispose();
  }

  void _setControllerValue(TextEditingController controller, double value) {
    final text = value.round().toString();
    if (controller.text != text) {
      controller.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
  }

  /// When someone leaves a box, show the stored value; if the two boxes ended up the wrong way round
  /// (minimum above maximum) they swap places, so nothing the person typed is lost.
  void _normalizeMinimum() {
    if (_minimumFocus.hasFocus) return;
    _fixOrder();
    _setControllerValue(_minimumController, widget.range.start);
  }

  void _normalizeMaximum() {
    if (_maximumFocus.hasFocus) return;
    _fixOrder();
    _setControllerValue(_maximumController, widget.range.end);
  }

  void _fixOrder() {
    final r = widget.range;
    if (r.start > r.end) widget.onChanged(RangeValues(r.end, r.start));
  }

  /// Each box only changes its own value while typing. The two boxes do not follow each other.
  void _onAmountChanged(String text, {required bool isMinimum}) {
    final amount = int.tryParse(text);
    if (amount == null) return;

    final value = amount.clamp(0, 10000).toDouble();
    final r = widget.range;
    widget.onChanged(isMinimum ? RangeValues(value, r.end) : RangeValues(r.start, value));
  }

  Widget _amountField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String key,
    required ValueChanged<String> onChanged,
  }) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(16),
        ),
        child: TextField(
          key: ValueKey(key),
          controller: controller,
          focusNode: focusNode,
          readOnly: widget.readOnly,
          showCursor: !widget.readOnly,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(5),
          ],
          textInputAction: TextInputAction.done,
          onChanged: widget.readOnly ? null : onChanged,
          onSubmitted: widget.readOnly ? null : (_) => focusNode.unfocus(),
          decoration: const InputDecoration(
            prefixText: 'RM ',
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          ),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.textDark,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _amountField(
              controller: _minimumController,
              focusNode: _minimumFocus,
              key: 'budget-min-input',
              onChanged: (text) => _onAmountChanged(text, isMinimum: true),
            ),
            const SizedBox(width: 16),
            _amountField(
              controller: _maximumController,
              focusNode: _maximumFocus,
              key: 'budget-max-input',
              onChanged: (text) => _onAmountChanged(text, isMinimum: false),
            ),
          ],
        ),
      ],
    );
  }
}
