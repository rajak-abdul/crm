import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crm_app/screen/deals/cubit/deals_cubit.dart';
import 'package:crm_app/screen/deals/cubit/deals_sheet_state.dart';
import 'package:dio/dio.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart' hide BorderStyle, Border;
import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

// Same channel Lead's export uses — the native Android side already
// inserts into the public Downloads collection via MediaStore, which
// getApplicationDocumentsDirectory() (the app's private sandbox) can't
// do.
final MethodChannel _dealsDownloadsChannel = MethodChannel('crm/downloads');

Future<String> _saveXlsxToDownloads(String fileName, List<int> bytes) async {
  if (Platform.isAndroid) {
    final path = await _dealsDownloadsChannel.invokeMethod<String>(
      'saveToDownloads',
      <String, dynamic>{
        'fileName': fileName,
        'bytes': Uint8List.fromList(bytes),
        'mimeType':
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      },
    );
    return path ?? '';
  }
  return FileSaver.instance.saveFile(
    name: fileName.replaceAll('.xlsx', ''),
    bytes: Uint8List.fromList(bytes),
    ext: 'xlsx',
    mimeType: MimeType.microsoftExcel,
  );
}

class DealsTemplateCubit extends Cubit<DealsTemplateState> {
  final DealsCubit dealsCubit;

  DealsTemplateCubit(this.dealsCubit)
      : super(DealsTemplateInitial());

  // ===============================
  // Download Excel Template
  // ===============================
  Future<void> downloadTemplate() async {
    emit(DealsTemplateLoading());

    try {
      final excel = Excel.createExcel();

      excel.rename('Sheet1', 'Deals Template');

      final Sheet sheet = excel['Deals Template'];

      final headers = [
        "Deal Name",
        "Company Name",
        "Phone Number",
        "Deal Title",
        "Assigned To (Email)",
        "Value",
        "Currency",
        "Client Type (B2B/B2C)",
        "Discount Given (%)",
        "Stage",
        "Email",
        "Source",
        "Company Size",
        "Industry",
        "Requirement",
        "Address",
        "Country",
        "Notes",
        "Follow Up Date (YYYY-MM-DD)",
        "Follow Up Comment",
      ];

      final headerStyle = CellStyle(
  fontFamily: getFontFamily(FontFamily.Calibri),
  fontSize: 11,
  bold: true,
  fontColorHex: ExcelColor.white,
  backgroundColorHex: ExcelColor.blue,
  horizontalAlign: HorizontalAlign.Center,
  verticalAlign: VerticalAlign.Center,
  textWrapping: TextWrapping.WrapText,

  leftBorder: Border(
    borderStyle: BorderStyle.Thin,
    borderColorHex: ExcelColor.grey,
  ),
  rightBorder: Border(
    borderStyle: BorderStyle.Thin,
    borderColorHex: ExcelColor.grey,
  ),
  topBorder: Border(
    borderStyle: BorderStyle.Thin,
    borderColorHex: ExcelColor.grey,
  ),
  bottomBorder: Border(
    borderStyle: BorderStyle.Thin,
    borderColorHex: ExcelColor.grey,
  ),
);

      for (int i = 0; i < headers.length; i++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(
            columnIndex: i,
            rowIndex: 0,
          ),
        );

        cell.value = TextCellValue(headers[i]);
        cell.cellStyle = headerStyle;

        sheet.setColumnWidth(i, 28);
      }

      final bytes = excel.encode();

      if (bytes == null) {
        emit(const DealsTemplateError(
          "Failed to generate template.",
        ));
        return;
      }

      await _saveXlsxToDownloads('Deals_Template.xlsx', bytes);

      emit(
        const DealsTemplateSuccess(
          "Deals template downloaded successfully.",
        ),
      );
    } catch (e) {
      emit(
        DealsTemplateError(e.toString()),
      );
    }
  }

// ===============================
// Export deals
// ===============================

// ISO date string → "yyyy-MM-dd" (local); raw value if it can't be parsed.
String _formatYmd(dynamic raw) {
  final s = raw?.toString() ?? '';
  final d = DateTime.tryParse(s);
  return d == null ? s : DateFormat('yyyy-MM-dd').format(d.toLocal());
}




