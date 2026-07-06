import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../services/app_controller.dart';

class SettingsSheet extends StatefulWidget {
  final AppController controller;

  const SettingsSheet({super.key, required this.controller});

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  late TextEditingController _name;
  late TextEditingController _job;
  late TextEditingController _phone;
  late bool _includePersonal;
  late DateSystem _dateSystem;
  late NumeralSystem _numeralSystem;

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    final s = widget.controller.settings;
    _name = TextEditingController(text: s.name);
    _job = TextEditingController(text: s.job);
    _phone = TextEditingController(text: s.phone);
    _includePersonal = s.includePersonalInfo;
    _dateSystem = s.dateSystem;
    _numeralSystem = s.numeralSystem;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _name.dispose();
    _job.dispose();
    _phone.dispose();
    super.dispose();
  }

  /// Text fields persist on a short debounce instead of every keystroke,
  /// so typing a name doesn't hammer local storage with dozens of writes.
  void _persistDebounced() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _persistNow);
  }

  Future<void> _persistNow() async {
    await widget.controller.updateSettings(AppSettings(
      name: _name.text,
      job: _job.text,
      phone: _phone.text,
      includePersonalInfo: _includePersonal,
      dateSystem: _dateSystem,
      numeralSystem: _numeralSystem,
    ));
  }

  Widget _segButton(String label, bool active, VoidCallback onTap, AppPalette colors) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: active ? colors.primary : colors.bgCard,
            border: Border.all(
                color: active ? colors.primary : colors.border, width: 1.4),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: active ? Colors.white : colors.textMain,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text, AppPalette colors, {Color? color}) => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 6),
        child: Text(text,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color ?? colors.textSub)),
      );

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colors.bgCard,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('الإعدادات',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: colors.primary)),
                    IconButton(
                      onPressed: () async {
                        _debounce?.cancel();
                        await _persistNow();
                        if (context.mounted) Navigator.of(context).pop();
                      },
                      icon: Icon(Icons.close, color: colors.textSub),
                    ),
                  ],
                ),
                _label('الاسم', colors),
                TextField(
                  controller: _name,
                  textAlign: TextAlign.right,
                  style: TextStyle(color: colors.textMain),
                  maxLength: 80,
                  onChanged: (_) => _persistDebounced(),
                ),
                _label('العمل', colors),
                TextField(
                  controller: _job,
                  textAlign: TextAlign.right,
                  style: TextStyle(color: colors.textMain),
                  maxLength: 80,
                  onChanged: (_) => _persistDebounced(),
                ),
                _label('رقم الهاتف', colors),
                TextField(
                  controller: _phone,
                  textAlign: TextAlign.right,
                  style: TextStyle(color: colors.textMain),
                  keyboardType: TextInputType.phone,
                  maxLength: 20,
                  onChanged: (_) => _persistDebounced(),
                ),
                GestureDetector(
                  onTap: () {
                    setState(() => _includePersonal = !_includePersonal);
                    _persistNow();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: _includePersonal
                                ? colors.primary
                                : Colors.transparent,
                            border: Border.all(color: colors.primary, width: 1.5),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: _includePersonal
                              ? const Icon(Icons.check, size: 15, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text('إدراج المعلومات الشخصية في المستند',
                              style: TextStyle(fontSize: 14, color: colors.textMain)),
                        ),
                      ],
                    ),
                  ),
                ),
                _label('نوع التاريخ', colors),
                Row(
                  children: [
                    _segButton('ميلادي', _dateSystem == DateSystem.gregorian, () {
                      setState(() => _dateSystem = DateSystem.gregorian);
                      _persistNow();
                    }, colors),
                    _segButton('هجري', _dateSystem == DateSystem.hijri, () {
                      setState(() => _dateSystem = DateSystem.hijri);
                      _persistNow();
                    }, colors),
                  ],
                ),
                _label('نوع الأرقام', colors),
                Row(
                  children: [
                    _segButton('123', _numeralSystem == NumeralSystem.arabic, () {
                      setState(() => _numeralSystem = NumeralSystem.arabic);
                      _persistNow();
                    }, colors),
                    _segButton('١٢٣', _numeralSystem == NumeralSystem.hindi, () {
                      setState(() => _numeralSystem = NumeralSystem.hindi);
                      _persistNow();
                    }, colors),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
