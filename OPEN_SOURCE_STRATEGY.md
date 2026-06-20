# Open Source Strategy

Scrivora’s public repo should be useful on day one: buildable source, clear
privacy boundaries, clean model policy, and no local machine artifacts.

Use `RELEASE_STATUS.md` for the current release state.

## First Public Cut

Publish the macOS app and core Swift package together.

Include:

- Local audio capture and 16 kHz mono processing.
- Ring buffer, VAD, chunk scheduling, and recorder lifecycle.
- FluidAudio and whisper.cpp integration points.
- Model catalog, local model download helpers, and model-selection fallback.
- App-aware cleanup profiles.
- Clipboard insertion and copy fallback.
- Local history, correction memory, privacy export, and redaction.
- macOS menu bar shell, global triggers, and floating overlay.
- Build scripts, release scripts, tests, website, and update templates.

Exclude:

- Model weights.
- Generated `.app`, `.zip`, `.dmg`, and notarization output.
- Signing identities, certificates, keychains, profiles, and Apple credentials.
- Local transcripts, recordings, logs, app support folders, and model caches.
- Future payment, license-key, telemetry, or support systems.

## License Gate

A public repository needs a real source license. Until `LICENSE` exists, people
can read the code but do not have clear rights to use, modify, or redistribute
it.

Pick one license, add `LICENSE`, then update:

- `README.md`
- `LICENSE_PLAN.md`
- `THIRD_PARTY_NOTICES.md`
- GitHub repository license metadata

## Model Policy

The source release should not bundle speech model weights.

The app may download supported models on the user’s machine. Before bundling or
mirroring any model file, record the upstream URL, exact license, attribution
requirements, commercial-use terms, and redistribution terms in
`MODEL_LICENSES.md` and `THIRD_PARTY_NOTICES.md`.

## GitHub Repo Setup

Before flipping the repo public:

1. Add `LICENSE`.
2. Keep `SECURITY.md`, `CONTRIBUTING.md`, and `.github/` templates in the repo.
3. Run:

   ```bash
   swift test
   swift build --product LocalVoiceFlowApp
   Scripts/audit_sensitive_files.sh
   Scripts/stage_site.sh
   ```

4. Confirm `git ls-files` does not include generated binaries, model weights,
   transcripts, recordings, local logs, app bundles, zips, DMGs, keychains,
   certificates, profiles, or signing passwords.
5. Push to the intended GitHub repository.
6. Enable GitHub Pages or Vercel only after the domain target is confirmed.

## Binary Release Boundary

Open source does not make the Mac app safe to download.

Public DMG and in-app update releases require:

- Developer ID Application signing.
- Hardened runtime.
- Notarization.
- Stapling.
- Gatekeeper verification on a clean Mac.
- A final updater ZIP URL, byte size, and SHA-256.

Keep `updates/stable.example.json` as a template. Publish `updates/stable.json`
only after it is generated from the exact uploaded updater ZIP.

## Public Positioning

Say this:

- Scrivora is private voice writing for macOS.
- Core dictation runs locally and does not require an account, card, or cloud
  speech API.
- Model downloads and update checks are explicit network actions.
- The source repo is public once the license is added.
- Public Mac downloads use the signed release channel.

Do not claim this until verified:

- App Store availability.
- Live auto-updates.
- Notarized public download.
- Bundled model redistribution rights.
- Security bounty or guaranteed response SLA.