Future<void> exportDeals({
  DateTime? startDate,
  DateTime? endDate,
}) async {
  emit(DealsTemplateLoading());

  try {
    final deals = await dealsCubit.exportDeals(
      startDate: startDate,
      endDate: endDate,
    );

    final excel = Excel.createExcel();

    excel.rename('Sheet1', 'Deals Export');

    final Sheet sheet = excel['Deals Export'];

    final headers = [
      "Deal Name",
      "Company Name",
      "Phone Number",
      "Deal Title",
      "Assigned To (Email)",
      "Value",
      "Currency",
      "Client Type (B2B/B2C)",
      "Discount Given (%)",
      "Stage",
      "Email",
      "Source",
      "Company Size",
      "Industry",
      "Requirement",
      "Address",
      "Country",
      "Notes",
      "Follow Up Date (YYYY-MM-DD)",
      "Follow Up Comment",
      "Created At",
    ];

    final headerStyle = CellStyle(
      fontFamily: getFontFamily(FontFamily.Calibri),
      fontSize: 11,
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      backgroundColorHex: ExcelColor.blue50,
    );

    final dataStyle = CellStyle(
  fontFamily: getFontFamily(FontFamily.Calibri),
  fontSize: 11,
  horizontalAlign: HorizontalAlign.Left,
  verticalAlign: VerticalAlign.Center,

  leftBorder: Border(
    borderStyle: BorderStyle.Thin,
    borderColorHex: ExcelColor.grey,
  ),
  rightBorder: Border(
    borderStyle: BorderStyle.Thin,
    borderColorHex: ExcelColor.grey,
  ),
  topBorder: Border(
    borderStyle: BorderStyle.Thin,
    borderColorHex: ExcelColor.grey,
  ),
  bottomBorder: Border(
    borderStyle: BorderStyle.Thin,
    borderColorHex: ExcelColor.grey,
  ),
);

    // ==========================
    // Write Headers
    // ==========================

    for (int col = 0; col < headers.length; col++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(
          columnIndex: col,
          rowIndex: 0,
        ),
      );

      cell.value = TextCellValue(headers[col]);
      cell.cellStyle = headerStyle;
      sheet.setColumnWidth(0, 30); // Deal Name
sheet.setColumnWidth(1, 30); // Company
sheet.setColumnWidth(2, 18); // Phone
sheet.setColumnWidth(3, 25); // Deal Title
sheet.setColumnWidth(4, 35); // Assigned To
sheet.setColumnWidth(5, 15); // Value
sheet.setColumnWidth(6, 12); // Currency
sheet.setColumnWidth(7, 18); // Client Type
sheet.setColumnWidth(8, 15); // Discount
sheet.setColumnWidth(9, 25); // Stage
sheet.setColumnWidth(10, 35); // Email
sheet.setColumnWidth(11, 18); // Source
sheet.setColumnWidth(12, 18); // Company Size
sheet.setColumnWidth(13, 20); // Industry
sheet.setColumnWidth(14, 35); // Requirement
sheet.setColumnWidth(15, 30); // Address
sheet.setColumnWidth(16, 18); // Country
sheet.setColumnWidth(17, 40); // Notes
sheet.setColumnWidth(18, 26); // Follow Up Date
sheet.setColumnWidth(19, 35); // Follow Up Comment
sheet.setColumnWidth(20, 18); // Created At
    }

    // ==========================
    // Write Data
    // ==========================

    for (int row = 0; row < deals.length; row++) {
      final deal = deals[row];

      final values = [
        deal['dealName'],
        deal['companyName'],
        deal['phoneNumber'],
        deal['dealTitle'],
        deal['assignedTo'],
        deal['value'],
        deal['currency'],
        deal['clientType'],
        deal['discountGiven'],
        deal['stage'],
        deal['email'],
        deal['source'],
        deal['companySize'],
        deal['industry'],
        deal['requirement'],
        deal['address'],
        deal['country'],
        deal['notes'],
        _formatYmd(deal['followUpDate']),
        deal['followUpComment'],
        deal['createdAt'],
      ];

      for (int col = 0; col < values.length; col++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(
            columnIndex: col,
            rowIndex: row + 1,
          ),
        );

        cell.value = TextCellValue(
          values[col]?.toString() ?? '',
        );

        final rowStyle = CellStyle(
  fontFamily: getFontFamily(FontFamily.Calibri),
  fontSize: 11,
  horizontalAlign: HorizontalAlign.Left,
  verticalAlign: VerticalAlign.Center,
  backgroundColorHex:
      row.isEven ? ExcelColor.white : ExcelColor.grey50,

  leftBorder: Border(
    borderStyle: BorderStyle.Thin,
    borderColorHex: ExcelColor.grey,
  ),
  rightBorder: Border(
    borderStyle: BorderStyle.Thin,
    borderColorHex: ExcelColor.grey,
  ),
  topBorder: Border(
    borderStyle: BorderStyle.Thin,
    borderColorHex: ExcelColor.grey,
  ),
  bottomBorder: Border(
    borderStyle: BorderStyle.Thin,
    borderColorHex: ExcelColor.grey,
  ),
);

cell.cellStyle = rowStyle;
      }
    }

    // ==========================
    // Save Excel
    // ==========================

    final bytes = excel.encode();

    if (bytes == null) {
      emit(const DealsTemplateError(
        "Failed to generate export.",
      ));
      return;
    }

    final fileName =
        "Deals_Export_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx";

    await _saveXlsxToDownloads(fileName, bytes);

    emit(
      DealsTemplateSuccess(
        "Successfully exported ${deals.length} deal(s).",
      ),
    );
  } catch (e) {
    emit(
      DealsTemplateError(
        e.toString(),
      ),
    );
  }
}  // ===============================
  // Import Excel
  // ===============================
  Future<void> pickAndImportTemplate() async {
    emit(DealsTemplateLoading());

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        allowMultiple: false,
      );

      if (result == null) {
        emit(
          const DealsTemplateError(
            "No file selected.",
          ),
        );
        return;
      }

      final file = result.files.single;

      final importResult =
          await dealsCubit.bulkImportDeals(file);

      if (importResult == null) {
        emit(
          const DealsTemplateError(
            "Import failed.",
          ),
        );
        return;
      }

      if (importResult.success) {
        String message =
            "Imported ${importResult.created} deal(s) successfully.";

        if (importResult.hasFailures) {
          message +=
              "\n${importResult.failed} row(s) failed.";

          if (importResult.errors.isNotEmpty) {
            message +=
                "\n\n${importResult.errors.join('\n')}";
          }
        }

        emit(
          DealsTemplateSuccess(message),
        );
      } else {
        emit(
          DealsTemplateError(
            importResult.errors.isNotEmpty
                ? importResult.errors.join('\n')
                : "Import failed.",
          ),
        );
      }
    } catch (e) {
      emit(
        DealsTemplateError(
          e.toString(),
        ),
      );
    }
  }
}