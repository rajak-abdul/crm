import 'dart:typed_data';

import 'package:crm_app/screen/invoice/modal/invoice_model.dart';
import 'package:excel/excel.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';


class InvoiceExcelExporter {
  InvoiceExcelExporter._();

  static Future<void> export(List<Invoice> invoices) async {
    final excel = Excel.createExcel();

    final String sheetName = 'Invoices';

    if (excel.tables.containsKey('Sheet1')) {
      excel.rename('Sheet1', sheetName);
    }
    const MethodChannel _channel = MethodChannel('crm/downloads');
    final Sheet sheet = excel[sheetName];

    // -----------------------------------------------------------------
    // Header Style
    // -----------------------------------------------------------------

    final CellStyle headerStyle = CellStyle(
      bold: true,
      fontColorHex: ExcelColor.white,
      backgroundColorHex: ExcelColor.blue,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    final CellStyle totalStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.grey200,
    );

    final CellStyle amountStyle = CellStyle(
      horizontalAlign: HorizontalAlign.Right,
    );

    // -----------------------------------------------------------------
    // Column Widths
    // -----------------------------------------------------------------

    sheet.setColumnWidth(0, 22); // Invoice Number
sheet.setColumnWidth(1, 30); // Deal Name
sheet.setColumnWidth(2, 24); // Sales Person
sheet.setColumnWidth(3, 18); // Status
sheet.setColumnWidth(4, 14); // Currency
sheet.setColumnWidth(5, 18); // Invoice Amount
sheet.setColumnWidth(6, 18); // Amount Paid
sheet.setColumnWidth(7, 20); // Outstanding Amount
sheet.setColumnWidth(8, 20); // Payment Due Date

    // -----------------------------------------------------------------
    // Header Row
    // -----------------------------------------------------------------

    final headers = <String>[
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

    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(
          columnIndex: i,
          rowIndex: 0,
        ),
      );

      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
    }

    double totalInvoiceAmount = 0;
    double totalPaidAmount = 0;
    double totalBalanceAmount = 0;

    final currencyFormatter = NumberFormat('#,##0.00');
  
      // -----------------------------------------------------------------
    // Invoice Rows
    // -----------------------------------------------------------------

    int row = 1;

    for (final invoice in invoices) {
      totalInvoiceAmount += invoice.total;
      totalPaidAmount += invoice.amountPaid;
      totalBalanceAmount += invoice.balanceDue;

      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
          .value = TextCellValue(invoice.invoiceNo);

      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
          .value = TextCellValue(invoice.dealName);

      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: row))
          .value = TextCellValue(invoice.assignTo);

      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row))
          .value = TextCellValue(invoice.status);

      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row))
          .value = TextCellValue(invoice.currency);

      final amountCell = sheet.cell(
        CellIndex.indexByColumnRow(
          columnIndex: 3,
          rowIndex: row,
        ),
      );

      amountCell.value =
          DoubleCellValue(double.parse(invoice.total.toStringAsFixed(2)));
      amountCell.cellStyle = amountStyle;

      final paidCell = sheet.cell(
        CellIndex.indexByColumnRow(
          columnIndex: 5,
          rowIndex: row,
        ),
      );

      paidCell.value = DoubleCellValue(
        double.parse(invoice.amountPaid.toStringAsFixed(2)),
      );
      paidCell.cellStyle = amountStyle;

      final balanceCell = sheet.cell(
        CellIndex.indexByColumnRow(
          columnIndex: 6,
          rowIndex: row,
        ),
      );

      balanceCell.value = DoubleCellValue(
        double.parse(invoice.balanceDue.toStringAsFixed(2)),
      );
      balanceCell.cellStyle = amountStyle;

      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: row))
          .value = TextCellValue(invoice.dueDate);

      row++;
    }

    // -----------------------------------------------------------------
    // Total Row
    // -----------------------------------------------------------------

    final totalRow = row;

    final titleCell = sheet.cell(
      CellIndex.indexByColumnRow(
        columnIndex: 0,
        rowIndex: totalRow,
      ),
    );

    titleCell.value =  TextCellValue("TOTAL");
    titleCell.cellStyle = totalStyle;

    for (int i = 1; i <= 4; i++) {
      sheet.cell(
        CellIndex.indexByColumnRow(
          columnIndex: i,
          rowIndex: totalRow,
        ),
      ).cellStyle = totalStyle;
    }

    final totalInvoiceCell = sheet.cell(
      CellIndex.indexByColumnRow(
        columnIndex: 5,
        rowIndex: totalRow,
      ),
    );

    totalInvoiceCell.value = DoubleCellValue(
      double.parse(totalInvoiceAmount.toStringAsFixed(2)),
    );
    totalInvoiceCell.cellStyle = totalStyle;

    final totalPaidCell = sheet.cell(
      CellIndex.indexByColumnRow(
        columnIndex: 6,
        rowIndex: totalRow,
      ),
    );

    totalPaidCell.value = DoubleCellValue(
      double.parse(totalPaidAmount.toStringAsFixed(2)),
    );
    totalPaidCell.cellStyle = totalStyle;

    final totalBalanceCell = sheet.cell(
      CellIndex.indexByColumnRow(
        columnIndex: 7,
        rowIndex: totalRow,
      ),
    );

    totalBalanceCell.value = DoubleCellValue(
      double.parse(totalBalanceAmount.toStringAsFixed(2)),
    );
    totalBalanceCell.cellStyle = totalStyle;

    // -----------------------------------------------------------------
    // Save Excel File
    // -----------------------------------------------------------------

    final List<int>? bytes = excel.encode();

    if (bytes == null) {
      throw Exception('Failed to generate Excel file.');
    }

    final Uint8List data = Uint8List.fromList(bytes);

    final fileName =
        'Invoices_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}';
    final path = await _channel.invokeMethod<String>(
  'saveToDownloads',
  {
    'fileName': '$fileName.xlsx',
    'bytes': data,
    'mimeType':
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  },
);

debugPrint('Saved to: $path');
  }
}