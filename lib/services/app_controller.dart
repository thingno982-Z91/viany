import 'package:flutter/material.dart';
import '../models/models.dart';
import 'storage_service.dart';

/// Central state controller for the whole app.
///
/// Error handling philosophy: storage operations can fail (corrupted data,
/// full disk, etc). Instead of letting exceptions bubble up and crash the
/// UI, every mutating method here catches [StorageException], stores the
/// message in [lastError], and notifies listeners so the UI can show it
/// (e.g. a SnackBar) — the in-memory state still updates so the user's
/// action isn't silently lost even if persistence briefly fails.
class AppController extends ChangeNotifier {
  final StorageService _storage = StorageService();

  List<Statement> statements = [];
  String? activeStatementId;
  AppSettings settings = AppSettings();
  bool hasOnboarded = false;
  bool isLoading = true;
  String? lastError;

  EntryTab currentTab = EntryTab.statement;
  DateTime selectedDate = DateTime.now();
  bool viewAll = false;

  Statement? get activeStatement {
    if (statements.isEmpty) return null;
    if (activeStatementId == null) return statements.first;
    try {
      return statements.firstWhere((s) => s.id == activeStatementId);
    } catch (_) {
      return statements.first;
    }
  }

  void clearError() {
    lastError = null;
    notifyListeners();
  }

  Future<void> load() async {
    try {
      await _storage.init();
      hasOnboarded = _storage.hasOnboarded();
      statements = await _storage.loadStatements();
      settings = _storage.loadSettings();
      activeStatementId = _storage.loadActiveStatementId();

      if (statements.isNotEmpty &&
          (activeStatementId == null ||
              !statements.any((s) => s.id == activeStatementId))) {
        activeStatementId = statements.first.id;
      }
    } on StorageException catch (e) {
      lastError = e.message;
      // Fall back to a safe empty state so the app remains usable.
      statements = [];
      settings = AppSettings();
      hasOnboarded = false;
    } catch (e) {
      lastError = 'حدث خطأ غير متوقع أثناء تحميل البيانات.';
      statements = [];
      settings = AppSettings();
      hasOnboarded = false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> completeOnboarding(String name) async {
    final finalName = name.trim().isEmpty ? 'البيان الرئيسي' : name.trim();
    final statement = Statement(name: finalName);
    statements = [statement];
    activeStatementId = statement.id;
    hasOnboarded = true;
    try {
      await _storage.setOnboarded();
      await _persist();
    } on StorageException catch (e) {
      lastError = e.message;
    }
    notifyListeners();
  }

  Future<void> addStatement(String name) async {
    if (name.trim().isEmpty) return;
    final statement = Statement(name: name.trim());
    statements.add(statement);
    activeStatementId = statement.id;
    viewAll = false;
    selectedDate = DateTime.now();
    await _persist();
    notifyListeners();
  }

  Future<void> switchStatement(String id) async {
    activeStatementId = id;
    viewAll = false;
    selectedDate = DateTime.now();
    try {
      await _storage.saveActiveStatementId(id);
    } on StorageException catch (e) {
      lastError = e.message;
    }
    notifyListeners();
  }

  void setTab(EntryTab tab) {
    currentTab = tab;
    notifyListeners();
  }

  void setSelectedDate(DateTime date) {
    selectedDate = date;
    viewAll = false;
    notifyListeners();
  }

  void goPrevDay() {
    selectedDate = selectedDate.subtract(const Duration(days: 1));
    viewAll = false;
    notifyListeners();
  }

  void goNextDay() {
    selectedDate = selectedDate.add(const Duration(days: 1));
    viewAll = false;
    notifyListeners();
  }

  void setViewAll(bool value) {
    viewAll = value;
    notifyListeners();
  }

  List<Entry> get currentTabEntries {
    final s = activeStatement;
    if (s == null) return [];
    return currentTab == EntryTab.statement
        ? s.statementEntries
        : s.expenseEntries;
  }

  List<Entry> get visibleEntries {
    final all = currentTabEntries;
    if (viewAll) {
      final sorted = [...all]..sort((a, b) => a.date.compareTo(b.date));
      return sorted;
    }
    return all.where((e) => _isSameDay(e.date, selectedDate)).toList();
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Adds a new entry. Guards against a missing active statement (shouldn't
  /// normally happen, but prevents a crash if it ever does) and against
  /// non-finite numeric input (e.g. if a text field parse ever slips through).
  Future<void> addEntry({
    required String details,
    required double value,
    double received = 0,
    DateTime? date,
  }) async {
    final s = activeStatement;
    if (s == null) {
      lastError = 'لا يوجد بيان نشط لإضافة المدخل إليه.';
      notifyListeners();
      return;
    }
    final safeValue = value.isFinite ? value : 0.0;
    final safeReceived = received.isFinite ? received : 0.0;

    final entry = Entry(
      details: details.trim(),
      value: safeValue,
      received: currentTab == EntryTab.statement ? safeReceived : 0,
      date: date ?? selectedDate,
    );
    if (currentTab == EntryTab.statement) {
      s.statementEntries.add(entry);
    } else {
      s.expenseEntries.add(entry);
    }
    await _persist();
    notifyListeners();
  }

  Future<void> updateEntry(
    String entryId, {
    required String details,
    required double value,
    double received = 0,
  }) async {
    final s = activeStatement;
    if (s == null) return;
    final list = currentTab == EntryTab.statement
        ? s.statementEntries
        : s.expenseEntries;
    final idx = list.indexWhere((e) => e.id == entryId);
    if (idx == -1) return;

    final safeValue = value.isFinite ? value : 0.0;
    final safeReceived = received.isFinite ? received : 0.0;

    list[idx] = list[idx].copyWith(
      details: details.trim(),
      value: safeValue,
      received: currentTab == EntryTab.statement ? safeReceived : 0,
    );
    await _persist();
    notifyListeners();
  }

  Future<void> deleteEntry(String entryId) async {
    final s = activeStatement;
    if (s == null) return;
    if (currentTab == EntryTab.statement) {
      s.statementEntries.removeWhere((e) => e.id == entryId);
    } else {
      s.expenseEntries.removeWhere((e) => e.id == entryId);
    }
    await _persist();
    notifyListeners();
  }

  Future<void> updateSettings(AppSettings newSettings) async {
    settings = newSettings;
    try {
      await _storage.saveSettings(settings);
    } on StorageException catch (e) {
      lastError = e.message;
    }
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      await _storage.saveStatements(statements);
      if (activeStatementId != null) {
        await _storage.saveActiveStatementId(activeStatementId!);
      }
    } on StorageException catch (e) {
      lastError = e.message;
    } catch (e) {
      lastError = 'تعذّر حفظ التغييرات. حاول مرة أخرى.';
    }
  }

  // ---- Totals helpers ----

  double sumValue(List<Entry> entries) =>
      entries.fold(0, (a, e) => a + e.value);
  double sumReceived(List<Entry> entries) =>
      entries.fold(0, (a, e) => a + e.received);

  double get visibleTotalValue => sumValue(visibleEntries);
  double get visibleTotalReceived =>
      currentTab == EntryTab.statement ? sumReceived(visibleEntries) : 0;
  double get visibleTotalRemaining => currentTab == EntryTab.statement
      ? visibleTotalValue - visibleTotalReceived
      : visibleTotalValue;

  double get grandTotalRemaining {
    final all = currentTabEntries;
    if (currentTab == EntryTab.statement) {
      return sumValue(all) - sumReceived(all);
    }
    return sumValue(all);
  }
}
