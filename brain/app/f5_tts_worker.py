from __future__ import annotations

import argparse
import base64
import contextlib
import io
import json
import os
import sys
from importlib.resources import files
from pathlib import Path
from typing import Any, Dict, Optional


_MODEL: Any = None
_DEVICE: Optional[str] = None

DEFAULT_MODEL = "F5TTS_v1_Base"
DEFAULT_REFERENCE_TEXT = "Some call me nature, others call me mother nature."


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
            from f5_tts.api import F5TTS  # noqa: F401
            import soundfile  # noqa: F401

        print(
            json.dumps(
                {
                    "importable": True,
                    "device": preferred_device(),
                    "model": model_name(),
                }
            ),
            flush=True,
        )
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
                        "model": model_name(),
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

    reference_audio = reference_audio_path(str(request.get("referenceAudioPath") or "").strip())
    reference_text = str(request.get("referenceText") or "").strip()
    if not reference_text and not str(request.get("referenceAudioPath") or "").strip():
        reference_text = DEFAULT_REFERENCE_TEXT

    speed = _clamp(request.get("speed", 1.0), 0.5, 1.8)
    cfg_strength = _clamp(request.get("cfgStrength", 2.0), 0.5, 5.0)
    nfe_step = int(_clamp(request.get("nfeStep", 32), 8, 64))

    with contextlib.redirect_stdout(sys.stderr):
        model = model_client()
        wav, sample_rate, _ = model.infer(
            ref_file=reference_audio,
            ref_text=reference_text,
            gen_text=text,
            show_info=lambda *_args, **_kwargs: None,
            progress=None,
            cfg_strength=cfg_strength,
            nfe_step=nfe_step,
            speed=speed,
            seed=None,
        )
    if wav is None:
        raise RuntimeError("F5-TTS generated no audio.")
    return wav_bytes(wav, int(sample_rate))


def model_client() -> Any:
    global _MODEL
    if _MODEL is None:
        with contextlib.redirect_stdout(sys.stderr):
            from f5_tts.api import F5TTS

            _MODEL = F5TTS(
                model=model_name(),
                device=preferred_device(),
                hf_cache_dir=os.environ.get("JARVIS_F5_TTS_HF_CACHE") or None,
            )
    return _MODEL


def model_name() -> str:
    return os.environ.get("JARVIS_F5_TTS_MODEL", DEFAULT_MODEL).strip() or DEFAULT_MODEL


def reference_audio_path(reference: str) -> str:
    if reference:
        path = Path(reference).expanduser()
        if not path.exists():
            raise ValueError(f"F5-TTS reference audio was not found: {path}")
        return str(path)
    return str(files("f5_tts").joinpath("infer/examples/basic/basic_ref_en.wav"))


def preferred_device() -> str:
    global _DEVICE
    if _DEVICE:
        return _DEVICE

    override = os.environ.get("JARVIS_F5_TTS_DEVICE", "").strip().lower()
    if override in {"cpu", "mps", "cuda", "xpu"}:
        _DEVICE = override
        return _DEVICE

    device = "cpu"
    try:
        with contextlib.redirect_stdout(sys.stderr):
            import torch

        if torch.cuda.is_available():
            device = "cuda"
        elif getattr(torch, "xpu", None) is not None and torch.xpu.is_available():
            device = "xpu"
        elif getattr(torch.backends, "mps", None) is not None and torch.backends.mps.is_available():
            device = "mps"
    except Exception:
        device = "cpu"
    _DEVICE = device
    return _DEVICE


def wav_bytes(samples: Any, sample_rate: int) -> bytes:
    import soundfile as sf

    buffer = io.BytesIO()
    sf.write(buffer, samples, sample_rate, format="WAV")
    return buffer.getvalue()


def _clamp(value: Any, minimum: float, maximum: float) -> float:
    return min(max(float(value), minimum), maximum)


if __name__ == "__main__":
    raise SystemExit(main())
