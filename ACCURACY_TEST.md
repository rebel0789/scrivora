# Scrivora Accuracy Test

This test is for real user voice accuracy and app-specific cleanup behavior. It stays local. Do not commit generated recordings.

## Live App Test

Use `/Applications/Scrivora.app` with:

- ASR model: `Parakeet V2 English`
- Trigger: `Hold Control`
- Cleanup output profile: `Automatic`

Open each target app, click into a text field, hold Control, read the matching prompts from `BenchmarkSamples/reading-prompts.csv`, then release Control.

Target app buckets:

- Coding: VS Code, Cursor, Xcode, Terminal, iTerm, Warp
- Agent: ChatGPT, Claude, Codex, Gemini, Perplexity
- Email: Mail, Outlook, Spark, Superhuman
- General writing: Notes, TextEdit, Pages, Notion, Slack, Discord
- Browser: Chrome, Safari, Brave, Arc, Firefox

Expected profile behavior:

- Coding apps resolve to `Pragmatic`: less prose polish, no forced final period.
- Agent apps resolve to `Agent`: clean prompt-style text.
- Email apps resolve to `Email`: sentence casing and final punctuation.
- Notes/TextEdit/browser resolve to `General` until tab-specific routing exists.

## Measured WER/CER Test

Record your own voice samples:

```bash
Scripts/record_benchmark_samples.sh BenchmarkSamples
```

When the script asks for reference text, paste one line from:

```bash
BenchmarkSamples/reading-prompts.csv
```

Then run the benchmark:

```bash
Scripts/benchmark_asr.py \
  --manifest BenchmarkSamples/manifest.csv \
  --include-fluidaudio \
  --fluidaudio-model-version v2 \
  --fluidaudio-model-version v3 \
  --output BenchmarkResults/real_voice_parakeet.json
```

If whisper.cpp models are installed, the same command also tests the default whisper models that exist in `~/Library/Application Support/LocalVoiceFlow/Models`.

## What To Report

For each failed or awkward dictation, save:

- Target app.
- Prompt ID.
- Exact text Scrivora inserted.
- Whether paste happened automatically or only clipboard fallback worked.
- Whether the profile shown in Debug matched the target app.
