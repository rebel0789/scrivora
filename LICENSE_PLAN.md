# License Decision

Scrivora source is released under the MIT License.

The repository includes `LICENSE` at the root. Public visibility now grants
clear rights to use, modify, and redistribute the source under MIT terms.

This file is an engineering checklist. It is not legal advice.

## Decision

Selected source license: `MIT`.

Do not mix license families casually. New third-party code must remain
compatible with the source license and the notices in this repo.

## Separate From Model Licenses

The source license does not license model weights.

Before a public release:

- Confirm FluidAudio package terms.
- Confirm each Parakeet model license.
- Confirm whisper.cpp license terms.
- Confirm every whisper model license and redistribution term.
- Do not bundle model weights unless redistribution is explicitly allowed.

See `MODEL_LICENSES.md`.

## Separate From Apple Distribution

Open-source licensing does not solve macOS distribution requirements.

Public app downloads still require:

- Developer ID signing.
- Hardened runtime.
- Notarization.
- Stapling.
- Gatekeeper verification on a clean Mac.

See `DISTRIBUTION.md`.

## Commercial Boundary

If the project later adds paid features, keep that boundary explicit:

- Public local dictation code can stay under the selected source license.
- Private payment, license-key, hosted update, or customer systems can remain
  separate.
- Do not add license checks to the local privacy path without documenting the
  data flow.

## Release Step

1. Keep `LICENSE` in the root.
2. Keep copyright owner text current.
3. Check dependency compatibility before adding packages.
4. Check model-license compatibility before bundling or mirroring models.
5. Keep `README.md`, `MODEL_LICENSES.md`, and `THIRD_PARTY_NOTICES.md`
   current.
