# Sanbuk Flutter SDK

Official Flutter plugin for [Sanbuk](https://sanbuk.com) — publisher ad serving in the CPA model.

**[راهنمای فارسی →](README.fa.md)**

> **Status: first preview — Android only.** Banner, native, interstitial and rewarded all work, drawn by the native Android SDK. iOS lands when that SDK grows its renderer; the platform is not declared until it does, because a platform declared before it works is a crash on somebody's iPhone.

## Installing

```yaml
dependencies:
  sanbuk_flutter:
    git: https://github.com/sanbuk-dev/sanbuk-flutter.git
```

Then one line in `android/build.gradle.kts`, inside `allprojects { repositories { … } }`:

```kotlin
maven { url = uri("${rootDir}/../../android/repo") }   // path to the plugin's repo folder
```

That line exists because an app resolves its own dependencies: the native SDK travels inside
this plugin as a one-artifact Maven repository, and Gradle will not look there unless your app
names it. It goes away the day `ir.sanbuk:sdk-android` is published to a public repository —
nothing else about your integration changes when it does.

If your project keeps its repositories in `settings.gradle.kts` under
`dependencyResolutionManagement` instead, add the same line there.

## Using it

```dart
// once, at startup
await Sanbuk.init(mediaCode: 'YOUR-MEDIA-CODE');
```

**Let us draw it** — a widget that fetches, renders, counts the view and routes the click:

```dart
const SanbukAdView(placementCode: 'HOME-TOP')
```

**Draw it yourself** — the same ad as data, styled by your own widgets:

```dart
final ad = await Sanbuk.loadAd('HOME-TOP');   // headline, image, cta, colours
if (ad == null) return const SizedBox.shrink();

// ...render it with your own widgets...
ad.recordImpression();   // when it is really on screen
// ...and on tap:
ad.click();
```

A null ad is a normal answer, not a failure: no campaign matched, the budget is spent, the
slot is capped for today. Collapse the space or draw your own content — never show an error.

Two obligations come with drawing it yourself, and they are the reason the default renderer
exists: call `recordImpression()` only when the ad is genuinely on screen, and label it as an
advertisement. `ad.disclosureLabel` gives you the wording.

**Full screen** — loaded first and shown later, because the moment worth interrupting is
rarely the moment you have a network round trip to spare:

```dart
final ad = await SanbukFullscreen.load('LEVEL-END');
// ...later, when your app decides...
await ad?.show();
```

`SanbukFullscreen.loadRewarded` is the version somebody opted into. The interruption rules —
nothing during a cold start, nothing back to back, a ceiling per session, a close control
after a few seconds — are enforced in the native SDK, not here, so they are the same on every
platform and cannot be tuned away by a shell.

## What this package is

A thin binding, deliberately. Matching, pacing, frequency caps, trial periods and budgets live
on the Sanbuk server; the viewability rule, the offline impression queue and the interruption
rules live in the native SDK. This package asks, draws, and reports.

A version shipped to phones is frozen for months, so a rule hardened into a shell would
outlive several changes of mind — and would have to be written again for every other shell,
where the copies would drift.

## Running the example

```bash
cd example && flutter run
```

`flutter test` runs the unit tests against a fake channel. The one test that needs a real
device is separate, because a fake answers whatever it is told to and cannot catch a method
name the Kotlin side spells differently:

```bash
cd example && flutter test integration_test
```

## Related

- [Sanbuk Android SDK](https://github.com/sanbuk-dev/sanbuk-android) — the native SDK underneath
- [Sanbuk iOS SDK](https://github.com/sanbuk-dev/sanbuk-ios)
