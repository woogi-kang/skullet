## 0.1.0 (unreleased)

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
