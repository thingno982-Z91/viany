import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// A single entry (row) inside a "بيان" or "مصروف" tab.
class Entry {
  final String id;
  final String details;
  final double value; // القيمة
  final double received; // مستلم (0 for expense entries)
  final DateTime date;

  Entry({
    String? id,
    required this.details,
    required double value,
    double received = 0,
    required this.date,
  })  : id = id ?? _uuid.v4(),
        // Defensive: guard against NaN/Infinity ever reaching persisted
        // data (e.g. from a malformed calculation), which would otherwise
        // corrupt totals silently.
        value = value.isFinite ? value : 0.0,
        received = received.isFinite ? received : 0.0;

  double get remaining => value - received;

  Entry copyWith({
    String? details,
    double? value,
    double? received,
    DateTime? date,
  }) {
    return Entry(
      id: id,
      details: details ?? this.details,
      value: value ?? this.value,
      received: received ?? this.received,
      date: date ?? this.date,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'details': details,
        'value': value,
        'received': received,
        'date': date.toIso8601String(),
      };

  /// Parses one entry defensively: any missing/malformed field falls back
  /// to a safe default instead of throwing, so a single corrupted entry
  /// can't take down the whole statement's data on load.
  factory Entry.fromJson(Map<String, dynamic> json) {
    DateTime parsedDate;
    try {
      parsedDate = DateTime.parse(json['date'] as String? ?? '');
    } catch (_) {
      parsedDate = DateTime.now();
    }
    return Entry(
      id: json['id'] as String? ?? _uuid.v4(),
      details: json['details'] as String? ?? '',
      value: (json['value'] as num?)?.toDouble() ?? 0.0,
      received: (json['received'] as num?)?.toDouble() ?? 0.0,
      date: parsedDate,
    );
  }
}

/// A statement (بيان) folder — contains its own separate lists
/// of "بيان" entries and "مصروف" entries.
class Statement {
  final String id;
  String name;
  List<Entry> statementEntries; // تبويب "بيان"
  List<Entry> expenseEntries; // تبويب "مصروف"

  Statement({
    String? id,
    required this.name,
    List<Entry>? statementEntries,
    List<Entry>? expenseEntries,
  })  : id = id ?? _uuid.v4(),
        statementEntries = statementEntries ?? [],
        expenseEntries = expenseEntries ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'statementEntries': statementEntries.map((e) => e.toJson()).toList(),
        'expenseEntries': expenseEntries.map((e) => e.toJson()).toList(),
      };

  /// Parses one statement defensively: if an individual entry within the
  /// list is corrupted, it's skipped rather than failing the entire
  /// statement (and therefore the entire app) from loading.
  factory Statement.fromJson(Map<String, dynamic> json) {
    List<Entry> parseEntries(dynamic raw) {
      if (raw is! List) return [];
      final result = <Entry>[];
      for (final item in raw) {
        try {
          result.add(Entry.fromJson(Map<String, dynamic>.from(item as Map)));
        } catch (_) {
          // Skip this single malformed entry; keep the rest intact.
        }
      }
      return result;
    }

    return Statement(
      id: json['id'] as String? ?? _uuid.v4(),
      name: json['name'] as String? ?? 'بيان',
      statementEntries: parseEntries(json['statementEntries']),
      expenseEntries: parseEntries(json['expenseEntries']),
    );
  }
}

enum EntryTab { statement, expense }

enum DateSystem { gregorian, hijri }

enum NumeralSystem { arabic, hindi }

/// User settings, persisted locally.
class AppSettings {
  String name;
  String job;
  String phone;
  bool includePersonalInfo;
  DateSystem dateSystem;
  NumeralSystem numeralSystem;

  AppSettings({
    this.name = '',
    this.job = '',
    this.phone = '',
    this.includePersonalInfo = false,
    this.dateSystem = DateSystem.gregorian,
    this.numeralSystem = NumeralSystem.arabic,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'job': job,
        'phone': phone,
        'includePersonalInfo': includePersonalInfo,
        'dateSystem': dateSystem.name,
        'numeralSystem': numeralSystem.name,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    try {
      return AppSettings(
        name: json['name'] as String? ?? '',
        job: json['job'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        includePersonalInfo: json['includePersonalInfo'] as bool? ?? false,
        dateSystem: DateSystem.values.firstWhere(
          (e) => e.name == (json['dateSystem'] as String? ?? 'gregorian'),
          orElse: () => DateSystem.gregorian,
        ),
        numeralSystem: NumeralSystem.values.firstWhere(
          (e) => e.name == (json['numeralSystem'] as String? ?? 'arabic'),
          orElse: () => NumeralSystem.arabic,
        ),
      );
    } catch (_) {
      return AppSettings();
    }
  }
}
