import 'package:flutter/services.dart';

import 'sanbuk_ad.dart';

/// The one wire between Dart and the native SDK.
///
/// Every call here is a pass-through. No decision, no caching, no retry, no
/// viewability rule — all of that lives in the native core, where it is written
/// once and shared by every shell. A rule that lived here would have to be
/// written again for Unity and React Native, and the copies would drift,
/// because the shells ship at different speeds.
class SanbukChannel {
  SanbukChannel._();

  static SanbukChannel instance = SanbukChannel._();

  /// Visible for testing: lets a test stand in for the native side.
  static const MethodChannel channel = MethodChannel('ir.sanbuk/sdk');

  Future<void> init({required String mediaCode, bool debug = false}) {
    return channel.invokeMethod<void>('init', {
      'mediaCode': mediaCode,
      'debug': debug,
    });
  }

  Future<SanbukAd?> loadAd(String placementCode) async {
    final map = await channel.invokeMapMethod<Object?, Object?>('loadAd', {
      'placementCode': placementCode,
    });

    return SanbukAd.fromMap(map);
  }

  Future<void> recordImpression(int adId) {
    return channel.invokeMethod<void>('recordImpression', {'adId': adId});
  }

  Future<void> click(int adId) {
    return channel.invokeMethod<void>('click', {'adId': adId});
  }

  Future<int?> loadFullscreen(String placementCode, {required bool rewarded}) {
    return channel.invokeMethod<int>('loadFullscreen', {
      'placementCode': placementCode,
      'rewarded': rewarded,
    });
  }

  Future<void> showFullscreen(int handle) {
    return channel.invokeMethod<void>('showFullscreen', {'handle': handle});
  }
}
