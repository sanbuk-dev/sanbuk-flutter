import 'channel.dart';

/// One ad, described rather than drawn.
///
/// Sanbuk never sends markup — no HTML, no pre-rendered banner, no hidden
/// webview. The reply is a description, and what you do with it is yours: draw
/// it with your own widgets, your own fonts, your own animation, and the ad
/// looks like part of your app. That is the point of this SDK rather than an
/// incidental detail, and it is not something a network that ships a rendered
/// banner can offer you.
///
/// Two calls carry obligations rather than just behaviour:
///
/// - [recordImpression] must fire when the ad was really on screen, not when it
///   was created. Reporting on build counts ads nobody scrolled to. Under
///   [SanbukAdView] that judgement is made for you against the MRC bar; here it
///   is yours, and it cannot be verified from the server.
/// - the «آگهی» label in [disclosureLabel] has to appear somewhere on the ad.
///   Store policy asks for it, advertisers expect it, and a reader deserves to
///   know which part of your screen was paid for.
class SanbukAd {
  SanbukAd._({
    required this.id,
    required this.format,
    required this.campaignId,
    required this.headline,
    required this.body,
    required this.callToAction,
    required this.imageUrl,
    required this.logoUrl,
    required this.brandColor,
  });

  /// Opaque handle the native side uses to find this ad again.
  final int id;

  /// banner | native | interstitial | rewarded — chosen by the publisher when
  /// the slot was registered, never by your code.
  final String format;
  final String campaignId;

  final String? headline;
  final String? body;
  final String callToAction;
  final String? imageUrl;
  final String? logoUrl;

  /// The advertiser's own colour as 0xAARRGGBB, when they chose one.
  final int? brandColor;

  /// The word that has to appear on any ad your own widgets draw.
  String get disclosureLabel => 'آگهی';

  bool _impressionRecorded = false;

  /// Report that this ad was seen. Safe to call more than once — the second
  /// call does nothing, and a retry from the offline queue is recognised by the
  /// server rather than counted again.
  Future<void> recordImpression() async {
    if (_impressionRecorded) return;
    _impressionRecorded = true;
    await SanbukChannel.instance.recordImpression(id);
  }

  /// Open the destination. Always through the tracker and always in a real
  /// browser: an in-app webview has its own cookie jar, so the first-party
  /// click id does not survive it and the conversion is never attributed — the
  /// publisher does the work and earns nothing.
  Future<void> click() => SanbukChannel.instance.click(id);

  static SanbukAd? fromMap(Map<Object?, Object?>? map) {
    if (map == null) return null;
    final id = map['id'];
    if (id is! int) return null;

    return SanbukAd._(
      id: id,
      format: map['format'] as String? ?? 'banner',
      campaignId: map['campaignId'] as String? ?? '',
      headline: map['headline'] as String?,
      body: map['body'] as String?,
      callToAction: map['callToAction'] as String? ?? '',
      imageUrl: map['imageUrl'] as String?,
      logoUrl: map['logoUrl'] as String?,
      brandColor: map['brandColor'] as int?,
    );
  }
}
