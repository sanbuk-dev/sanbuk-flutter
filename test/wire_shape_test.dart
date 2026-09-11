// The seam neither other suite can see.
//
// channel_test.dart drives a fake channel, so it proves this package's logic
// against whatever the fake was told to answer. The Kotlin side is never
// consulted. So if the two halves stop agreeing on a spelling — Dart sends
// `loadAd`, Kotlin waits for `load` — both suites stay green and a publisher
// meets the failure at runtime.
//
// The map is worse than the method names, because there is no failure at all:
// every key Dart cannot find falls back to '' or null, so a renamed key shows
// an ad with a blank button instead of raising anything. This exact shape of
// bug has been shipped on this project twice across the PHP/Go boundary, both
// times with green tests on both sides.
//
// Reading source text is a blunt instrument, and it is here because the precise
// one — building the plugin and calling it — needs a device. Those live in
// example/integration_test. This runs everywhere, including CI without an
// emulator, which is where drift is cheapest to catch.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final plugin = File(
    'android/src/main/kotlin/ir/sanbuk/sanbuk_flutter/SanbukFlutterPlugin.kt',
  ).readAsStringSync();

  test('every method Dart calls is one Kotlin answers', () {
    final source = File('lib/src/channel.dart').readAsStringSync();

    // invokeMethod, invokeMapMethod, invokeListMethod — a name matched by only
    // some of those is how this test first passed while `loadAd` went unread.
    final dart = RegExp(r"""invoke\w*Method<[^>]*>\('([^']+)'""")
        .allMatches(source)
        .map((m) => m.group(1)!)
        .toSet();

    // The regex has to have seen every call, not most of them: a silent miss
    // here is a method this test stops guarding, with nothing to show for it.
    expect(
      dart.length,
      'channel.invoke'.allMatches(source).length,
      reason: 'the regex missed a call shape used in channel.dart',
    );

    // The arms of `when (call.method)`, which is the only place Kotlin decides
    // what it understands; anything else answers notImplemented().
    final kotlin = RegExp(r'"(\w+)" ->')
        .allMatches(plugin)
        .map((m) => m.group(1)!)
        .toSet();

    expect(
      dart.difference(kotlin),
      isEmpty,
      reason: 'Dart calls a method the Android side does not handle',
    );
  });

  test('every key Dart reads off an ad is one Kotlin writes', () {
    // Kotlin's describe(): the flat shape the standard codec can carry.
    final kotlin = RegExp(r'"(\w+)" to ')
        .allMatches(plugin)
        .map((m) => m.group(1)!)
        .toSet();

    final dart = RegExp(r"""map\['(\w+)'\]""")
        .allMatches(File('lib/src/sanbuk_ad.dart').readAsStringSync())
        .map((m) => m.group(1)!)
        .toSet();

    expect(dart, isNotEmpty, reason: 'the regex stopped matching, not a pass');
    expect(
      dart.difference(kotlin),
      isEmpty,
      reason: 'Dart reads a key the Android side never sends — it would be '
          'blank on screen, with no error anywhere',
    );
  });

  test('the platform view type is spelled the same on both sides', () {
    final dart = RegExp(r"""_viewType = '([^']+)'""")
        .firstMatch(File('lib/src/sanbuk_ad_view.dart').readAsStringSync())
        ?.group(1);

    expect(dart, isNotNull, reason: 'the regex stopped matching, not a pass');
    expect(
      plugin.contains('VIEW_TYPE = "$dart"'),
      isTrue,
      reason: 'a mismatch here is an empty box where the ad should be',
    );
  });

  test('the channel name is spelled the same on both sides', () {
    final dart = RegExp(r"""MethodChannel\('([^']+)'\)""")
        .firstMatch(File('lib/src/channel.dart').readAsStringSync())
        ?.group(1);

    expect(dart, isNotNull, reason: 'the regex stopped matching, not a pass');
    expect(plugin.contains('CHANNEL = "$dart"'), isTrue);
  });
}
