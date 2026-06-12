# LocalVoiceFlow Product Spec

## Product

LocalVoiceFlow is a native macOS menu bar dictation assistant. It records speech from a global shortcut or floating control, transcribes locally, optionally cleans the transcript locally, and inserts the final text into the currently focused app. It has no account, subscription, analytics, or required cloud API.

## MVP

The MVP must prove the fast privacy-first loop:

1. User launches the menu bar app.
2. User grants microphone and accessibility permissions.
3. User selects or downloads a local ASR model.
4. App loads and warms the selected model before dictation.
5. User presses the global shortcut.
6. Recording starts immediately and audio enters an in-memory 16 kHz mono buffer.
7. VAD detects speech and silence.
8. The app schedules rolling chunks and shows listening/processing state.
9. The app builds a final transcript.
10. Deterministic cleanup handles spacing, capitalization, punctuation, and commands like "new line".
11. The app inserts text through accessibility where possible and clipboard paste as fallback.
12. The app restores the previous clipboard when safe.
13. Latency metrics are stored locally and shown in a debug screen.

## MVP Screens

- Menu bar menu.
- Welcome/onboarding.
- Permission status.
- Floating dictation overlay.
- Preferences.
- Dictation settings.
- Model manager.
- Post-processing settings.
- History.
- Privacy.
- Debug/performance.
- About.

## MVP Privacy Defaults

- No analytics.
- No account.
- No audio saved.
- Transcript history enabled only if the user leaves it enabled.
- Privacy mode disables history immediately.
- Network only used for explicit model downloads.
- Data and models stored under Application Support.

## V1

- Production WhisperKit SDK integration.
- Production whisper.cpp C API fallback.
- Multiple ASR models with benchmarks.
- Stable partial transcript display.
- Long dictation stable sentence commits.
- Optional local LLM cleanup through llama.cpp.
- User dictionary.
- Custom replacements.
- Custom prompts.
- Per-app behavior rules.
- Searchable local history.
- Import/export settings.
- Improved floating overlay.

## Future

- sherpa-onnx streaming backend.
- Moonshine backend if benchmarking proves lower latency.
- Parakeet backend if macOS packaging becomes practical.
- MLX local LLM backend.
- More voice editing commands.
- App-specific profiles.
- Signed distribution outside the Mac App Store.

## Non-Goals For MVP

- Cloud transcription.
- Cloud cleanup.
- Accounts or sync.
- Team features.
- Raw audio history.
- Multiple ASR engine production support at once.
- A copied Wispr Flow brand, layout, icon set, animation style, or copy.

