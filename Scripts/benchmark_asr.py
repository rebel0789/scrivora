#!/usr/bin/env python3
import argparse
import csv
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path


def normalize(text: str) -> str:
    text = text.lower()
    text = re.sub(r"[^a-z0-9\s]", " ", text)
    text = re.sub(r"local\s+voice\s+flow", "localvoiceflow", text)
    text = re.sub(r"\s+", " ", text)
    return text.strip()


def edit_distance(hypothesis, reference) -> int:
    if not reference:
        return len(hypothesis)
    if not hypothesis:
        return len(reference)

    previous = list(range(len(reference) + 1))
    current = [0] * (len(reference) + 1)
    for h_index, h_value in enumerate(hypothesis, start=1):
        current[0] = h_index
        for r_index, r_value in enumerate(reference, start=1):
            if h_value == r_value:
                current[r_index] = previous[r_index - 1]
            else:
                current[r_index] = min(
                    previous[r_index] + 1,
                    current[r_index - 1] + 1,
                    previous[r_index - 1] + 1,
                )
        previous, current = current, previous
    return previous[len(reference)]


def score(hypothesis: str, reference: str) -> dict:
    normalized_hypothesis = normalize(hypothesis)
    normalized_reference = normalize(reference)
    hypothesis_words = normalized_hypothesis.split() if normalized_hypothesis else []
    reference_words = normalized_reference.split() if normalized_reference else []
    word_distance = edit_distance(hypothesis_words, reference_words)
    character_distance = edit_distance(list(normalized_hypothesis), list(normalized_reference))
    wer = 0 if not reference_words and not hypothesis_words else (
        1 if not reference_words else word_distance / len(reference_words)
    )
    cer = 0 if not normalized_reference and not normalized_hypothesis else (
        1 if not normalized_reference else character_distance / len(normalized_reference)
    )
    return {
        "normalized_hypothesis": normalized_hypothesis,
        "normalized_reference": normalized_reference,
        "word_edit_distance": word_distance,
        "character_edit_distance": character_distance,
        "wer": wer,
        "cer": cer,
    }


def load_manifest(path: Path) -> list[dict]:
    with path.open(newline="") as handle:
        reader = csv.DictReader(handle)
        required = {"id", "audio", "reference"}
        missing = required - set(reader.fieldnames or [])
        if missing:
            raise SystemExit(f"manifest is missing required columns: {', '.join(sorted(missing))}")
        rows = []
        for row in reader:
            audio = Path(row["audio"]).expanduser()
            if not audio.is_absolute():
                audio = (path.parent / audio).resolve()
            rows.append({
                "id": row["id"],
                "audio": audio,
                "reference": row["reference"],
            })
        return rows


def run_process(command: list[str], timeout: int = 180) -> tuple[str, str, float]:
    started = time.perf_counter()
    completed = subprocess.run(
        command,
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        timeout=timeout,
    )
    elapsed = time.perf_counter() - started
    return completed.stdout.strip(), completed.stderr.strip(), elapsed


def run_command(command: list[str], timeout: int = 180) -> tuple[str, float]:
    stdout, stderr, elapsed = run_process(command, timeout=timeout)
    return (stdout + "\n" + stderr).strip(), elapsed


def run_whisper(sample: dict, model_path: Path, whisper_cli: str) -> tuple[str, float]:
    with tempfile.TemporaryDirectory(prefix="lvf-bench-") as temporary:
        output_base = Path(temporary) / sample["id"]
        command = [
            whisper_cli,
            "-m", str(model_path),
            "-f", str(sample["audio"]),
            "-otxt",
            "-of", str(output_base),
            "-nt",
            "-l", "en",
        ]
        output, elapsed = run_command(command)
        text_file = output_base.with_suffix(".txt")
        if text_file.exists():
            text = text_file.read_text().strip()
        else:
            text = output
        return text, elapsed


