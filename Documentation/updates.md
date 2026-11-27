# App updates

The app checks the public GitHub Releases API at startup and hourly while automatic checks are enabled. It treats the historical tags `v0.01` and `v0.02` as `0.0.1` and `0.0.2`, compares numeric version components, and includes prereleases with the official Apple silicon ZIP. An available release appears in Settings and the menu bar. Notifications and automatic installation are separate opt-ins.

A signed release includes a Sparkle 2.10.1 appcast alongside its ZIP. The app embeds the maintainer's public Ed25519 key and verifies the update before extraction. When automatic installation is enabled, Sparkle installs the prepared update and relaunches the app. Older releases containing only a ZIP can still be announced. Users of v0.01 and v0.02 must install the first update-enabled release manually. The ad hoc macOS signature used for release builds does not provide Apple Developer ID or notarization.

## Configure the signing key once

On the maintainer Mac, build the project using the README command so Swift Package Manager downloads Sparkle. From the repository root, run the following commands in a shell authenticated to GitHub CLI with repository administration access.

1. Generate the project key in your login Keychain. Keep a secure backup and reuse this account for subsequent releases. The tool prints the public key.

   ```sh
   sparkle_tools=build/SourcePackages/artifacts/sparkle/Sparkle/bin
   repo=realtebo/status-page-monitor-for-mac
   account=status-page-monitor-mac
   "$sparkle_tools/generate_keys" --account "$account"
   ```

2. Save the public key as the repository Actions variable `SPARKLE_PUBLIC_KEY`.

   ```sh
   "$sparkle_tools/generate_keys" --account "$account" -p | gh variable set SPARKLE_PUBLIC_KEY --repo "$repo"
   ```

3. Export the private key into a temporary private directory, transfer it to the repository Actions secret `SPARKLE_PRIVATE_KEY` and remove the temporary copy. The original stays in the Keychain.

   ```sh
   (
     set -eu
     umask 077
     key_dir="$(mktemp -d)"
     trap 'rm -f "$key_dir/signing.key"; rmdir "$key_dir"' EXIT
     "$sparkle_tools/generate_keys" --account "$account" -x "$key_dir/signing.key"
     gh secret set SPARKLE_PRIVATE_KEY --repo "$repo" < "$key_dir/signing.key"
   )
   ```

For a local update-enabled build, pass `SPARKLE_PUBLIC_ED_KEY` with the public key and `CURRENT_PROJECT_VERSION` with the intended internal build number to Xcode. Local builds without this configuration can still check for releases and send notifications.

## Publish a release

Follow the annotated-tag procedure in the [README](../README.md#releases). The workflow uses the tag as the marketing version, the workflow run number as the internal build number, and the tag message as the release notes. A normal push to main only updates the source.

Xcode signs the bundled app and embedded frameworks ad hoc. The job verifies the app with `codesign`, creates the ZIP, then uses the pinned Sparkle package's `generate_appcast` executable to sign the archive and embed the notes. The secret is available only to the signing step. The workflow publishes the draft after uploading both assets:

- `StatusPageMonitor-macOS-arm64.zip`
- `appcast.xml`

Both are served from the tag's public GitHub Release. A missing or mismatched signing key prevents publication. Verify the first installation and upgrade on a Mac with the actual release key before distributing it. [Sparkle publishing guide](https://sparkle-project.org/documentation/publishing/)
