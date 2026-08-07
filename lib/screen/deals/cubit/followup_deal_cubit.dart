import 'dart:io';
import 'dart:typed_data';

import 'package:crm_app/screen/deals/cubit/followup_deals_state.dart';
import 'package:crm_app/screen/deals/modal/deal_modal.dart';
import 'package:crm_app/shareWidgets/notifcation_service.dart';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart' show debugPrint;
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

class FollowUpsTemplateCubit extends Cubit<FollowUpsTemplateState> {
  FollowUpsTemplateCubit() : super(FollowUpsTemplateInitial());

  Future<void> exportFollowUps({
    required List<Deal> deals,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    emit(FollowUpsTemplateLoading());
   const MethodChannel downloadsChannel = MethodChannel('crm/downloads');
    try {
      final excel = Excel.createExcel();
      final sheet = excel['Follow-ups'];

      if (excel.sheets.containsKey('Sheet1')) {
        excel.delete('Sheet1');
      }

      // Header Style
      final headerStyle = CellStyle(
        bold: true,
        fontFamily: getFontFamily(FontFamily.Calibri),
        fontSize: 11,
        fontColorHex: ExcelColor.white,
        backgroundColorHex: ExcelColor.blue,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
        leftBorder: Border(borderStyle: BorderStyle.Thin),
        rightBorder: Border(borderStyle: BorderStyle.Thin),
        topBorder: Border(borderStyle: BorderStyle.Thin),
        bottomBorder: Border(borderStyle: BorderStyle.Thin),
      );

      // Even Row Style
      final evenRowStyle = CellStyle(
        fontFamily: getFontFamily(FontFamily.Calibri),
        fontSize: 11,
        verticalAlign: VerticalAlign.Center,
        leftBorder: Border(borderStyle: BorderStyle.Thin),
        rightBorder: Border(borderStyle: BorderStyle.Thin),
        topBorder: Border(borderStyle: BorderStyle.Thin),
        bottomBorder: Border(borderStyle: BorderStyle.Thin),
      );

      // Odd Row Style
      final oddRowStyle = CellStyle(
        fontFamily: getFontFamily(FontFamily.Calibri),
        fontSize: 11,
        backgroundColorHex: ExcelColor.fromHexString('#F5F9FF'),
        verticalAlign: VerticalAlign.Center,
        leftBorder: Border(borderStyle: BorderStyle.Thin),
        rightBorder: Border(borderStyle: BorderStyle.Thin),
        topBorder: Border(borderStyle: BorderStyle.Thin),
        bottomBorder: Border(borderStyle: BorderStyle.Thin),
      );

      const headers = [
  'Deal',
  'Company',
  'Assigned To',
  'Follow-up Date',
  'Logged On',
  'Outcome',
  'Note',
];

      for (int col = 0; col < headers.length; col++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(
            columnIndex: col,
            rowIndex: 0,
          ),
        );

        cell.value = TextCellValue(headers[col]);
        cell.cellStyle = headerStyle;
      }

      sheet.setColumnWidth(0, 30);
      sheet.setColumnWidth(1, 25);
      sheet.setColumnWidth(2, 25);
      sheet.setColumnWidth(3, 22);
      sheet.setColumnWidth(4, 22);
      sheet.setColumnWidth(5, 18);
      sheet.setColumnWidth(6, 45);

      int row = 1;

      final formatter = DateFormat('dd/MM/yyyy hh:mm a');

      for (final deal in deals) {
  // No history available
  if (deal.followUpHistory.isEmpty) {
    final rowStyle = row.isEven ? evenRowStyle : oddRowStyle;

    final values = [
  deal.name, // Deal
  deal.companyName, // Company
  deal.assignTo, // Assigned To
  deal.followUpDate != null
      ? formatter.format(DateTime.parse(deal.followUpDate!))
      : '-', // Follow-up Date
  '-', // Logged On
  '-', // Outcome
  deal.followUpComment?.isNotEmpty == true
      ? deal.followUpComment!
      : '-', // Note
];
    for (int col = 0; col < values.length; col++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(
          columnIndex: col,
          rowIndex: row,
        ),
      );

      cell.value = TextCellValue(values[col].toString());
      cell.cellStyle = rowStyle;
    }

    row++;
    continue;
  }

  // History exists
  for (final history in deal.followUpHistory) {
    final rowStyle = row.isEven ? evenRowStyle : oddRowStyle;

    final values = [
  deal.name,
  deal.companyName,
  deal.assignTo,
  history.followUpDate != null
      ? formatter.format(history.followUpDate!)
      : (deal.followUpDate != null
            ? formatter.format(DateTime.parse(deal.followUpDate!))
            : '-'),
  history.date != null
      ? formatter.format(history.date!)
      : '-',
  history.action.isNotEmpty
      ? history.action
      : '-',
  history.comment.isNotEmpty
      ? history.comment
      : (deal.followUpComment?.isNotEmpty == true
            ? deal.followUpComment!
            : '-'),
];
   for (int col = 0; col < values.length; col++) {
  final cell = sheet.cell(
    CellIndex.indexByColumnRow(
      columnIndex: col,
      rowIndex: row,
    ),
  );

  cell.value = TextCellValue(values[col].toString());
  cell.cellStyle = rowStyle;
}

row++;
  }
}
      if (row == 1) {
        throw Exception('No follow-up records found.');
      }

      final bytes = excel.encode();

if (bytes == null) {
  throw Exception('Failed to generate Excel file.');
}

final Uint8List uint8Bytes = Uint8List.fromList(bytes);

      final fileName =
          'FollowUps_Export_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';

     if (Platform.isAndroid) {
  try {
  final path = await downloadsChannel.invokeMethod<String>(
  'saveToDownloads',
  {
    'fileName': fileName,
    'bytes': uint8Bytes,
    'mimeType':
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  },
);



emit(
  const FollowUpsTemplateSuccess(
    'Follow-ups exported to Downloads.',
  ),
);
} on PlatformException catch (e) {
  debugPrint("PlatformException: ${e.code} ${e.message}");
  emit(FollowUpsTemplateError(e.message ?? "Export failed"));
}

  return;
}

final dir = await getApplicationDocumentsDirectory();

final file = File('${dir.path}/$fileName');

await file.writeAsBytes(bytes, flush: true);

emit(
  const FollowUpsTemplateSuccess(
    'Follow-ups exported successfully.',
  ),
);

await OpenFile.open(file.path);
    } catch (e) {
      emit(
        FollowUpsTemplateError(
          e.toString(),
        ),
      );
    }
  }
}