def run_parakeet(sample: dict, command_template: str) -> tuple[str, float]:
    with tempfile.TemporaryDirectory(prefix="lvf-parakeet-") as temporary:
        output_dir = Path(temporary)
        command = [
            part.format(audio=str(sample["audio"]), output_dir=str(output_dir))
            for part in command_template.split()
        ]
        output, elapsed = run_command(command, timeout=600)
        text_files = sorted(output_dir.rglob("*.txt"))
        if text_files:
            text = "\n".join(path.read_text().strip() for path in text_files)
        else:
            text = output
        return text.strip(), elapsed


def default_fluidaudio_model_dir(version: str) -> Path:
    folder_by_version = {
        "v2": "parakeet-tdt-0.6b-v2",
        "v3": "parakeet-tdt-0.6b-v3",
        "110m": "parakeet-tdt-ctc-110m",
    }
    folder = folder_by_version.get(version, f"parakeet-{version}")
    return Path("~/Library/Application Support/FluidAudio/Models").expanduser() / folder


def extract_fluidaudio_transcript(stdout: str) -> str:
    stdout = re.sub(
        r"E5RT encountered.*?zero shape error\.?",
        "",
        stdout,
        flags=re.IGNORECASE | re.DOTALL,
    )

    def is_noise(line: str) -> bool:
        lowered = line.lower()
        noise_fragments = [
            "e5rt encountered",
            "failed to propagateinputtensorshapes",
            "zero shape error",
            "processing time:",
            "audio duration:",
            "rtfx:",
            "confidence:",
            "loading model",
            "loaded model",
        ]
        return any(fragment in lowered for fragment in noise_fragments)

    lines = [
        line.strip()
        for line in stdout.splitlines()
        if line.strip() and not is_noise(line.strip())
    ]
    return lines[-1] if lines else ""


def run_fluidaudio(sample: dict, cli_path: str, model_version: str, model_dir: Path) -> tuple[str, float]:
    command = [
        cli_path,
        "transcribe",
        str(sample["audio"]),
        "--model-version", model_version,
        "--model-dir", str(model_dir),
    ]
    stdout, _, elapsed = run_process(command, timeout=600)
    return extract_fluidaudio_transcript(stdout), elapsed


def candidate_engines(args) -> list[dict]:
    engines = []
    model_dir = Path(args.model_dir).expanduser()
    whisper_cli = args.whisper_cli or shutil.which("whisper-cli") or "/opt/homebrew/bin/whisper-cli"
    if Path(whisper_cli).is_file():
        for model_name in args.whisper_model:
            model_path = model_dir / model_name
            if model_path.exists():
                engines.append({
                    "name": f"whisper:{model_name}",
                    "kind": "whisper",
                    "model_path": model_path,
                    "whisper_cli": whisper_cli,
                })
            else:
                print(f"skip whisper:{model_name} missing {model_path}", file=sys.stderr)

    parakeet_command = args.parakeet_command
    if args.include_parakeet:
        if not parakeet_command:
            parakeet_binary = shutil.which("parakeet-mlx")
            if parakeet_binary:
                parakeet_command = f"{parakeet_binary} {{audio}} --output-format txt --output-dir {{output_dir}}"
        if parakeet_command:
            engines.append({
                "name": "parakeet",
                "kind": "parakeet",
                "command": parakeet_command,
            })
        else:
            print("skip parakeet: install parakeet-mlx or pass --parakeet-command", file=sys.stderr)

    if args.include_fluidaudio:
        fluidaudio_cli = (
            args.fluidaudio_cli
            or shutil.which("fluidaudiocli")
            or ("/tmp/FluidAudio/.build/debug/fluidaudiocli" if Path("/tmp/FluidAudio/.build/debug/fluidaudiocli").is_file() else None)
        )
        if not fluidaudio_cli or not Path(fluidaudio_cli).is_file():
            print("skip fluidaudio: pass --fluidaudio-cli or build fluidaudiocli", file=sys.stderr)
        else:
            for model_version in args.fluidaudio_model_version:
                model_dir = (
                    Path(args.fluidaudio_model_dir).expanduser()
                    if args.fluidaudio_model_dir and len(args.fluidaudio_model_version) == 1
                    else default_fluidaudio_model_dir(model_version)
                )
                if not model_dir.exists():
                    print(f"skip fluidaudio:{model_version} missing {model_dir}", file=sys.stderr)
                    continue
                engines.append({
                    "name": f"fluidaudio:{model_version}",
                    "kind": "fluidaudio",
                    "cli": fluidaudio_cli,
                    "model_version": model_version,
                    "model_dir": model_dir,
                })

    return engines


