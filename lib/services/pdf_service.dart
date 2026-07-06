import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/models.dart';
import 'format_service.dart';

/// Thrown when PDF generation fails, with a message safe to show to the user.
class PdfGenerationException implements Exception {
  final String message;
  PdfGenerationException(this.message);
  @override
  String toString() => message;
}

/// Builds and shares/saves a real PDF file that mirrors the in-app table:
/// right-to-left columns, colored مستلم/الباقي, and totals boxes.
///
/// Design goals for this version:
/// - Real Arabic font (fetched via PdfGoogleFonts from the `printing`
///   package, cached after first use — no manual font file needed).
/// - Brand logo shown top-left of the document header.
/// - Long "التفاصيل" text wraps instead of overflowing or shrinking the page.
/// - Table uses fixed-friendly column widths so nothing runs off the page,
///   even on narrow content or many rows (multi-page automatically).
/// - All failures throw PdfGenerationException with a clear Arabic message
///   instead of letting the app crash.
class PdfService {
  static const PdfColor primary = PdfColor.fromInt(0xFF1E3A5F);
  static const PdfColor bgSoft = PdfColor.fromInt(0xFFEAF0F8);
  static const PdfColor border = PdfColor.fromInt(0xFFC9D8EB);
  static const PdfColor green = PdfColor.fromInt(0xFF1F8A4C);
  static const PdfColor red = PdfColor.fromInt(0xFFC43D3D);
  static const PdfColor rowAlt = PdfColor.fromInt(0xFFF7FAFD);
  static const PdfColor textSub = PdfColor.fromInt(0xFF5A7290);

  static pw.Font? _regularFont;
  static pw.Font? _boldFont;
  static pw.MemoryImage? _logoImage;
  static bool _logoLoadAttempted = false;

  static Future<void> _ensureFonts() async {
    try {
      _regularFont ??= await PdfGoogleFonts.notoNaskhArabicRegular();
      _boldFont ??= await PdfGoogleFonts.notoNaskhArabicBold();
    } catch (e) {
      throw PdfGenerationException(
        'تعذّر تحميل الخط العربي للمستند. تأكد من الاتصال بالإنترنت أول مرة '
        'تستخدم فيها التصدير (يتم حفظ الخط بعدها ويعمل بدون إنترنت).',
      );
    }
  }

