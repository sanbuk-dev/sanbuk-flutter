import 'package:flutter/material.dart';
import 'package:sanbuk_flutter/sanbuk_flutter.dart';

/// The smallest honest integration: initialise once, put a slot on screen,
/// and load a full-screen ad ahead of the moment you want to show it.
///
/// Replace the two codes with the ones the publisher panel gives you, under
/// the media's placements — the panel prints the exact call for each slot.
void main() {
  runApp(const ExampleApp());
}

const String mediaCode = 'YOUR-MEDIA-CODE';
const String bannerPlacement = 'YOUR-BANNER-PLACEMENT';
const String fullscreenPlacement = 'YOUR-FULLSCREEN-PLACEMENT';

class ExampleApp extends StatefulWidget {
  const ExampleApp({super.key});

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  SanbukFullscreen? _pending;
  SanbukAd? _raw;

  @override
  void initState() {
    super.initState();
    Sanbuk.init(mediaCode: mediaCode, debug: true);
    // Loaded early on purpose: the moment worth interrupting is rarely the
    // moment you have a network round trip to spare.
    SanbukFullscreen.load(fullscreenPlacement).then((ad) {
      if (mounted) setState(() => _pending = ad);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Sanbuk')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Drawn for you — SanbukAdView'),
            const SizedBox(height: 8),
            const SizedBox(
              height: 100,
              child: SanbukAdView(placementCode: bannerPlacement),
            ),
            const Divider(height: 32),
            const Text('Drawn by you — Sanbuk.loadAd'),
            const SizedBox(height: 8),
            if (_raw != null) _CustomAd(ad: _raw!),
            FilledButton(
              onPressed: () async {
                final ad = await Sanbuk.loadAd(bannerPlacement);
                if (mounted) setState(() => _raw = ad);
              },
              child: const Text('fetch as data'),
            ),
            const Divider(height: 32),
            FilledButton(
              onPressed: _pending == null ? null : () => _pending!.show(),
              child: Text(_pending == null ? 'no full-screen ad' : 'show full screen'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Drawing it yourself means two obligations the built-in view handles for
/// you: report the view only when it was really seen, and label the ad.
class _CustomAd extends StatefulWidget {
  const _CustomAd({required this.ad});

  final SanbukAd ad;

  @override
  State<_CustomAd> createState() => _CustomAdState();
}

class _CustomAdState extends State<_CustomAd> {
  @override
  void initState() {
    super.initState();
    // A real app should wait until the ad is actually on screen; this example
    // keeps it simple and says so rather than pretending otherwise.
    widget.ad.recordImpression();
  }

  @override
  Widget build(BuildContext context) {
    final ad = widget.ad;

    return InkWell(
      onTap: ad.click,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ad.disclosureLabel, style: const TextStyle(fontSize: 10)),
                  if (ad.headline != null)
                    Text(ad.headline!, style: const TextStyle(fontWeight: FontWeight.bold)),
                  if (ad.body != null) Text(ad.body!),
                ],
              ),
            ),
            Text(ad.callToAction),
          ],
        ),
      ),
    );
  }
}
