import 'dart:io';
import 'dart:ui' as ui;

import 'package:crm_app/screen/message/ui/message_screen.dart';
import 'package:crm_app/thems/app_themes.dart' show AppTheme;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _capture(
    WidgetTester tester, Size size, String outPath) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final boundaryKey = GlobalKey();
  await tester.pumpWidget(RepaintBoundary(
    key: boundaryKey,
    child: MaterialApp(
      theme: AppTheme.theme,
      debugShowCheckedModeBanner: false,
      home: const MessagesScreen(),
    ),
  ));
  await tester.pumpAndSettle();

  final boundary =
      boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 1.0);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  await File(outPath).writeAsBytes(bytes!.buffer.asUint8List());
}

void main() {
  testWidgets('preview wide layout', (tester) async {
    await _capture(tester, const Size(1280, 800),
        'C:/crm_saas/.preview_wide.png');
  });

  testWidgets('preview narrow layout', (tester) async {
    await _capture(tester, const Size(420, 900),
        'C:/crm_saas/.preview_narrow.png');
  });
}
