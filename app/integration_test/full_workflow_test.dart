import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:medivoice/app/app.dart';

import '../test/fakes.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('synthetic prescription reaches verified result', (tester) async {
    final directory = await Directory.systemTemp.createTemp('medivoice_test_');
    addTearDown(() => directory.delete(recursive: true));
    final image = File('${directory.path}/sample.png');
    await image.writeAsBytes(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
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
