import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medivoice/app/app.dart';

import '../fakes.dart';

void main() {
  testWidgets('synthetic demo reaches review without camera or Gemini', (
    tester,
  ) async {
    final controller = buildTestController(demoMode: true);
    addTearDown(controller.dispose);

    await tester.pumpWidget(MediVoiceApp(controller: controller));
    await tester.tap(find.text('Try synthetic demo'));
    await tester.pumpAndSettle();

    expect(find.text('Check before continuing'), findsOneWidget);
    expect(
      find.textContaining('deterministic mock extraction'),
      findsOneWidget,
    );

    final confirm = find.text('Confirm and continue');
    await tester.scrollUntilVisible(
      confirm,
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(confirm);
    await tester.pumpAndSettle();

    expect(find.text('Verified result'), findsOneWidget);
    expect(find.textContaining('Paracetamol'), findsWidgets);
    expect(find.textContaining('not Gemini'), findsOneWidget);
  });

  testWidgets('synthetic scan reaches the verified result', (tester) async {
    final directory = await tester.runAsync(
      () => Directory.systemTemp.createTemp('medivoice_widget_'),
    );
    if (directory == null) throw StateError('Could not create test directory.');
    addTearDown(() => directory.deleteSync(recursive: true));
    final image = File('${directory.path}/sample.png');
    await tester.runAsync(
      () => image.writeAsBytes(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
        ),
      ),
    );
    final controller = buildTestController(imagePath: image.path);
    addTearDown(controller.dispose);

    await tester.pumpWidget(MediVoiceApp(controller: controller));
    await tester.tap(find.text('Scan prescription'));
    await tester.pumpAndSettle();
    expect(find.text('Use this image'), findsOneWidget);

    await tester.tap(find.text('Use this image'));
    await tester.pumpAndSettle();
    expect(find.text('Check before continuing'), findsOneWidget);

    final confirm = find.text('Confirm and continue');
    await tester.scrollUntilVisible(
      confirm,
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(confirm);
    await tester.pumpAndSettle();

    expect(find.text('Verified result'), findsOneWidget);
    expect(find.textContaining('Paracetamol'), findsWidgets);
    final playAudio = find.text('Play audio');
    await tester.scrollUntilVisible(
      playAudio,
      500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(playAudio, findsOneWidget);
  });
}
