# Alt²Tab

Alt²Tab is an independent fork of [AltTab](https://github.com/lwouis/alt-tab-macos), the macOS window switcher. It is not affiliated with or endorsed by the upstream maintainer.

The fork exists to provide the AltTab experience with all currently integrated functionality available, without the upstream Pro/license requirement.

## Status

- Not yet publicly released.
- No automatic updater: Sparkle is never started and no update feed is configured.
- No upstream license server dependency: all features are unlocked at build time; the app never contacts a license API.
- No AppCenter crash reporting: the SDK is never started and no secret is embedded.

## Build

Requires Xcode. From the repository root:

```bash
scripts/codesign/setup_local.sh
```

Creates a local self-signed certificate (one-time) so macOS keeps the Accessibility and Screen Recording permissions across Debug builds.

```bash
xcodebuild -project alt-tab-macos.xcodeproj -scheme Debug -configuration Debug -derivedDataPath DerivedData
```

The app is written to `DerivedData/Build/Products/Debug/Alt2Tab.app`.

## Issues

Report Alt²Tab issues at <https://github.com/vingt-douze/alt2tab/issues>. Do not report them to the upstream project.

## License

The source is licensed under the [GPL-3.0](LICENCE.md). Upstream copyright and attribution are retained: see [contributors](docs/contributors.md) and [acknowledgments](docs/acknowledgments.md).

Upstream project: [lwouis/alt-tab-macos](https://github.com/lwouis/alt-tab-macos).
