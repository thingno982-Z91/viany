import 'package:hive_flutter/hive_flutter.dart';
import '../models/models.dart';

/// Thrown when a local save/load operation fails, with a message
/// safe to show directly to the user.
class StorageException implements Exception {
  final String message;
  StorageException(this.message);
  @override
  String toString() => message;
}

/// Handles saving/loading all app data locally on the device using Hive,
/// so data reliably persists between app launches.
///
/// Hive was chosen over SharedPreferences because this app's data
/// (potentially many statements, each with many dated entries) is
/// structured and can grow large over time — Hive handles that volume
/// efficiently, while SharedPreferences is only meant for small key/value
/// settings and would slow down or risk data loss as entries accumulate.
class StorageService {
  static const _statementsBox = 'statements_box_v1';
  static const _metaBox = 'meta_box_v1';

  static const _statementsKey = 'statements';
  static const _activeStatementKey = 'active_statement_id';
  static const _settingsKey = 'app_settings';
  static const _hasOnboardedKey = 'has_onboarded';

  Box? _statements;
  Box? _meta;

  /// Must be called once before any other method (done in main()).
  Future<void> init() async {
    try {
      await Hive.initFlutter();
      _statements = await Hive.openBox(_statementsBox);
      _meta = await Hive.openBox(_metaBox);
    } catch (e) {
      throw StorageException(
          'تعذّر فتح قاعدة البيانات المحلية. أعد تشغيل التطبيق، وإذا تكررت '
          'المشكلة قد تحتاج لإعادة تثبيت التطبيق.');
    }
  }

  Future<void> saveStatements(List<Statement> statements) async {
    try {
      final list = statements.map((s) => s.toJson()).toList();
      await _statements!.put(_statementsKey, list);
    } catch (e) {
      throw StorageException(
          'تعذّر حفظ البيانات. تأكد من وجود مساحة تخزين كافية على الجهاز.');
    }
  }

  Future<List<Statement>> loadStatements() async {
    try {
      final raw = _statements!.get(_statementsKey);
      if (raw == null) return [];
      final list = (raw as List).cast<dynamic>();
      final result = <Statement>[];
      for (final item in list) {
        try {
          result.add(Statement.fromJson(Map<String, dynamic>.from(item as Map)));
        } catch (_) {
          // Skip only this one corrupted statement; keep the rest of the
          // user's data intact instead of wiping everything.
        }
      }
      return result;
    } catch (e) {
      // The box itself is unreadable (not just one bad statement) —
      // this is the only case where we truly have nothing to recover.
      throw StorageException(
          'تعذّرت قراءة البيانات المحفوظة، قد تكون تالفة. سيبدأ التطبيق '
          'ببيانات فارغة لتفادي التعطل.');
    }
  }

  Future<void> saveActiveStatementId(String id) async {
    try {
      await _meta!.put(_activeStatementKey, id);
    } catch (e) {
      // Non-critical: failing to remember the last open statement
      // shouldn't interrupt the user's flow.
    }
  }

  String? loadActiveStatementId() {
    try {
      return _meta!.get(_activeStatementKey) as String?;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveSettings(AppSettings settings) async {
    try {
      await _meta!.put(_settingsKey, settings.toJson());
    } catch (e) {
      throw StorageException('تعذّر حفظ الإعدادات.');
    }
  }

  AppSettings loadSettings() {
    try {
      final raw = _meta!.get(_settingsKey);
      if (raw == null) return AppSettings();
      return AppSettings.fromJson(Map<String, dynamic>.from(raw as Map));
    } catch (_) {
      return AppSettings();
    }
  }

  bool hasOnboarded() {
    try {
      return _meta!.get(_hasOnboardedKey, defaultValue: false) as bool;
    } catch (_) {
      return false;
    }
  }

  Future<void> setOnboarded() async {
    try {
      await _meta!.put(_hasOnboardedKey, true);
    } catch (e) {
      throw StorageException('تعذّر حفظ حالة الإعداد الأولي.');
    }
  }
}
