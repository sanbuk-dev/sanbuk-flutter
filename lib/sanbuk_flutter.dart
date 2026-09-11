/// Sanbuk publisher SDK for Flutter.
///
/// A thin binding over the native SDK — deliberately. Matching, pacing,
/// frequency caps, trial periods, budgets and every publisher rule live on the
/// Sanbuk server; the viewability rule, the offline queue and the interruption
/// rules live in the native core. This package asks, draws, and reports.
///
/// A version shipped to phones is frozen for months, so any rule hardened into
/// a shell would outlive several changes of mind — and would have to be written
/// again for every other shell.
library;

import 'src/channel.dart';
import 'src/sanbuk_ad.dart';

export 'src/sanbuk_ad.dart' show SanbukAd;
export 'src/sanbuk_ad_view.dart' show SanbukAdView;

/// The publisher's entry point.
///
/// ```dart
/// await Sanbuk.init(mediaCode: 'YOUR-MEDIA-CODE');
///
/// // let us draw it
/// const SanbukAdView(placementCode: 'HOME-TOP');
///
/// // or draw it yourself
/// final ad = await Sanbuk.loadAd('HOME-TOP');
/// ```
class Sanbuk {
  const Sanbuk._();

  /// Once, at startup. Returns as soon as the native side has the code; it
  /// touches no disk on the calling thread.
  static Future<void> init({required String mediaCode, bool debug = false}) {
    return SanbukChannel.instance.init(mediaCode: mediaCode, debug: debug);
  }

  /// Ask for an ad as plain data, to draw with your own widgets.
  ///
  /// Null is a normal answer: no campaign matched, the budget is spent, the
  /// slot is capped for today. Collapse the space or draw your own content.
  ///
  /// Whoever calls this draws the ad, so the server is told as much — see
  /// [SanbukAd.recordImpression] for the obligation that comes with it.
  static Future<SanbukAd?> loadAd(String placementCode) {
    return SanbukChannel.instance.loadAd(placementCode);
  }
}

/// A full-screen ad — an interstitial, or a rewarded one somebody opted into.
///
/// Loaded first and shown later, because the moment worth interrupting is
/// rarely the moment you have a network round trip to spare: a game loads
/// between levels and shows at the end of one.
///
/// The interruption rules — nothing during a cold start, nothing back to back,
/// a ceiling per session, a close control after a few seconds — are enforced in
/// the native core, not here. They are what separates a format a publisher
/// keeps from one they remove.
class SanbukFullscreen {
  const SanbukFullscreen._(this._handle);

  final int _handle;

  /// An interstitial: shown when your app decides, gated by the rules above.
  static Future<SanbukFullscreen?> load(String placementCode) async {
    final handle = await SanbukChannel.instance
        .loadFullscreen(placementCode, rewarded: false);

    return handle == null ? null : SanbukFullscreen._(handle);
  }

  /// A rewarded ad: the person asked for it, so the interruption rules do not
  /// apply — refusing an ad somebody requested is refusing them their reward.
  /// A duration requirement applies instead, and leaving early earns nothing.
  static Future<SanbukFullscreen?> loadRewarded(String placementCode) async {
    final handle = await SanbukChannel.instance
        .loadFullscreen(placementCode, rewarded: true);

    return handle == null ? null : SanbukFullscreen._(handle);
  }

  /// Put it on screen. Silently refuses when the moment is wrong — the native
  /// side decides, and the rules are the same on every platform.
  Future<void> show() => SanbukChannel.instance.showFullscreen(_handle);
}
