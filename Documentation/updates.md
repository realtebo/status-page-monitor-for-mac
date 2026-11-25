# Official macOS app updates

This project uses [Sparkle](https://sparkle-project.org/) for update discovery and installation. Sparkle reads a signed appcast and downloads a signed release archive. GitHub Releases can host the archives; GitHub Pages can host the static appcast. Sparkle does not discover GitHub releases by repository name alone.

## Current repository state

- The Xcode project currently depends on SwiftSoup only; Sparkle has not yet been added.
- The app bundle identifier is `org.statuspagemonitor.mac` and the deployment target is macOS 13.0.
- The official repository is [realtebo/status-page-monitor-for-mac](https://github.com/realtebo/status-page-monitor-for-mac). The appcast URL is still pending.
- No Developer ID signing identity or Sparkle EdDSA key is configured.

The updater code is intentionally inert until Sparkle is linked and the bundle has a real HTTPS `SUFeedURL` and `SUPublicEDKey`. No example URL, public key, or signing credential should be shipped as configuration.

## Xcode integration

1. Add the official Sparkle Swift package, `https://github.com/sparkle-project/Sparkle`, to the macOS app target and link its `Sparkle` product. At the time this guide was checked (2026-11-25), the latest stable release was Sparkle 2.10.1; it supports macOS 12 and later, which includes this app's macOS 13 minimum. Keep the resolved package version committed and review Sparkle updates deliberately. See [Sparkle's setup guide](https://sparkle-project.org/documentation/) and [official release](https://github.com/sparkle-project/Sparkle/releases/latest).
2. Add `Sources/StatusPageMonitorApp/OfficialUpdater.swift` to the app target if Xcode does not include it automatically.
3. In `AppLifecycleDelegate.applicationDidFinishLaunching`, access `OfficialUpdater.shared` so automatic checks start with the app. Its controller must remain retained; the singleton does that.
4. Add a **Check for Updates…** action to the app's menu or settings view. Call `OfficialUpdater.shared.checkForUpdates()` and disable the action while `canCheckForUpdates` is false. The Sparkle standard controller uses its native update UI.
5. Set the actual `SUFeedURL` and `SUPublicEDKey` as app-target Info.plist values only after the official feed and signing key have been established. The URL must be HTTPS. Sparkle uses the app's `CFBundleVersion` to compare installed and available releases; increment it for each release.
6. Verify that **Product → Archive → Distribute App → Developer ID** produces an app that is signed and notarized, and that Sparkle's embedded helpers are signed as part of the Xcode archive. The project currently disables code signing, so distribution signing needs a separate release configuration.

Sparkle's standard defaults ask the user on the second launch whether the app may check automatically; if allowed, the normal scheduled check is once per day. It offers updates for installation and does not silently install by default. Keep that consent and installation behavior unless a separate product decision changes it. See [Sparkle's customization reference](https://sparkle-project.org/documentation/customization/).

## One-time release setup

Complete these steps only in a maintainer-controlled environment:

1. Configure GitHub Pages for the official repository. With the default project site, publish the feed at `https://realtebo.github.io/status-page-monitor-for-mac/appcast.xml` and verify that it responds before setting `SUFeedURL`. Attach the signed archives to the [official GitHub Releases](https://github.com/realtebo/status-page-monitor-for-mac/releases).
2. Enroll the maintainer account in Apple's Developer ID program and configure Xcode signing/notarization for the official app. Use a Developer ID identity for the released app; ad-hoc signatures are not suitable for public distribution.
3. Add Sparkle to the project, then use Sparkle's `generate_keys` tool once on a trusted maintainer Mac. It stores the private EdDSA key in that user's login Keychain and prints the public key. Put only the public key in the app's `SUPublicEDKey`; never commit or upload the private key. Make a secure recovery/export plan before relying on this key.
4. Record the canonical HTTPS appcast URL as `SUFeedURL`. Keep it stable: every installed copy uses this URL for future checks.
5. For stronger feed validation, enable `SUVerifyUpdateBeforeExtraction` and `SURequireSignedFeed` together. EdDSA signatures are required for verification before extraction; signed feeds also require signing feed/release-note content. Do not enable `SURequireFeedBundleIdentifier` until the project adopts a Sparkle release that supports it (the official docs currently identify it as 2.11 beta).
6. Decide where the release archives and generated feed will be published. A practical GitHub-hosted layout is a stable appcast file on Pages, with each signed `.zip` or `.dmg` attached to the matching official GitHub Release. `generate_appcast` must write archive links that resolve publicly over HTTPS. GitHub Pages publishes static repository files; GitHub Releases accept binary assets. See [GitHub Pages publishing](https://docs.github.com/en/pages/getting-started-with-github-pages/creating-a-github-pages-site) and [managing GitHub releases](https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository).

## Publishing each release

1. Increment `CFBundleVersion` and set the user-facing `CFBundleShortVersionString`.
2. Archive the app in Xcode and distribute it with Developer ID signing and notarization. Test the archive as an installed app, not only from Xcode's build folder.
3. Create a ZIP that preserves the app bundle's symlinks and permissions:

   ```bash
   ditto -c -k --sequesterRsrc --keepParent StatusPageMonitor.app StatusPageMonitor.zip
   ```

4. Put the archive in the update archive directory used for the release history. Run Sparkle's `generate_appcast` on that directory from the Sparkle distribution tools. It generates the EdDSA signatures and appcast entries; use its help output to set the archive URL prefix for the configured official GitHub Release download location.
5. Publish the app archive as an asset on the matching official GitHub Release. Publish the generated appcast (and any generated delta archives or signed release notes) to the configured HTTPS feed location. Do not publish the appcast before its referenced assets are available.
6. Test from a lower-version, Developer ID-signed build. Confirm the appcast is reachable without authentication, the release archive URL is reachable, Sparkle accepts the signature, and the update installs and relaunches correctly. Then test the normal user flow for automatic-check permission and the manual **Check for Updates…** action.

Sparkle recommends `generate_appcast` because it creates update signatures and feed metadata; preserve previous release archives so delta generation and older installed versions continue to work. See [Sparkle's publishing guide](https://sparkle-project.org/documentation/publishing/).

## Required wiring and blockers

The isolated implementation is in `Sources/StatusPageMonitorApp/OfficialUpdater.swift`. The app owner still needs to:

- add the Sparkle package product to the Xcode app target and include the source file in the target;
- initialize the singleton in the existing app launch delegate;
- add the user-facing **Check for Updates…** action;
- set actual `SUFeedURL` and `SUPublicEDKey` values in the release app's generated Info.plist settings;
- configure Developer ID signing and notarization for release archives.

The automatic update feed cannot be activated until the canonical GitHub repository/feed URL, a maintainer-controlled Developer ID identity, and a Sparkle EdDSA key are available. These are deployment inputs; the code deliberately does not invent or substitute values for them.

## Sources

- [Sparkle documentation: setup and security](https://sparkle-project.org/documentation/)
- [Sparkle programmatic setup for SwiftUI](https://sparkle-project.org/documentation/programmatic-setup/)
- [Sparkle configuration reference](https://sparkle-project.org/documentation/customization/)
- [Sparkle publishing guide](https://sparkle-project.org/documentation/publishing/)
- [Sparkle latest stable release](https://github.com/sparkle-project/Sparkle/releases/latest)
- [GitHub Pages: creating a site](https://docs.github.com/en/pages/getting-started-with-github-pages/creating-a-github-pages-site)
- [GitHub: managing repository releases](https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository)