  /// Loads the brand logo once and caches it. If the asset is ever missing
  /// (e.g. a stripped-down build), this fails silently and the header
  /// simply omits the logo instead of breaking PDF export entirely.
  static Future<pw.MemoryImage?> _ensureLogo() async {
    if (_logoLoadAttempted) return _logoImage;
    _logoLoadAttempted = true;
    try {
      final bytes = await rootBundle.load('assets/images/logo.png');
      _logoImage = pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (_) {
      _logoImage = null;
    }
    return _logoImage;
  }

  /// Generates the PDF bytes for a "بيان" (statement) or "مصروف" (expense) export.
  ///
  /// [entries] should already be filtered to whatever the user is viewing
  /// (a single day, or "الجميع" for everything) — the export always matches
  /// exactly what's on screen at the moment the user taps the document icon.
  ///
  /// Throws [PdfGenerationException] on any failure — callers should catch
  /// this and show the message to the user rather than letting it crash.
  static Future<Uint8List> buildStatementPdf({
    required String title,
    required List<Entry> entries,
    required EntryTab tab,
    required AppSettings settings,
  }) async {
    if (title.trim().isEmpty) {
      throw PdfGenerationException('لا يمكن إنشاء المستند: اسم البيان فارغ.');
    }

    try {
      await _ensureFonts();
      final logo = await _ensureLogo();

      final doc = pw.Document();
      final isStatement = tab == EntryTab.statement;

      final totalValue = entries.fold<double>(0, (a, e) => a + e.value);
      final totalReceived = isStatement
          ? entries.fold<double>(0, (a, e) => a + e.received)
          : 0.0;
      final totalRemaining =
          isStatement ? totalValue - totalReceived : totalValue;

      final baseStyle = pw.TextStyle(font: _regularFont, fontSize: 12);
      final boldStyle = pw.TextStyle(
          font: _boldFont, fontSize: 12, fontWeight: pw.FontWeight.bold);

      pw.Widget buildPersonalBox() {
        if (!settings.includePersonalInfo) return pw.SizedBox();
        final lines = <String>[];
        if (settings.name.trim().isNotEmpty) lines.add(settings.name.trim());
        if (settings.job.trim().isNotEmpty) lines.add(settings.job.trim());
        if (settings.phone.trim().isNotEmpty) lines.add(settings.phone.trim());
        if (lines.isEmpty) return pw.SizedBox();
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: lines
              .map((l) => pw.Text(l,
                  style: pw.TextStyle(
                      font: _regularFont, fontSize: 10, color: textSub)))
              .toList(),
        );
      }

      // Fixed column widths (in flex ratio) that keep every column readable
      // and prevent overflow: التفاصيل gets the most room and wraps freely,
      // numeric columns stay compact and never wrap awkwardly.
      final columnWidths = isStatement
          ? <int, pw.TableColumnWidth>{
              0: const pw.FlexColumnWidth(1.0), // الباقي
              1: const pw.FlexColumnWidth(1.0), // مستلم
              2: const pw.FlexColumnWidth(1.0), // القيمة
              3: const pw.FlexColumnWidth(2.4), // الوصف (wraps)
              4: const pw.FlexColumnWidth(1.2), // التاريخ
            }
          : <int, pw.TableColumnWidth>{
              0: const pw.FlexColumnWidth(1.0), // القيمة
              1: const pw.FlexColumnWidth(2.6), // التفاصيل (wraps)
            };

      pw.Widget cell(String text,
          {required pw.TextStyle style, bool alignRight = false}) {
        return pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          child: pw.Text(
            text.isEmpty ? '-' : text,
            textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.center,
            style: style,
            softWrap: true,
            overflow: pw.TextOverflow.visible,
          ),
        );
      }

      List<pw.TableRow> buildRows() {
        final headers = isStatement
            ? ['الباقي', 'مستلم', 'القيمة', 'الوصف', 'التاريخ']
            : ['القيمة', 'التفاصيل'];

        final rows = <pw.TableRow>[
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: bgSoft),
            children: headers
                .map((h) => pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(
                          vertical: 10, horizontal: 6),
                      child: pw.Text(h,
                          textAlign: pw.TextAlign.center,
                          style: boldStyle.copyWith(color: primary)),
                    ))
                .toList(),
          ),
        ];

        for (var i = 0; i < entries.length; i++) {
          final e = entries[i];
          final bg = i % 2 == 1 ? rowAlt : PdfColors.white;
          // Guard against malformed/missing data instead of crashing.
          final safeDetails =
              e.details.trim().isEmpty ? 'بدون وصف' : e.details.trim();
          final safeValue = e.value.isFinite ? e.value : 0.0;
          final safeReceived = e.received.isFinite ? e.received : 0.0;

          if (isStatement) {
            final remaining = safeValue - safeReceived;
            rows.add(pw.TableRow(
              decoration: pw.BoxDecoration(color: bg),
              children: [
                cell(formatSigned(remaining, settings.numeralSystem),
                    style: baseStyle.copyWith(
                        color: remaining < 0 ? red : green,
                        fontWeight: pw.FontWeight.bold)),
                cell(formatNumber(safeReceived, settings.numeralSystem),
                    style: baseStyle.copyWith(
                        color: red, fontWeight: pw.FontWeight.bold)),
                cell(formatNumber(safeValue, settings.numeralSystem),
                    style: baseStyle),
                cell(safeDetails, style: baseStyle, alignRight: true),
                cell(
                    formatDayLabel(e.date, settings.numeralSystem,
                        dateSystem: settings.dateSystem),
                    style: baseStyle),
              ],
            ));
          } else {
            rows.add(pw.TableRow(
              decoration: pw.BoxDecoration(color: bg),
              children: [
                cell(formatNumber(safeValue, settings.numeralSystem),
                    style: baseStyle),
                cell(safeDetails, style: baseStyle, alignRight: true),
              ],
            ));
          }
        }

        if (!isStatement) {
          rows.add(pw.TableRow(
            decoration: const pw.BoxDecoration(color: bgSoft),
            children: [
              cell(formatNumber(totalValue, settings.numeralSystem),
                  style: boldStyle.copyWith(color: primary)),
              cell('المجموع',
                  style: boldStyle.copyWith(color: primary),
                  alignRight: true),
            ],
          ));
        }

        return rows;
      }

      pw.Widget buildTotalsRow() {
        if (!isStatement) return pw.SizedBox();
        pw.Widget box(String label, String value, PdfColor color) {
          return pw.Container(
            padding:
                const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: pw.BoxDecoration(
              color: bgSoft,
              border: pw.Border.all(color: border),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.Text(label,
                    style: pw.TextStyle(
                        font: _regularFont, fontSize: 9, color: textSub)),
                pw.SizedBox(height: 4),
                pw.Text(value,
                    style: pw.TextStyle(
                        font: _boldFont,
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                        color: color)),
              ],
            ),
          );
        }

        // Wrap so totals never overflow narrow page widths.
        return pw.Padding(
          padding: const pw.EdgeInsets.only(top: 18),
          child: pw.Wrap(
            alignment: pw.WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              box('مجموع القيمة',
                  '${formatNumber(totalValue, settings.numeralSystem)} ﷼',
                  primary),
              box('مجموع المستلم',
                  '${formatNumber(totalReceived, settings.numeralSystem)} ﷼',
                  red),
              box(
                  'مجموع الباقي',
                  '${formatSigned(totalRemaining, settings.numeralSystem)} ﷼',
                  totalRemaining < 0 ? red : green),
            ],
          ),
        );
      }

      // MultiPage ensures the table automatically continues onto extra
      // pages if there are many entries, instead of clipping/overflowing.
      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          textDirection: pw.TextDirection.rtl,
          margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 26),
          header: (context) {
            if (context.pageNumber != 1) return pw.SizedBox();
            return pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      // Logo sits top-left of the document.
                      logo != null
                          ? pw.Image(logo, height: 40, fit: pw.BoxFit.contain)
                          : pw.SizedBox(),
                      buildPersonalBox(),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                  pw.Center(
                    child: pw.Text(
                      title,
                      style: pw.TextStyle(
                          font: _boldFont,
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                          color: primary),
                    ),
                  ),
                  pw.SizedBox(height: 16),
                ],
              ),
            );
          },
          footer: (context) => pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Align(
              alignment: pw.Alignment.center,
              child: pw.Text(
                'صفحة ${context.pageNumber} من ${context.pagesCount}',
                style: pw.TextStyle(
                    font: _regularFont, fontSize: 8, color: textSub),
              ),
            ),
          ),
          build: (context) => [
            pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Table(
                border: pw.TableBorder.all(color: border, width: 0.6),
                columnWidths: columnWidths,
                children: buildRows(),
              ),
            ),
            pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: buildTotalsRow(),
            ),
          ],
        ),
      );

      return await doc.save();
    } on PdfGenerationException {
      rethrow;
    } catch (e) {
      throw PdfGenerationException(
          'حدث خطأ غير متوقع أثناء إنشاء المستند. حاول مرة أخرى.');
    }
  }

  /// Opens the native share/save sheet so the user can save the PDF
  /// to their phone or share it directly.
  ///
  /// Throws [PdfGenerationException] if sharing fails (e.g. no share
  /// target available, storage permission denied).
  static Future<void> shareOrSavePdf(Uint8List bytes, String fileName) async {
    try {
      final safeName = fileName.trim().isEmpty ? 'بيان' : fileName.trim();
      await Printing.sharePdf(bytes: bytes, filename: '$safeName.pdf');
    } catch (e) {
      throw PdfGenerationException(
          'تعذّرت مشاركة أو حفظ الملف. تحقق من صلاحيات التخزين والمشاركة.');
    }
  }
}
