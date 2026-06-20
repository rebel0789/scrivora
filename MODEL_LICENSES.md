# Model Licenses

Scrivora does not track or commit speech model weights in this repo.

The app can download or use local models on the user’s machine. Those files have
their own licenses and redistribution rules.

## Current Catalog

| Model family | Source | Current license signal | Repo policy |
| --- | --- | --- | --- |
| FluidAudio package | `https://github.com/FluidInference/FluidAudio` | Upstream describes open-source Core ML audio models and local ANE inference. | Package dependency is pinned in `Package.resolved`; preserve upstream notices. |
| NVIDIA Parakeet V3 | `https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3` | Hugging Face model card lists CC-BY-4.0. | Download locally only. Do not bundle without attribution review. |
| NVIDIA Parakeet V2 | `https://huggingface.co/nvidia/parakeet-tdt-0.6b-v2` | Hugging Face model card lists `cc-by-4.0`. | Download locally only. Do not bundle without attribution review. |
| whisper.cpp | `https://github.com/ggml-org/whisper.cpp` | MIT. | Preserve upstream copyright and license if source or binaries are redistributed. |
| ggml Whisper models | `https://huggingface.co/ggerganov/whisper.cpp` | Hugging Face model page lists MIT and per-file SHA values. | Download locally with pinned hashes. Do not commit weights. |

## Local Cache Locations

Do not commit these paths or their contents:

- `~/Library/Application Support/FluidAudio/Models`
- `~/Library/Application Support/LocalVoiceFlow`
- `~/Library/Application Support/Scrivora`
- `.build/`
- Any downloaded `.gguf`, `.bin`, `.mlmodel`, `.mlpackage`, or generated model
  artifact.

## Required Review Before Bundling Models

For each model or model downloader:

1. Record the upstream project URL.
2. Record the exact license.
3. Record whether commercial use is allowed.
4. Record whether redistribution is allowed.
5. Record attribution requirements.
6. Record whether converted or quantized artifacts can be redistributed.
7. Decide whether the public app downloads the model from upstream or asks the
   user to provide it.

## Packaging Rule

Default to source releases and app releases with no bundled model weights.

Only bundle a model when its license, redistribution terms, attribution text,
and generated-artifact rights are confirmed and reflected in
`THIRD_PARTY_NOTICES.md`.
