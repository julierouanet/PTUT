import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Génère une étiquette de maintenance préventive au format A6 paysage.
///
/// Aucun appel réseau — toutes les données sont passées en paramètre
/// depuis [EquipmentMaintenanceTab] après validation PM.
class PdfLabelService {
  static const _primary   = PdfColors.blue800;
  static const _border    = PdfColors.grey400;
  static const _textMuted = PdfColors.grey600;

  static const _hospitalName = 'Hôpital de District de Kabutare';

  /// Construit et retourne les octets du PDF A6 paysage.
  static Future<Uint8List> generateMaintenanceLabel({
    required String equipmentName,
    required String? serialNumber,
    required String department,
    required String technicianName,
    required String performedAt,
    required String nextPm,
  }) async {
    final doc = pw.Document();

    // Format A6 paysage : 148mm × 105mm
    const pageFormat = PdfPageFormat(
      148 * PdfPageFormat.mm,
      105 * PdfPageFormat.mm,
    );

    final performedFormatted = _formatDate(performedAt);
    final nextFormatted      = _formatDate(nextPm);

    doc.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: pw.EdgeInsets.all(10 * PdfPageFormat.mm),
        build: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            // ── En-tête hôpital ───────────────────────────────────────
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4),
              decoration: pw.BoxDecoration(
                color: _primary,
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Text(
                _hospitalName,
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                textAlign: pw.TextAlign.center,
              ),
            ),
            pw.SizedBox(height: 6),

            // ── Séparateur ────────────────────────────────────────────
            pw.Divider(color: _border, thickness: 0.5),
            pw.SizedBox(height: 4),

            // ── Informations équipement ───────────────────────────────
            _labelRow('Équipement', equipmentName),
            if (serialNumber != null && serialNumber.isNotEmpty)
              _labelRow('N° série', serialNumber),
            _labelRow('Département', department),

            pw.SizedBox(height: 4),
            pw.Divider(color: _border, thickness: 0.5),
            pw.SizedBox(height: 4),

            // ── Informations maintenance ──────────────────────────────
            _labelRow('Technicien', technicianName),
            _labelRow('Date maint.', performedFormatted),
            _labelRow(
              'Prochaine',
              nextFormatted,
              valueStyle: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: _primary,
              ),
            ),
          ],
        ),
      ),
    );

    return doc.save();
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  static pw.Widget _labelRow(
    String label,
    String value, {
    pw.TextStyle? valueStyle,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 65,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 9,
                color: _textMuted,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: valueStyle ??
                  pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  /// Formate un ISO datetime → DD/MM/YYYY
  static String _formatDate(String iso) {
    if (iso.length < 10) return iso;
    final s = iso.substring(0, 10).split('-');
    if (s.length != 3) return iso;
    return '${s[2]}/${s[1]}/${s[0]}';
  }
}
