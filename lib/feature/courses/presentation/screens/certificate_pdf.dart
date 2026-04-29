import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Builds a printable certificate PDF for the finished course and
/// hands it off to the OS share sheet via the `printing` package.
///
/// The visual is intentionally close to the in-app preview in
/// `course_detail_page.dart`: cream gradient, gold border, gold seal,
/// name + course + date + instructor signature line.
Future<void> shareCertificatePdf({
  required String studentName,
  required String courseTitle,
  required String instructor,
  required String date,
}) async {
  final pdf = await _buildCertificatePdf(
    studentName: studentName,
    courseTitle: courseTitle,
    instructor: instructor,
    date: date,
  );

  await Printing.sharePdf(
    bytes: pdf,
    filename:
        'vozhaomuz-certificate-${courseTitle.replaceAll(RegExp(r'\s+'), '-').toLowerCase()}.pdf',
  );
}

Future<Uint8List> _buildCertificatePdf({
  required String studentName,
  required String courseTitle,
  required String instructor,
  required String date,
}) async {
  // Fonts that support Cyrillic. Using bundled Noto loaded via the
  // `printing` helper so we don't have to ship our own.
  final regular = await PdfGoogleFonts.notoSansRegular();
  final bold = await PdfGoogleFonts.notoSansBold();
  final italic = await PdfGoogleFonts.playfairDisplayBoldItalic();
  final script = await PdfGoogleFonts.dancingScriptBold();

  final doc = pw.Document();

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: pw.EdgeInsets.zero,
      build: (ctx) => _certificateLayout(
        regular: regular,
        bold: bold,
        italic: italic,
        script: script,
        studentName: studentName,
        courseTitle: courseTitle,
        instructor: instructor,
        date: date,
      ),
    ),
  );
  return doc.save();
}

pw.Widget _certificateLayout({
  required pw.Font regular,
  required pw.Font bold,
  required pw.Font italic,
  required pw.Font script,
  required String studentName,
  required String courseTitle,
  required String instructor,
  required String date,
}) {
  const gold = PdfColor.fromInt(0xFFFDB022);
  const goldDark = PdfColor.fromInt(0xFFE48B0B);
  const cream = PdfColor.fromInt(0xFFFFFBEB);
  const ink = PdfColor.fromInt(0xFF1D2939);
  const muted = PdfColor.fromInt(0xFF667085);
  const blue = PdfColor.fromInt(0xFF1D4ED8);

  return pw.Container(
    color: cream,
    padding: const pw.EdgeInsets.all(28),
    child: pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: gold, width: 3),
        borderRadius: pw.BorderRadius.circular(12),
        color: PdfColors.white,
      ),
      padding: const pw.EdgeInsets.all(28),
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          // Top: heading + seal.
          pw.Column(
            children: [
              pw.Container(
                width: 64,
                height: 64,
                alignment: pw.Alignment.center,
                decoration: pw.BoxDecoration(
                  shape: pw.BoxShape.circle,
                  gradient: const pw.LinearGradient(
                    colors: [gold, goldDark],
                    begin: pw.Alignment.topLeft,
                    end: pw.Alignment.bottomRight,
                  ),
                ),
                child: pw.Text(
                  '★',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 30,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 14),
              pw.Text(
                'CERTIFICATE',
                style: pw.TextStyle(
                  font: bold,
                  fontSize: 14,
                  letterSpacing: 6,
                  color: goldDark,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                'of completion',
                style: pw.TextStyle(
                  font: italic,
                  fontSize: 36,
                  color: ink,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Container(
                width: 80,
                height: 2.5,
                decoration: const pw.BoxDecoration(color: gold),
              ),
            ],
          ),
          // Middle: awarded to.
          pw.Column(
            children: [
              pw.Text(
                'AWARDED TO',
                style: pw.TextStyle(
                  font: regular,
                  fontSize: 11,
                  letterSpacing: 2,
                  color: muted,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                studentName,
                style: pw.TextStyle(
                  font: italic,
                  fontSize: 38,
                  color: ink,
                ),
              ),
              pw.SizedBox(height: 14),
              pw.Text(
                'for successfully completing the course',
                style: pw.TextStyle(font: regular, fontSize: 12, color: muted),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                courseTitle,
                style: pw.TextStyle(font: bold, fontSize: 18, color: ink),
              ),
            ],
          ),
          // Bottom: signature + date.
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Expanded(
                child: pw.Column(
                  children: [
                    pw.Text(
                      instructor,
                      style: pw.TextStyle(
                        font: script,
                        fontSize: 22,
                        color: blue,
                      ),
                    ),
                    pw.Container(
                      height: 1,
                      width: 200,
                      color: PdfColors.grey400,
                      margin: const pw.EdgeInsets.symmetric(vertical: 4),
                    ),
                    pw.Text(
                      'INSTRUCTOR',
                      style: pw.TextStyle(
                        font: regular,
                        fontSize: 9,
                        letterSpacing: 1,
                        color: muted,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(width: 30),
              pw.Expanded(
                child: pw.Column(
                  children: [
                    pw.Text(
                      date,
                      style: pw.TextStyle(font: bold, fontSize: 16, color: ink),
                    ),
                    pw.Container(
                      height: 1,
                      width: 200,
                      color: PdfColors.grey400,
                      margin: const pw.EdgeInsets.symmetric(vertical: 4),
                    ),
                    pw.Text(
                      'DATE',
                      style: pw.TextStyle(
                        font: regular,
                        fontSize: 9,
                        letterSpacing: 1,
                        color: muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

