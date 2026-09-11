import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanbuk_flutter/sanbuk_flutter.dart';
import 'package:sanbuk_flutter/src/channel.dart';

/// The wire between Dart and the native SDK.
///
/// These tests exist because the shell has no logic of its own to test: what
/// can go wrong here is the contract — a renamed key, a dropped argument, a
/// null handled as if it were data. Each of those fails silently at runtime on
/// a device and looks like "the ad just doesn't show".
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final calls = <MethodCall>[];
  Object? reply;

  setUp(() {
    calls.clear();
    reply = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SanbukChannel.channel, (call) async {
      calls.add(call);

      return reply;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SanbukChannel.channel, null);
  });

  test('init carries the media code the panel issued', () async {
    await Sanbuk.init(mediaCode: 'MED-123');

    expect(calls.single.method, 'init');
    expect(calls.single.arguments, {'mediaCode': 'MED-123', 'debug': false});
  });

  test('an ad comes back as data, never as markup', () async {
    reply = {
      'id': 7,
      'format': 'native',
      'campaignId': 'cmp-1',
      'headline': 'تخفیف پاییزه',
      'body': 'تا ۵۰ درصد',
      'callToAction': 'خرید',
      'imageUrl': 'https://cdn/i.png',
      'logoUrl': null,
      'brandColor': 0xFF060ADB,
    };

    final ad = await Sanbuk.loadAd('HOME-TOP');

    expect(calls.single.arguments, {'placementCode': 'HOME-TOP'});
    expect(ad, isNotNull);
    expect(ad!.headline, 'تخفیف پاییزه');
    expect(ad.format, 'native');
    expect(ad.brandColor, 0xFF060ADB);
    expect(ad.logoUrl, isNull);
  });

  /// An empty slot is a normal answer, not a failure — the most common mistake
  /// an integrator makes is treating it as an error and showing one.
  test('an empty slot is a null ad, not a throw', () async {
    reply = null;

    expect(await Sanbuk.loadAd('HOME-TOP'), isNull);
  });

  test('an ad without an id is not usable', () async {
    reply = {'format': 'banner'};

    expect(await Sanbuk.loadAd('HOME-TOP'), isNull);
  });

  /// The count has no event identity of its own on the server, so a second
  /// report is a second view — and a per-impression commission is paid on that
  /// number.
  test('one drawn ad reports at most one impression', () async {
    reply = {'id': 7, 'format': 'banner', 'campaignId': 'c', 'callToAction': 'x'};
    final ad = (await Sanbuk.loadAd('HOME-TOP'))!;
    calls.clear();

    await ad.recordImpression();
    await ad.recordImpression();
    await ad.recordImpression();

    expect(calls, hasLength(1));
    expect(calls.single.method, 'recordImpression');
    expect(calls.single.arguments, {'adId': 7});
  });

  test('a click is routed by the native side, never opened here', () async {
    reply = {'id': 7, 'format': 'banner', 'campaignId': 'c', 'callToAction': 'x'};
    final ad = (await Sanbuk.loadAd('HOME-TOP'))!;
    calls.clear();

    await ad.click();

    expect(calls.single.method, 'click');
    expect(calls.single.arguments, {'adId': 7});
  });

  test('the disclosure is not optional and not ours to translate', () async {
    reply = {'id': 7, 'format': 'banner', 'campaignId': 'c', 'callToAction': 'x'};

    expect((await Sanbuk.loadAd('HOME-TOP'))!.disclosureLabel, 'آگهی');
  });

  group('full screen', () {
    test('an interstitial says it is not rewarded', () async {
      reply = 42;

      final ad = await SanbukFullscreen.load('LEVEL-END');

      expect(ad, isNotNull);
      expect(calls.single.arguments,
          {'placementCode': 'LEVEL-END', 'rewarded': false});
    });

    /// Refusing an ad somebody asked for is refusing them their reward, so the
    /// two paths are distinct all the way down to the native core.
    test('a rewarded ad says so, because its rules differ', () async {
      reply = 42;

      await SanbukFullscreen.loadRewarded('EXTRA-LIFE');

      expect(calls.single.arguments,
          {'placementCode': 'EXTRA-LIFE', 'rewarded': true});
    });

    test('nothing to show is a null handle, not a throw', () async {
      reply = null;

      expect(await SanbukFullscreen.load('LEVEL-END'), isNull);
    });

    test('showing passes the handle the native side gave us', () async {
      reply = 42;
      final ad = (await SanbukFullscreen.load('LEVEL-END'))!;
      calls.clear();
      reply = null;

      await ad.show();

      expect(calls.single.method, 'showFullscreen');
      expect(calls.single.arguments, {'handle': 42});
    });
  });
}
