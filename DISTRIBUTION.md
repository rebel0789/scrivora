# Scrivora Distribution Notes

Date: 2026-06-12

## Current Development Install

Build and install locally:

```bash
swift test
Scripts/install_app_bundle.sh
open /Applications/Scrivora.app
```

Current installed app:

```text
/Applications/Scrivora.app
```

Executable:

```text
/Applications/Scrivora.app/Contents/MacOS/LocalVoiceFlowApp
```

Bundle ID:

```text
app.localvoiceflow.mvp
```

Version:

```text
0.3.0
```

Development signing authority:

```text
LocalVoiceFlow Development
```

## Development Signing

The local package script uses `.build/dev-signing` by default.

Relevant scripts:

```bash
Scripts/create_local_codesign_identity.sh
Scripts/package_dev_app.sh
Scripts/package_app_bundle.sh
Scripts/install_app_bundle.sh
Scripts/clean_dev_signing_material.sh
```

To move older dev signing files out of app support:

```bash
Scripts/clean_dev_signing_material.sh --move
```

To audit sensitive paths:

```bash
Scripts/audit_sensitive_files.sh
```

## Production Distribution Requirements

Before sharing Scrivora with users outside local development:

1. Create an Apple Developer ID Application signing identity.
2. Enable hardened runtime.
3. Review entitlements.
4. Build a release app bundle.
5. Sign with Developer ID.
6. Notarize with Apple.
7. Staple notarization ticket.
8. Verify Gatekeeper on a clean Mac.
9. Verify microphone and Accessibility permission prompts on a clean Mac.

Gated release script placeholders now exist:

```bash
Scripts/package_release_app.sh
Scripts/notarize_release_app.sh
Scripts/staple_release_app.sh
Scripts/verify_release_app.sh
```

They are intentionally not a completed release pipeline yet. `package_release_app.sh` exits unless `DEVELOPER_ID_APPLICATION` is set, and notarization requires Apple ID, team ID, and an app-specific password.

## Not Production Ready Yet

The current app is installed and usable locally, but it is not production-distribution ready because:

- It is not Developer ID signed.
- It is not notarized.
- It uses a local self-signed development identity.
- It has not been clean-install tested on a separate Mac.
- It has not been benchmarked under long-duration battery/load scenarios.

## Permission Stability

macOS privacy permissions are tied to app identity and signing requirement. For local MVP testing:

- Keep installing to `/Applications/Scrivora.app`.
- Keep bundle ID `app.localvoiceflow.mvp`.
- Keep the same `LocalVoiceFlow Development` identity.

Changing any of those may trigger fresh microphone or Accessibility permission prompts.
