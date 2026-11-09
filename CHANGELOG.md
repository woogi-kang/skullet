## 0.2.0 (unreleased)

**Breaking**

- `measureBones`, `Bone` and `BoneKind` moved out of `package:skullet/skullet.dart` into `package:skullet/measure.dart`. Apps rarely need them, and `Bone` clashed with skeletonizer's. `SkeletonShape` stays in both.
- Remembered shapes are now keyed by screen width as well as text scale (to the nearest 40 logical pixels), so shapes stored by 0.1.0 under a persistent `ShapeStore` are measured once more before they are remembered again.
- `SkeletonShape.toJson` writes a format version (`v`) and bone kinds by name. `fromJson` still reads what 0.1.0 wrote, and throws a `FormatException` for a format it doesn't know; `tryFromJson` returns null instead.
- Skeletons where tickers are off (`TickerMode`), such as on a route behind another or a tab out of sight, hold still and reveal at once, as under reduced motion.

**Fixes**

- The sample measured for a skeleton can no longer take focus (autofocus or Tab), run its own animations, or fly as a hero.
- Content keeps its state (scroll offsets, text being typed, opened tiles) while a refetch draws its skeleton over it, instead of being built again.
- Corners given by direction (`BorderRadiusDirectional`) are measured in the ambient text direction, and a `sequence` reveal reads right to left in RTL.
- `SelectableText` and a bare `EditableText` are measured as lines of text, and widgets inline in text (`WidgetSpan`) get bones of their own.
- The sweep's screen size comes from the view the skeleton is in, not the first window.

**New**

- Cupertino controls (`CupertinoSwitch`, `CupertinoCheckbox`, `CupertinoRadio`, `CupertinoSlider`, `CupertinoActivityIndicator`, `CupertinoTextField`) are measured as blocks.
- `SkulletTheme` is a `ThemeExtension`: put it in `ThemeData.extensions` and it blends when the theme changes. A provider's theme still wins.
- `SkulletProvider.store`, for a shape store per account or per test, and `SkulletProvider.label`, read for skeletons without a label of their own.
- Under high contrast (`MediaQuery.highContrast`), the skeleton's fill is twice as strong.
- `FutureSkeleton` takes `skeleton` and `reveal`, and debug builds print the error of a failed future with no `errorBuilder`.
- `Skullet.lastData` keeps the 64 ids shown most recently (`Skullet.lastDataLimit`).
- `--dart-define=SKULLET_TEST=true` marks a test run where the environment can't, as in `flutter test --platform chrome`.

**Performance**

- Each skeleton paints on a layer of its own, so its shimmer no longer repaints the content around it every frame.
- A row-by-row reveal redraws its mask only when a row's opacity changes by a sixteenth, rather than every frame.
- Measuring counts siblings once per parent, and shows in DevTools' timeline as `skullet: measure`.

**Project**

- CI runs integration tests on an Android emulator, an iPhone simulator, macOS, Windows, Linux and Chrome; unit tests in Chrome with leak tracking; golden images on a pinned Flutter; and checks the public API against the latest release.
- Issue templates, a contributing guide, Dependabot for workflow actions, and a workflow that publishes a pushed version tag to pub.dev.

## 0.1.0

First release: a Flutter port of [skullet](https://github.com/lochie/skullet).

- `Skeleton<T>`: measures the content built from `sample` (or the data last shown, or a remembered shape) into a skeleton, and reveals the real content in its exact space.
- `Skeleton.child` for loading flags you toggle yourself, and `FutureSkeleton` for futures.
- Reveals: `smart` (default), `together`, `sequence`, `sweep`, `instant`.
- Themes: light and dark colours, `shimmer`, `groupShimmer`, `pulse` or `none`, slow or fast, all sharing one phase across the screen.
- Hints: `SkeletonBlock`, `SkeletonIgnore`, `SkeletonReplace`, and `SkeletonBox` placeholders.
- Remembered shapes through a pluggable `ShapeStore`; `forgetShapes()` on sign-out.
- Images still loading after a reveal keep a skeleton of their own until decoded.
- Debug overlay and development warnings for skeletons that don't match their content.
- `SkulletMode.system` follows the brightness the app shows, read from the surrounding text colour, rather than the platform's: a light-only app on a system in dark mode got the dark palette, white bones on a white page.
- Under `flutter test`, skeletons hold still and reveals are instant, so `pumpAndSettle` settles.
