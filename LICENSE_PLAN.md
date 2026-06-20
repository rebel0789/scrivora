# License Decision

No source license has been selected yet.

Before the GitHub repo is made public, choose one source license and add
`LICENSE`. Public visibility without a license lets people read the code, but it
does not grant clear rights to use, modify, or redistribute it.

This file is an engineering checklist. It is not legal advice.

## Decision

Choose one source license for the public codebase.

Common options to evaluate:

- `Apache-2.0`: permissive license with an explicit patent grant.
- `MIT`: short permissive license with minimal conditions.
- `GPL-3.0-or-later`: copyleft license that requires derivative works to stay
  under compatible terms.

Do not mix license families casually. The source license must be compatible with
the third-party code and packages used by the project.

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

1. Pick the license.
2. Confirm copyright owner text.
3. Check dependency compatibility.
4. Check model-license compatibility.
5. Update `README.md` with the chosen license.
6. Keep `THIRD_PARTY_NOTICES.md` current.
7. Update GitHub repository license metadata after pushing.