def main() -> int:
    parser = argparse.ArgumentParser(description="Benchmark local ASR engines on a manifest of real voice samples.")
    parser.add_argument("--manifest", required=True, help="CSV with id,audio,reference columns")
    parser.add_argument("--output", default="BenchmarkResults/asr_benchmark.json")
    parser.add_argument("--model-dir", default="~/Library/Application Support/LocalVoiceFlow/Models")
    parser.add_argument("--whisper-cli")
    parser.add_argument(
        "--whisper-model",
        action="append",
        default=[],
        help="Whisper GGML filename to test. Repeatable.",
    )
    parser.add_argument("--include-parakeet", action="store_true")
    parser.add_argument(
        "--parakeet-command",
        help="Command template with {audio}, for example: 'parakeet-mlx {audio} --output-format txt'",
    )
    parser.add_argument("--include-fluidaudio", action="store_true")
    parser.add_argument("--fluidaudio-cli")
    parser.add_argument(
        "--fluidaudio-model-version",
        action="append",
        choices=["v2", "v3", "110m"],
        help="FluidAudio model version to test. Repeatable; defaults to v3.",
    )
    parser.add_argument("--fluidaudio-model-dir")
    args = parser.parse_args()

    if not args.whisper_model:
        args.whisper_model = ["ggml-base.en-q5_1.bin", "ggml-small.en-q5_1.bin"]
    if not args.fluidaudio_model_version:
        args.fluidaudio_model_version = ["v3"]

    samples = load_manifest(Path(args.manifest).expanduser())
    engines = candidate_engines(args)
    if not engines:
        raise SystemExit("no ASR engines available to benchmark")

    output_path = Path(args.output).expanduser()
    output_path.parent.mkdir(parents=True, exist_ok=True)
    results = []
    for engine in engines:
        engine_results = []
        for sample in samples:
            try:
                if engine["kind"] == "whisper":
                    hypothesis, elapsed = run_whisper(sample, engine["model_path"], engine["whisper_cli"])
                elif engine["kind"] == "parakeet":
                    hypothesis, elapsed = run_parakeet(sample, engine["command"])
                else:
                    hypothesis, elapsed = run_fluidaudio(
                        sample,
                        engine["cli"],
                        engine["model_version"],
                        engine["model_dir"],
                    )
                sample_score = score(hypothesis, sample["reference"])
                engine_results.append({
                    "id": sample["id"],
                    "audio": str(sample["audio"]),
                    "reference": sample["reference"],
                    "hypothesis": hypothesis,
                    "latency_seconds": elapsed,
                    **sample_score,
                })
            except Exception as error:
                engine_results.append({
                    "id": sample["id"],
                    "audio": str(sample["audio"]),
                    "reference": sample["reference"],
                    "error": str(error),
                })

        scored = [result for result in engine_results if "wer" in result]
        summary = {
            "engine": engine["name"],
            "sample_count": len(scored),
            "average_wer": sum(result["wer"] for result in scored) / len(scored) if scored else None,
            "average_cer": sum(result["cer"] for result in scored) / len(scored) if scored else None,
            "average_latency_seconds": sum(result["latency_seconds"] for result in scored) / len(scored) if scored else None,
        }
        results.append({"summary": summary, "samples": engine_results})
        print(json.dumps(summary, indent=2))

    output_path.write_text(json.dumps({"engines": results}, indent=2))
    print(f"wrote {output_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
