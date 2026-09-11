// The one test that needs a real device.
//
// Everything in ../../test runs against a fake channel: it proves this package
// sends the right calls and reads the answers correctly, but a fake answers
// whatever it is told to. It cannot catch a method name the Kotlin side spells
// differently, a plugin that was never registered, or an answer built in a
// shape the standard codec refuses to carry — and each of those is silent until
// a publisher runs the app.
//
//   flutter test integration_test --device-id <a real device or emulator>
//
// Deliberately independent of whether an ad is available: no campaign, no
// network and a wrong media code all produce the same null, which is the
// contract. What is under test is the wire, not the inventory.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sanbuk_flutter/sanbuk_flutter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('init reaches the native side', (tester) async {
    // Throwing here means the plugin was not registered — the failure a
    // publisher would otherwise meet as a MissingPluginException on their
    // first run.
    await Sanbuk.init(mediaCode: 'INTEGRATION-TEST', debug: true);
  });

  testWidgets('an ad that does not exist is a null, not a throw',
      (tester) async {
    await Sanbuk.init(mediaCode: 'INTEGRATION-TEST', debug: true);

    // An empty box is the worst an advertisement may cost a publisher's app,
    // so no path through the native side may raise into their code.
    expect(await Sanbuk.loadAd('NO-SUCH-PLACEMENT'), isNull);
  });

  testWidgets('a full-screen ad that does not exist is a null handle',
      (tester) async {
    await Sanbuk.init(mediaCode: 'INTEGRATION-TEST', debug: true);

    expect(await SanbukFullscreen.load('NO-SUCH-PLACEMENT'), isNull);
    expect(await SanbukFullscreen.loadRewarded('NO-SUCH-PLACEMENT'), isNull);
  });
}
