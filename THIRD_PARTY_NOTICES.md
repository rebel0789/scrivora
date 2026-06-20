# Third-Party Notices

Scrivora is a local macOS app. The source repo does not track model weights,
recordings, transcripts, app bundles, zips, DMGs, signing material, or
notarization output.

Keep this file current when adding packages, model downloaders, generated
assets, release binaries, or bundled models.

## Runtime And Build Dependencies

| Component | Use | License / notice status |
| --- | --- | --- |
| Swift, SwiftPM, AppKit, SwiftUI, AVFoundation, Carbon | macOS app, package build, capture, UI, hotkeys, and text insertion. | Used through Apple platform SDKs. |
| FluidAudio | Local speech package and model loader. | Upstream describes local low-latency audio AI and open-source models under MIT / Apache 2.0 signals. Preserve upstream notices. |
| NVIDIA Parakeet TDT 0.6B V3 | Default FluidAudio speech model path. | Hugging Face model card lists CC-BY-4.0. Attribute before bundling or redistributing model artifacts. |
| NVIDIA Parakeet TDT 0.6B V2 | Secondary FluidAudio speech model path. | Hugging Face model card lists `cc-by-4.0`. Attribute before bundling or redistributing model artifacts. |
| whisper.cpp | Optional local speech fallback engine. | MIT. Preserve upstream copyright and license if source or binaries are redistributed. |
| ggml Whisper model files | Optional whisper.cpp fallback models. | Hugging Face model page lists MIT and per-file SHA-256 values. Do not commit downloaded weights. |

## Model Policy

The first public source release should not bundle speech model weights.

The app may download supported models onto the user’s Mac and verify expected
hashes before treating those models as available. If a later release bundles
model weights, add the exact license text, attribution, redistribution decision,
and artifact provenance here before publishing.

## Local Artifacts

Do not commit:

- Downloaded model weights.
- Built whisper.cpp binaries unless a release policy explicitly includes them.
- Generated app bundles, zips, DMGs, or notarization output.
- Local transcripts, recordings, logs, or support exports.
- Signing identities, keychains, certificates, profiles, or notary credentials.

## Release Check

Before a public tag:

1. Confirm every third-party license and attribution requirement.
2. Confirm whether source, binaries, converted models, and quantized artifacts
   can be redistributed.
3. Update `MODEL_LICENSES.md` with any changed model source or license.
4. Run `Scripts/audit_sensitive_files.sh`.
