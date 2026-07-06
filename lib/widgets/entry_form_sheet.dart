import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../services/app_controller.dart';

/// Shows the add/edit entry bottom sheet.
/// - في تبويب "بيان": التفاصيل إجبارية، ويكفي إدخال واحد من (القيمة/مستلم).
/// - في تبويب "مصروف": التفاصيل إجبارية فقط، القيمة اختيارية.
Future<void> showEntryFormSheet(
  BuildContext context, {
  required AppController controller,
  Entry? existing,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _EntryFormSheet(controller: controller, existing: existing),
  );
}

class _EntryFormSheet extends StatefulWidget {
  final AppController controller;
  final Entry? existing;

  const _EntryFormSheet({required this.controller, this.existing});

  @override
  State<_EntryFormSheet> createState() => _EntryFormSheetState();
}

class _EntryFormSheetState extends State<_EntryFormSheet> {
  late final TextEditingController _details;
  late final TextEditingController _value;
  late final TextEditingController _received;
  String? _error;
  bool _saving = false;

  bool get isStatementTab => widget.controller.currentTab == EntryTab.statement;

  @override
  void initState() {
    super.initState();
    _details = TextEditingController(text: widget.existing?.details ?? '');
    _value = TextEditingController(
        text: widget.existing != null && widget.existing!.value != 0
            ? _trimZero(widget.existing!.value)
            : '');
    _received = TextEditingController(
        text: widget.existing != null && widget.existing!.received != 0
            ? _trimZero(widget.existing!.received)
            : '');
  }

  String _trimZero(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  @override
  void dispose() {
    _details.dispose();
    _value.dispose();
    _received.dispose();
    super.dispose();
  }

  /// Parses a numeric field defensively: empty -> 0, garbage input -> null
  /// (triggers a clear validation message instead of silently treating
  /// unparsable text as zero).
  double? _parseNumeric(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return 0;
    final normalized = t.replaceAll(',', '.');
    final v = double.tryParse(normalized);
    if (v == null || !v.isFinite) return null;
    return v;
  }

  Future<void> _save() async {
    if (_saving) return;
    final details = _details.text.trim();
    final value = _parseNumeric(_value.text);
    final received = _parseNumeric(_received.text);

    if (details.isEmpty) {
      setState(() => _error = 'التفاصيل مطلوبة');
      return;
    }
    if (value == null || (isStatementTab && received == null)) {
      setState(() => _error = 'الرجاء إدخال رقم صحيح');
      return;
    }
    if (isStatementTab && value == 0 && received == 0) {
      setState(() => _error = 'أدخل القيمة أو المستلم على الأقل');
      return;
    }

    setState(() {
      _error = null;
      _saving = true;
    });

    try {
      if (widget.existing != null) {
        await widget.controller.updateEntry(
          widget.existing!.id,
          details: details,
          value: value,
          received: received ?? 0,
        );
      } else {
        await widget.controller.addEntry(
          details: details,
          value: value,
          received: received ?? 0,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmDelete() async {
    if (widget.existing == null) return;
    final colors = AppColors.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: colors.bgCard,
          title: Text('حذف المدخل', style: TextStyle(color: colors.textMain)),
          content: Text('هل أنت متأكد من حذف هذا المدخل؟ لا يمكن التراجع عن هذا الإجراء.',
              style: TextStyle(color: colors.textSub)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text('حذف', style: TextStyle(color: colors.red)),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      await widget.controller.deleteEntry(widget.existing!.id);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final maxHeight = MediaQuery.of(context).size.height * 0.85;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colors.bgCard,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        widget.existing != null ? 'تعديل المدخل' : 'إضافة مدخل',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: colors.primary,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(Icons.close, color: colors.textSub),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('التفاصيل',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: colors.textSub)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _details,
                    textAlign: TextAlign.right,
                    textInputAction: TextInputAction.next,
                    maxLength: 200,
                    style: TextStyle(color: colors.textMain),
                    decoration: const InputDecoration(hintText: 'اكتب الوصف'),
                  ),
                  Text('القيمة',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: colors.textSub)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _value,
                    textAlign: TextAlign.right,
                    textInputAction:
                        isStatementTab ? TextInputAction.next : TextInputAction.done,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    style: TextStyle(color: colors.textMain),
                    decoration: const InputDecoration(hintText: '0'),
                  ),
                  if (isStatementTab) ...[
                    const SizedBox(height: 14),
                    Text('مستلم',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colors.red)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _received,
                      textAlign: TextAlign.right,
                      textInputAction: TextInputAction.done,
                      style: TextStyle(color: colors.red),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      ],
                      decoration: const InputDecoration(hintText: '0'),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(_error!, style: TextStyle(color: colors.red, fontSize: 13)),
                  ],
                  const SizedBox(height: 18),
                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('تم'),
                  ),
                  if (widget.existing != null) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _saving ? null : _confirmDelete,
                      child: Text('حذف المدخل', style: TextStyle(color: colors.red)),
                    ),
                  ],
                  SizedBox(height: MediaQuery.of(context).viewInsets.bottom > 0 ? 8 : 0),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
