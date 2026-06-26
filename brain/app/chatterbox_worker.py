from __future__ import annotations

import argparse
import base64
import contextlib
import io
import json
import os
import sys
from pathlib import Path
from typing import Any, Dict, Optional


_MODEL: Any = None
_DEVICE: Optional[str] = None


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--status", action="store_true")
    args = parser.parse_args()
    if args.status:
        return status()
    return serve()


def status() -> int:
    try:
        with contextlib.redirect_stdout(sys.stderr):
            patch_perth_watermarker()
            import chatterbox.tts  # noqa: F401
            import soundfile  # noqa: F401

        print(json.dumps({"importable": True, "device": preferred_device()}), flush=True)
        return 0
    except Exception as exc:
        print(json.dumps({"importable": False, "device": None, "error": str(exc)}), flush=True)
        return 1


def serve() -> int:
    for line in sys.stdin:
        if not line.strip():
            continue
        try:
            request = json.loads(line)
            wav = synthesize(request)
            print(
                json.dumps(
                    {
                        "ok": True,
                        "device": preferred_device(),
                        "wav": base64.b64encode(wav).decode("ascii"),
                    },
                    separators=(",", ":"),
                ),
                flush=True,
            )
        except Exception as exc:
            print(json.dumps({"ok": False, "error": str(exc)}, separators=(",", ":")), flush=True)
    return 0


def synthesize(request: Dict[str, Any]) -> bytes:
    text = " ".join(str(request.get("text", "")).split()).strip()
    if not text:
        raise ValueError("No text was provided for speech synthesis.")

    exaggeration = _clamp(request.get("exaggeration", 0.45), 0.15, 1.20)
    cfg_weight = _clamp(request.get("cfgWeight", 0.50), 0.10, 1.20)
    kwargs: Dict[str, Any] = {"exaggeration": exaggeration, "cfg_weight": cfg_weight}

    reference = str(request.get("referenceAudioPath") or "").strip()
    if reference:
        path = Path(reference).expanduser()
        if not path.exists():
            raise ValueError(f"Chatterbox reference audio was not found: {path}")
        kwargs["audio_prompt_path"] = str(path)

    with contextlib.redirect_stdout(sys.stderr):
        model = model_client()
        samples = model.generate(text, **kwargs)
    samples = as_numpy_audio(samples)
    sample_rate = int(getattr(model, "sr", 24000))
    return wav_bytes(samples, sample_rate)


def model_client() -> Any:
    global _MODEL
    if _MODEL is None:
        with contextlib.redirect_stdout(sys.stderr):
            patch_perth_watermarker()
            from chatterbox.tts import ChatterboxTTS

            _MODEL = ChatterboxTTS.from_pretrained(device=preferred_device())
    return _MODEL


def patch_perth_watermarker() -> None:
    import perth

    if getattr(perth, "PerthImplicitWatermarker", None) is None:
        perth.PerthImplicitWatermarker = perth.DummyWatermarker


def preferred_device() -> str:
    global _DEVICE
    if _DEVICE:
        return _DEVICE

    override = os.environ.get("JARVIS_CHATTERBOX_DEVICE", "").strip().lower()
    if override in {"cpu", "mps", "cuda"}:
        _DEVICE = override
        return _DEVICE

    device = "cpu"
    try:
        with contextlib.redirect_stdout(sys.stderr):
            import torch

        if getattr(torch.backends, "mps", None) is not None and torch.backends.mps.is_available():
            device = "mps"
        elif torch.cuda.is_available():
            device = "cuda"
    except Exception:
        device = "cpu"
    _DEVICE = device
    return _DEVICE


def as_numpy_audio(samples: Any) -> Any:
    if hasattr(samples, "detach"):
        samples = samples.detach()
    if hasattr(samples, "cpu"):
        samples = samples.cpu()
    if hasattr(samples, "squeeze"):
        samples = samples.squeeze()
    if hasattr(samples, "numpy"):
        return samples.numpy()
    return samples


def wav_bytes(samples: Any, sample_rate: int) -> bytes:
    import soundfile as sf

    buffer = io.BytesIO()
    sf.write(buffer, samples, sample_rate, format="WAV")
    return buffer.getvalue()


def _clamp(value: Any, minimum: float, maximum: float) -> float:
    return min(max(float(value), minimum), maximum)


if __name__ == "__main__":
    raise SystemExit(main())
