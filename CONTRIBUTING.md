# Contributing to skullet

Thanks for helping. skullet is an unofficial Flutter port of [skullet](https://github.com/lochie/skullet) by Lochie Axon; this repository is only the Flutter port.

## Before you start

- For a bug, open an issue with the bug template first. The smallest widget that shows it, `flutter --version`, and a screenshot with `SkulletProvider(debug: true)` save a lot of back and forth.
- For a new feature, open an issue to talk it through before writing code. The public API is kept small on purpose.

## Checks

Run these before you open a pull request; CI runs the same:

```shell
dart format lib test example/lib example/test example/integration_test example/test_driver
flutter analyze
flutter test --exclude-tags golden
cd example && flutter analyze && flutter test
```

On a device or simulator, the integration tests:

```shell
cd example
flutter test integration_test -d <device id>
```

## Golden images

The golden images in `test/goldens/` are rendered on Linux with the Flutter version pinned in the `goldens` job of `.github/workflows/ci.yml`. Text rasterises a little differently on other systems and versions, so:

- Check them with `flutter test --tags golden` on Linux, with that Flutter.
- Update them with `flutter test --tags golden --update-goldens`, and look at every changed image before you commit it.
- To move to a newer Flutter, change the pinned version and update the goldens in the same pull request.

## Geometry cases

`test/geometry_cases.dart` holds layouts ported from the original's test cases, each checked by `test/geometry_test.dart` the way the original's `verify.ts` checks them. To cover a new kind of widget, add a case there: what it should measure as (a bar per line, one block, a surface) is the test.

## Versions and the changelog

- Before 1.0, a minor version (0.x.0) may break the API; a patch (0.x.y) may not. The `api` job in CI compares the public API with the latest release on pub.dev and fails when a break isn't matched by the version.
- Add a line under the unreleased version in `CHANGELOG.md` for anything a user would notice, and mark breaking changes **Breaking**.
- Releases are published from a version tag by `.github/workflows/publish.yml`. Only the maintainer pushes tags.

## Upstream

When the original skullet changes behaviour, a port of that change notes it in the changelog as *upstream*.
