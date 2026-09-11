import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// The ad, drawn for you.
///
/// Exists so a publisher can see revenue before spending an afternoon on UI —
/// not because drawing it yourself is the lesser path. It hosts the native
/// view, which renders the same data [SanbukAd] hands you and does the three
/// things you would otherwise have to remember:
///
/// - the impression is reported only once at least half the ad has been on
///   screen for a continuous second, so the number an advertiser pays against
///   is one a person could actually have seen;
/// - the «آگهی» label is always drawn;
/// - the click opens a real browser, which is what keeps attribution — and your
///   revenue — intact.
///
/// Give it a size. The native renderer adapts to the box you provide, and a
/// zero-height box draws nothing.
class SanbukAdView extends StatelessWidget {
  const SanbukAdView({
    super.key,
    required this.placementCode,
    this.onEmpty,
  });

  /// The slot code from the publisher panel.
  final String placementCode;

  /// Called when nothing came back. An empty slot is a normal answer, not a
  /// failure — collapse the space or draw your own content, but never treat it
  /// as an error.
  final VoidCallback? onEmpty;

  static const String _viewType = 'ir.sanbuk/adView';

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.android) {
      // iOS has a core but no UI layer yet, and pretending otherwise would put
      // an empty box in someone's app with no explanation.
      return const SizedBox.shrink();
    }

    return AndroidView(
      viewType: _viewType,
      creationParams: {'placementCode': placementCode},
      creationParamsCodec: const StandardMessageCodec(),
      // The ad is one click target and the native side owns the gesture; without
      // this, a scrollable parent swallows the tap.
      gestureRecognizers: const {
        Factory<OneSequenceGestureRecognizer>(TapGestureRecognizer.new),
      },
    );
  }
}
