# Release Checklist

This project is not ready for a broad non-developer release until signing and notarization are in place. Use this checklist when preparing any public release.

## Preflight

- [ ] `./Scripts/check-project.sh` passes locally.
- [ ] GitHub Actions CI passes on `main`.
- [ ] README install instructions match the current build path.
- [ ] `VERSION`, `BundleResources/Info.plist`, README release command, and the intended Git tag refer to the same version.
- [ ] `CHANGELOG.md` has an entry for the release.
- [ ] No `.build/`, local app data, API keys, or private screenshots are committed.
- [ ] Privacy-impacting changes are reflected in `PRIVACY.md`.

## Manual Product Smoke Test

- [ ] Run `./Scripts/install-local.sh`.
- [ ] Confirm the app exists in `~/Applications/ClipboardStation.app`.
- [ ] Run `./Scripts/doctor.sh` and confirm the launch agent is loaded.
- [ ] Launch packaged app.
- [ ] Floating bubble appears and opens/closes the station.
- [ ] Menu bar icon opens/closes the station.
- [ ] Copy plain text and confirm it appears once.
- [ ] Import or copy a screenshot and confirm image preview renders.
- [ ] Copy spreadsheet-like text and confirm it is treated as a table snippet.
- [ ] Reorder snippets with up/down controls.
- [ ] Add snippets to the composer and copy composed text.
- [ ] Disable Accessibility permission and confirm the app gives a clear paste warning.
- [ ] Re-enable Accessibility permission and confirm paste works.

## Packaging

- [ ] Run `./Scripts/package-app.sh`.
- [ ] Run `./Scripts/make-release-zip.sh vX.Y.Z`.
- [ ] Confirm `.build/ClipboardStation.app` launches.
- [ ] Confirm `.build/dist/Linggan-Floating-Ball-vX.Y.Z.zip` exists and unzips to `ClipboardStation.app`.
- [ ] Confirm `./Scripts/install-local.sh` installs into `~/Applications`.
- [ ] Confirm `./Scripts/uninstall-local.sh` removes the app and launch agent without deleting user data.
- [ ] Confirm the app icon appears.
- [ ] Confirm the app does not create duplicate instances.

## Future Signed Release

- [ ] Sign app with Developer ID.
- [ ] Notarize app.
- [ ] Staple notarization ticket.
- [ ] Provide checksum for release asset.
- [ ] Add install instructions for non-developers.
