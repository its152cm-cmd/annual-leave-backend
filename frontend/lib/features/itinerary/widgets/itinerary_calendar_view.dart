import 'package:flutter/material.dart';

import '../../../../models/itinerary.dart';
import '../../../services/route_service.dart';
import 'itinerary_daycards.dart';

class ItineraryCalendarView extends StatefulWidget {
  const ItineraryCalendarView({
    super.key,
    required this.items,
    required this.onDrop,
    required this.onDelete,
    required this.onLongPressDelete,
    required this.onAdjustDuration,
    this.legs = const {},
    this.onOpen,
  });

  final List<ItineraryDetailItem> items;
  final void Function(ItineraryDetailItem item, double canvasY) onDrop;
  final Future<void> Function(ItineraryDetailItem item) onDelete;
  final Future<void> Function(ItineraryDetailItem item) onLongPressDelete;
  final Future<void> Function(ItineraryDetailItem item) onAdjustDuration;
  final Map<String, TransferLeg> legs;
  final void Function(ItineraryDetailItem item)? onOpen;

  @override
  State<ItineraryCalendarView> createState() => _ItineraryCalendarViewState();
}

class _ItineraryCalendarViewState extends State<ItineraryCalendarView> {
  static const int _firstHour = 6;
  static const int _lastHour = 24;
  static const double _hourHeight = 72;

  final GlobalKey _calendarCanvasKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final canvasHeight = (_lastHour - _firstHour) * _hourHeight;
    return DragTarget<ItineraryDetailItem>(
      key: const ValueKey('itinerary-timeline-drop-target'),
      hitTestBehavior: HitTestBehavior.translucent,
      onWillAcceptWithDetails: (details) => !details.data.isFixed,
      onAcceptWithDetails: (details) {
        final renderObject = _calendarCanvasKey.currentContext
            ?.findRenderObject();
        if (renderObject is! RenderBox) return;
        final localPosition = renderObject.globalToLocal(details.offset);
        widget.onDrop(details.data, localPosition.dy);
      },
      builder: (context, candidates, rejected) => SingleChildScrollView(
        key: const ValueKey('itinerary-calendar-scroll-view'),
        child: LayoutBuilder(
          builder: (context, constraints) => SizedBox(
            key: _calendarCanvasKey,
            height: canvasHeight,
            width: constraints.maxWidth,
            child: Stack(
              children: [
                for (var hour = _firstHour; hour < _lastHour; hour++)
                  Positioned(
                    top: (hour - _firstHour) * _hourHeight,
                    left: 0,
                    right: 0,
                    height: _hourHeight,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 66,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8, top: 2),
                            child: Text(
                              _formatHour(hour),
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                color: Color(0xFF78808A),
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            height: 1,
                            color: const Color(0xFFE5E8EB),
                          ),
                        ),
                      ],
                    ),
                  ),
                Positioned(
                  left: 66,
                  right: 8,
                  top: 0,
                  bottom: 0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                  ),
                ),
                for (var i = 0; i < widget.items.length; i++)
                  _buildCalendarEvent(
                    widget.items[i],
                    i > 0 ? widget.items[i - 1] : null,
                    constraints.maxWidth - 74,
                    canvasHeight,
                  ),
                if (candidates.isNotEmpty)
                  Positioned(
                    top: 8,
                    left: 76,
                    right: 16,
                    child: IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F7EE)
                              .withValues(alpha: 0.96),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF31C45B)),
                        ),
                        child: const Text(
                          'Drop to schedule this activity',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF16863A),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarEvent(
    ItineraryDetailItem item,
    ItineraryDetailItem? previous,
    double eventWidth,
    double canvasHeight,
  ) {
    final startMinute = _minuteOfDay(item.timeStart);
    final endMinute = _minuteOfDay(item.timeEnd);
    final top = ((startMinute - _firstHour * 60) / 60 * _hourHeight)
        .clamp(0.0, double.infinity)
        .toDouble();
    final height = item.isFixed
        ? 66.0
        : (((endMinute - startMinute) / 60) * _hourHeight)
              .clamp(66.0, canvasHeight - top)
              .toDouble();
    final leg = widget.legs[item.id];
    final gap = previous == null
        ? 9999
        : startMinute - _minuteOfDay(previous.timeEnd);
    final card = TimelineScheduleCard(
      item: item,
      leg: leg,
      onTap: widget.onOpen == null ? null : () => widget.onOpen!(item),
      legTight: leg != null && previous != null && leg.minutes > gap,
      onDelete: () => widget.onDelete(item),
      onLongPressDelete: () => widget.onLongPressDelete(item),
      onAdjustDuration: !item.isFixed && item.type == 'attraction'
          ? () => widget.onAdjustDuration(item)
          : null,
    );

    return Positioned(
      key: ValueKey('calendar-event-${item.id}'),
      top: top,
      left: 74,
      right: 8,
      height: height,
      child: item.isFixed
          ? card
          : Draggable<ItineraryDetailItem>(
              data: item,
              feedback: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: eventWidth,
                  height: height,
                  child: TimelineScheduleCard(item: item),
                ),
              ),
              childWhenDragging: Opacity(
                opacity: 0.3,
                child: TimelineScheduleCard(item: item),
              ),
              child: card,
            ),
    );
  }

  static String _formatHour(int hour) {
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    final meridiem = hour < 12 ? 'AM' : 'PM';
    return '$displayHour $meridiem';
  }

  static int _minuteOfDay(String time) {
    final match = RegExp(
      r'^\s*(\d{1,2}):(\d{2})\s*(AM|PM)\s*$',
      caseSensitive: false,
    ).firstMatch(time);
    if (match == null) return _firstHour * 60;
    var hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    final isPm = match.group(3)!.toUpperCase() == 'PM';
    if (hour == 12) hour = 0;
    if (isPm) hour += 12;
    return hour * 60 + minute;
  }
}
