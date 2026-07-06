import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/format_service.dart';

class CalendarPicker extends StatefulWidget {
  final DateTime selectedDate;
  final bool viewAll;
  final ValueChanged<DateTime> onSelectDate;
  final VoidCallback onSelectAll;

  const CalendarPicker({
    super.key,
    required this.selectedDate,
    required this.viewAll,
    required this.onSelectDate,
    required this.onSelectAll,
  });

  @override
  State<CalendarPicker> createState() => _CalendarPickerState();
}

class _CalendarPickerState extends State<CalendarPicker> {
  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();
    _visibleMonth =
        DateTime(widget.selectedDate.year, widget.selectedDate.month, 1);
  }

  List<DateTime?> _daysInGrid() {
    final first = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final startOffset = first.weekday % 7; // 0 = Sunday
    final daysInMonth =
        DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0).day;
    final cells = <DateTime?>[];
    for (var i = 0; i < startOffset; i++) {
      cells.add(null);
    }
    for (var d = 1; d <= daysInMonth; d++) {
      cells.add(DateTime(_visibleMonth.year, _visibleMonth.month, d));
    }
    return cells;
  }

  static const _monthNamesAr = [
    'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
  ];

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final days = _daysInGrid();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                // DateTime normalizes month overflow/underflow automatically
                // (e.g. month 0 becomes December of the previous year),
                // so no manual bounds-checking is needed here.
                onPressed: () => setState(() {
                  _visibleMonth =
                      DateTime(_visibleMonth.year, _visibleMonth.month - 1, 1);
                }),
                icon: Icon(Icons.chevron_right, color: colors.primaryLight),
              ),
              Text(
                '${_monthNamesAr[_visibleMonth.month - 1]} ${_visibleMonth.year}',
                style: TextStyle(fontWeight: FontWeight.bold, color: colors.primary),
              ),
              IconButton(
                onPressed: () => setState(() {
                  _visibleMonth =
                      DateTime(_visibleMonth.year, _visibleMonth.month + 1, 1);
                }),
                icon: Icon(Icons.chevron_left, color: colors.primaryLight),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: weekdaysAr
                .map((w) => Expanded(
                      child: Center(
                        child: Text(
                          w.substring(0, 1),
                          style: TextStyle(fontSize: 12, color: colors.textSub),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 6),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: days.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
            ),
            itemBuilder: (context, i) {
              final d = days[i];
              if (d == null) return const SizedBox();
              final isSelected = !widget.viewAll &&
                  isSameDay(d, widget.selectedDate);
              return GestureDetector(
                onTap: () => widget.onSelectDate(d),
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: isSelected ? colors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${d.day}',
                    style: TextStyle(
                      fontSize: 13,
                      color: isSelected ? Colors.white : colors.textMain,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: widget.onSelectAll,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: widget.viewAll ? colors.primary : colors.bgSoft,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(
                'الجميع',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: widget.viewAll ? Colors.white : colors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
