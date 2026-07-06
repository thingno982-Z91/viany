import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../services/app_controller.dart';
import '../services/format_service.dart';
import '../services/pdf_service.dart';
import '../widgets/entry_form_sheet.dart';
import '../widgets/calendar_picker.dart';
import 'settings_sheet.dart';

class HomeScreen extends StatefulWidget {
  final AppController controller;

  const HomeScreen({super.key, required this.controller});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _calendarOpen = false;
  bool _isExporting = false;

  AppController get c => widget.controller;

  void _openStatementMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _StatementMenu(controller: c),
    );
  }

  void _openSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SettingsSheet(controller: c),
    );
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    final colors = AppColors.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textDirection: TextDirection.rtl),
        backgroundColor: isError ? colors.red : colors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _exportPdf() async {
    if (c.activeStatement == null) {
      _showSnack('لا يوجد بيان لتصديره.', isError: true);
      return;
    }
    if (c.visibleEntries.isEmpty) {
      _showSnack('لا توجد بيانات لتصديرها في هذا العرض.', isError: true);
      return;
    }

    setState(() => _isExporting = true);
    try {
      final bytes = await PdfService.buildStatementPdf(
        title: c.activeStatement!.name,
        entries: c.visibleEntries,
        tab: c.currentTab,
        settings: c.settings,
      );
      await PdfService.shareOrSavePdf(bytes, c.activeStatement!.name);
    } on PdfGenerationException catch (e) {
      _showSnack(e.message, isError: true);
    } catch (e) {
      _showSnack('حدث خطأ غير متوقع أثناء إنشاء المستند.', isError: true);
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  String _dayLabel() {
    if (c.viewAll) return 'الجميع';
    return formatDayLabel(c.selectedDate, c.settings.numeralSystem,
        dateSystem: c.settings.dateSystem);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final statement = c.activeStatement;
    final isStatementTab = c.currentTab == EntryTab.statement;
    final entries = c.visibleEntries;
    final screenWidth = MediaQuery.of(context).size.width;
    final isNarrow = screenWidth < 360;

    // If somehow there's no active statement (e.g. all statements were
    // removed in a future version), show a safe recoverable state instead
    // of crashing on a null access.
    if (statement == null) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: colors.bgApp,
          body: Center(
            child: Text('لا يوجد بيان بعد.', style: TextStyle(color: colors.textSub)),
          ),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: colors.bgApp,
        body: SafeArea(
          child: Column(
            children: [
              // Top bar
              Container(
                padding: EdgeInsets.symmetric(
                    horizontal: isNarrow ? 10 : 16, vertical: 12),
                decoration: BoxDecoration(
                  color: colors.bgCard,
                  border: Border(bottom: BorderSide(color: colors.border)),
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _openSettings,
                      icon: Icon(Icons.settings, color: colors.primary),
                      tooltip: 'الإعدادات',
                    ),
                    const Spacer(),
                    Flexible(
                      child: GestureDetector(
                        onTap: _openStatementMenu,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: colors.bgSoft,
                            border: Border.all(color: colors.border),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  statement.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: colors.primary,
                                      fontSize: 15),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.keyboard_arrow_down,
                                  color: colors.primaryLight, size: 18),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Document icon + date nav
              Padding(
                padding: EdgeInsets.fromLTRB(isNarrow ? 10 : 16, 10, isNarrow ? 10 : 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _isExporting ? null : _exportPdf,
                      tooltip: 'تصدير PDF',
                      icon: _isExporting
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: colors.primary),
                            )
                          : Icon(Icons.description_outlined, color: colors.primary),
                      style: IconButton.styleFrom(
                        backgroundColor: colors.bgSoft,
                        side: BorderSide(color: colors.border),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: colors.bgCard,
                          border: Border.all(color: colors.border),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              onPressed: c.goPrevDay,
                              icon: Icon(Icons.chevron_right, color: colors.primaryLight),
                            ),
                            Flexible(
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _calendarOpen = !_calendarOpen),
                                child: Text(
                                  _dayLabel(),
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold, color: colors.primary),
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: c.goNextDay,
                              icon: Icon(Icons.chevron_left, color: colors.primaryLight),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (_calendarOpen) ...[
                const SizedBox(height: 10),
                CalendarPicker(
                  selectedDate: c.selectedDate,
                  viewAll: c.viewAll,
                  onSelectDate: (d) {
                    c.setSelectedDate(d);
                    setState(() => _calendarOpen = false);
                  },
                  onSelectAll: () {
                    c.setViewAll(true);
                    setState(() => _calendarOpen = false);
                  },
                ),
              ],

              // Column headers
              Padding(
                padding: EdgeInsets.fromLTRB(isNarrow ? 16 : 24, 14, isNarrow ? 16 : 24, 4),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text('التفاصيل',
                          textAlign: TextAlign.right,
                          style: TextStyle(fontWeight: FontWeight.bold, color: colors.primary)),
                    ),
                    Expanded(
                      child: Text('القيمة',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontWeight: FontWeight.bold, color: colors.primary)),
                    ),
                    if (isStatementTab)
                      Expanded(
                        child: Text('مستلم',
                            textAlign: TextAlign.left,
                            style: TextStyle(fontWeight: FontWeight.bold, color: colors.red)),
                      ),
                  ],
                ),
              ),

              // Entries list — ListView.builder keeps long lists (many
              // months of daily entries under "الجميع") smooth, since it
              // only builds the rows currently visible on screen.
              Expanded(
                child: entries.isEmpty
                    ? Center(
                        child: Text('لا توجد مدخلات لهذا اليوم',
                            style: TextStyle(color: colors.textSub)),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        itemCount: entries.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final e = entries[i];
                          return _EntryRow(
                            entry: e,
                            isStatementTab: isStatementTab,
                            showDate: c.viewAll,
                            numeralSystem: c.settings.numeralSystem,
                            dateSystem: c.settings.dateSystem,
                            colors: colors,
                            onTap: () =>
                                showEntryFormSheet(context, controller: c, existing: e),
                          );
                        },
                      ),
              ),

              // Totals row: الباقي | المجموع
              Container(
                decoration: BoxDecoration(
                  color: colors.bgCard,
                  border: Border(top: BorderSide(color: colors.border)),
                ),
                child: Row(
                  children: [
                    _InlineTotal(
                      label: 'الباقي',
                      value: c.visibleTotalRemaining,
                      numeralSystem: c.settings.numeralSystem,
                      color: isStatementTab
                          ? (c.visibleTotalRemaining < 0 ? colors.red : colors.green)
                          : colors.primary,
                      textSubColor: colors.textSub,
                    ),
                    Container(width: 1, height: 40, color: colors.border),
                    _InlineTotal(
                      label: 'المجموع',
                      value: c.grandTotalRemaining,
                      numeralSystem: c.settings.numeralSystem,
                      color: isStatementTab
                          ? (c.grandTotalRemaining < 0 ? colors.red : colors.green)
                          : colors.primary,
                      textSubColor: colors.textSub,
                    ),
                  ],
                ),
              ),

              // Bottom tabs
              Row(
                children: [
                  Expanded(
                    child: _TabButton(
                      label: 'بيان',
                      active: c.currentTab == EntryTab.statement,
                      onTap: () => c.setTab(EntryTab.statement),
                      colors: colors,
                    ),
                  ),
                  Expanded(
                    child: _TabButton(
                      label: 'مصروف',
                      active: c.currentTab == EntryTab.expense,
                      onTap: () => c.setTab(EntryTab.expense),
                      colors: colors,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: Padding(
          padding: const EdgeInsets.only(bottom: 70),
          child: FloatingActionButton(
            backgroundColor: colors.primary,
            onPressed: () => showEntryFormSheet(context, controller: c),
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  final Entry entry;
  final bool isStatementTab;
  final bool showDate;
  final NumeralSystem numeralSystem;
  final DateSystem dateSystem;
  final AppPalette colors;
  final VoidCallback onTap;

  const _EntryRow({
    required this.entry,
    required this.isStatementTab,
    required this.showDate,
    required this.numeralSystem,
    required this.dateSystem,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: colors.bgCard,
          border: Border.all(color: colors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    entry.details.isEmpty ? 'بدون وصف' : entry.details,
                    textAlign: TextAlign.right,
                    // Long details wrap onto multiple lines instead of
                    // being clipped or forcing the row to overflow.
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w600, color: colors.textMain),
                  ),
                  if (showDate)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        formatDayLabel(entry.date, numeralSystem, dateSystem: dateSystem),
                        style: TextStyle(fontSize: 11, color: colors.textSub),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Text(
                formatNumber(entry.value, numeralSystem),
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w600, color: colors.textMain),
              ),
            ),
            if (isStatementTab)
              Expanded(
                child: Text(
                  formatNumber(entry.received, numeralSystem),
                  textAlign: TextAlign.left,
                  style: TextStyle(fontWeight: FontWeight.w600, color: colors.red),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InlineTotal extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final Color textSubColor;
  final NumeralSystem numeralSystem;

  const _InlineTotal({
    required this.label,
    required this.value,
    required this.color,
    required this.textSubColor,
    required this.numeralSystem,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13, color: textSubColor)),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text('${formatSigned(value, numeralSystem)} ﷼',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color)),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  final AppPalette colors;

  const _TabButton({
    required this.label,
    required this.active,
    required this.onTap,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: active ? colors.bgSoft : colors.bgCard,
          border: Border(
            top: BorderSide(
              color: active ? colors.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
            color: active ? colors.primary : colors.textSub,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}

class _StatementMenu extends StatefulWidget {
  final AppController controller;

  const _StatementMenu({required this.controller});

  @override
  State<_StatementMenu> createState() => _StatementMenuState();
}

class _StatementMenuState extends State<_StatementMenu> {
  bool _adding = false;
  final _newNameCtrl = TextEditingController();

  @override
  void dispose() {
    _newNameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final colors = AppColors.of(context);
    final maxHeight = MediaQuery.of(context).size.height * 0.7;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.bgCard,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final s in c.statements)
                  ListTile(
                    title: Text(
                      s.name,
                      textAlign: TextAlign.right,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: s.id == c.activeStatementId
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: colors.primary,
                      ),
                    ),
                    tileColor: s.id == c.activeStatementId ? colors.bgSoft : null,
                    onTap: () async {
                      await c.switchStatement(s.id);
                      if (context.mounted) Navigator.of(context).pop();
                    },
                  ),
                Divider(color: colors.border),
                if (!_adding)
                  ListTile(
                    title: Text('+ أضف بياناً',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            color: colors.primaryLight, fontWeight: FontWeight.bold)),
                    onTap: () => setState(() => _adding = true),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _newNameCtrl,
                            autofocus: true,
                            textAlign: TextAlign.right,
                            maxLength: 60,
                            style: TextStyle(color: colors.textMain),
                            decoration: const InputDecoration(hintText: 'اسم البيان'),
                            onSubmitted: (_) async {
                              if (_newNameCtrl.text.trim().isEmpty) return;
                              await c.addStatement(_newNameCtrl.text);
                              if (context.mounted) Navigator.of(context).pop();
                            },
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.check, color: colors.primary),
                          onPressed: () async {
                            if (_newNameCtrl.text.trim().isEmpty) return;
                            await c.addStatement(_newNameCtrl.text);
                            if (context.mounted) Navigator.of(context).pop();
                          },
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
