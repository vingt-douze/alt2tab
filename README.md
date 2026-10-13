# Alt²Tab

Alt²Tab is an independent fork of [AltTab](https://github.com/lwouis/alt-tab-macos), the macOS window switcher. It is not affiliated with or endorsed by the upstream maintainer.

The fork exists to provide the AltTab experience with all currently integrated functionality available, without the upstream Pro/license requirement.

## Status

- Published as notarized releases: <https://github.com/vingt-douze/alt2tab/releases>.
- No automatic updater: Sparkle is never started and no update feed is configured.
- No upstream license server dependency: all features are unlocked at build time; the app never contacts a license API.
- No AppCenter crash reporting: the SDK is never started and no secret is embedded.

## Versioning

Releases are numbered `<upstream version>.<fork revision>`, following the same order as a Debian or RPM package revision. The leading numbers are the upstream AltTab version that release merges; the last one counts the Alt²Tab releases built on it. `11.9.1.1` is the first Alt²Tab release based on upstream `v11.9.1`, a second one on that same upstream is `11.9.1.2`, and the first release on upstream `v11.10.0` is `11.10.0.1`. Keeping the upstream version first is what makes the numbering always increase.

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
