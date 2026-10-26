import 'package:crm_app/screen/invoice/modal/invoice_model.dart';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Exports invoices to Excel in this layout:
///
///   Invoice # | Deal | Status | Amount | Currency | Paid | Balance Due |
///   Assigned To | Due Date
///
/// followed by one "TOTAL (<CCY>)" row per currency. Every figure is in
/// the invoice's own currency — currencies are never added together.
class InvoiceExcelExporter {
  InvoiceExcelExporter._();

  static const MethodChannel _channel = MethodChannel('crm/downloads');

  // Column indexes — keep in step with [_headers].
  static const _cInvoice = 0,
      _cDeal = 1,
      _cStatus = 2,
      _cAmount = 3,
      _cCurrency = 4,
      _cPaid = 5,
      _cBalance = 6,
      _cAssigned = 7,
      _cDue = 8;

  static const _headers = <String>[
    'Invoice #',
    'Deal',
    'Status',
    'Amount',
    'Currency',
    'Paid',
    'Balance Due',
    'Assigned To',
    'Due Date',
  ];

  static Future<void> export(List<Invoice> invoices) async {
    final excel = Excel.createExcel();
    const sheetName = 'Invoices';
    if (excel.tables.containsKey('Sheet1')) {
      excel.rename('Sheet1', sheetName);
    }
    final Sheet sheet = excel[sheetName];

    final headerStyle = CellStyle(
      bold: true,
      fontColorHex: ExcelColor.white,
      backgroundColorHex: ExcelColor.fromHexString('#1A7FC1'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    sheet.setColumnWidth(_cInvoice, 14);
    sheet.setColumnWidth(_cDeal, 18);
    sheet.setColumnWidth(_cStatus, 12);
    sheet.setColumnWidth(_cAmount, 12);
    sheet.setColumnWidth(_cCurrency, 11);
    sheet.setColumnWidth(_cPaid, 12);
    sheet.setColumnWidth(_cBalance, 14);
    sheet.setColumnWidth(_cAssigned, 16);
    sheet.setColumnWidth(_cDue, 13);

    void text(int col, int row, String v, [CellStyle? style]) {
      final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
      cell.value = TextCellValue(v);
      if (style != null) cell.cellStyle = style;
    }

    void number(int col, int row, double v) {
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row))
          .value = DoubleCellValue(double.parse(v.toStringAsFixed(2)));
    }

    for (var i = 0; i < _headers.length; i++) {
      text(i, 0, _headers[i], headerStyle);
    }

    // Per-currency totals, in the order currencies first appear.
    final totals = <String, ({double amount, double paid, double balance})>{};

    var row = 1;
    for (final inv in invoices) {
      final currency = inv.currency.trim().toUpperCase();
      // Original-currency figures (same as the invoice details sheet):
      // inv.total / inv.balanceDue are in the *preferred* currency.
      final amount = (inv.price - inv.discountAmount + inv.taxAmount)
          .clamp(0, double.infinity)
          .toDouble();
      final paid = inv.amountPaid;
      final balance = (amount - paid).clamp(0, double.infinity).toDouble();

      text(_cInvoice, row, inv.invoiceNo);
      text(_cDeal, row, inv.dealName);
      text(_cStatus, row, inv.status);
      number(_cAmount, row, amount);
      text(_cCurrency, row, currency);
      number(_cPaid, row, paid);
      number(_cBalance, row, balance);
      text(_cAssigned, row, inv.assignTo);
      text(_cDue, row, _date(inv.dueDate));

      final t = totals[currency];
      totals[currency] = (
        amount: (t?.amount ?? 0) + amount,
        paid: (t?.paid ?? 0) + paid,
        balance: (t?.balance ?? 0) + balance,
      );
      row++;
    }

    // TOTAL (USD) / TOTAL (INR) … — amounts under their own columns.
    for (final entry in totals.entries) {
      text(_cInvoice, row, 'TOTAL (${entry.key})');
      number(_cAmount, row, entry.value.amount);
      text(_cCurrency, row, entry.key);
      number(_cPaid, row, entry.value.paid);
      number(_cBalance, row, entry.value.balance);
      row++;
    }

    final bytes = excel.encode();
    if (bytes == null) {
      throw Exception('Failed to generate Excel file.');
    }

    final fileName =
        'Invoices_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}';
    final path = await _channel.invokeMethod<String>(
      'saveToDownloads',
      {
        'fileName': '$fileName.xlsx',
        'bytes': Uint8List.fromList(bytes),
        'mimeType':
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      },
    );
    debugPrint('Saved to: $path');
  }

  /// "2026-10-14T00:00:00.000Z" → "2026-10-14"; unparseable values pass
  /// through unchanged.
  static String _date(String raw) {
    final dt = DateTime.tryParse(raw.trim());
    if (dt == null) return raw;
    return DateFormat('yyyy-MM-dd').format(dt.isUtc ? dt.toLocal() : dt);
  }
}
