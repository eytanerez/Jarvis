from __future__ import annotations

import hashlib
import io
import base64
import contextlib
import json
import os
import selectors
import subprocess
import threading
import time
import urllib.request
from pathlib import Path
from typing import Any, Dict, Optional


class TTSService:
    MODEL_URL = "https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/kokoro-v1.0.onnx"
    VOICES_URL = "https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/voices-v1.0.bin"

    # Cheap, frequently spoken phrases. They are short enough to be persisted in
    # the on-disk cache on first use, so repeat playback never re-synthesizes.
    COMMON_PHRASES = (
        "Got it.",
        "Done.",
        "Opening Spotify.",
        "One sec.",
        "I can't see that yet.",
    )
    default_f5_idle_seconds = 180  # within the 2-5 minute window
    default_kokoro_idle_seconds = 300
    default_status_ttl_seconds = 20  # cache window for the F5-TTS subprocess probe
    reaper_interval_seconds = 30

    def __init__(self) -> None:
        self.home = Path(os.environ.get("JARVIS_BRAIN_HOME", Path.home() / "Library/Application Support/JarvisNotch"))
        self.kokoro_dir = self.home / "kokoro"
        self.cache_dir = self.kokoro_dir / "cache"
        self.model_path = self.kokoro_dir / "kokoro-v1.0.onnx"
        self.voices_path = self.kokoro_dir / "voices-v1.0.bin"
        self.last_error: Optional[str] = None
        self._kokoro: Any = None
        self._f5: Any = None
        self._f5_device: Optional[str] = None
        self._brain_dir = Path(__file__).resolve().parents[1]
        self._f5_process: Optional[subprocess.Popen[str]] = None
        self._f5_lock = threading.Lock()
        # Telemetry + idle tracking.
        self._last_used: Dict[str, float] = {}
        self._last_engine_used: Optional[str] = None
        self._last_latency_ms: Optional[float] = None
        # Cached F5-TTS subprocess probe so /tts/status never blocks on it.
        self._f5_status_cache: Optional[Dict[str, Any]] = None
        self._f5_status_at: float = 0.0
        self._kokoro_importable_cache: Optional[bool] = None
        # Background reaper that unloads idle engines.
        self._reaper_thread: Optional[threading.Thread] = None
        self._reaper_stop = threading.Event()

    def status(self, force_refresh: bool = False) -> Dict[str, Any]:
        f5_status = self._cached_f5_status(force_refresh=force_refresh)
        # Cheap to do on every poll, and keeps idle heavy engines from lingering.
        self._maybe_unload_idle_engines()
        return {
            "engine": "kokoro",
            "importable": self._kokoro_importable(),
            "modelPresent": self.model_path.exists(),
            "voicesPresent": self.voices_path.exists(),
            "cacheDirectory": str(self.cache_dir),
            "f5TTSImportable": bool(f5_status.get("importable")),
            "f5TTSDevice": f5_status.get("device") or self._f5_device,
            "f5TTSModel": f5_status.get("model"),
            "f5TTSWorkerRunning": self.f5_worker_running(),
            "kokoroLoaded": self._kokoro is not None,
            "lastEngineUsed": self._last_engine_used,
            "lastLatencyMs": self._last_latency_ms,
            "lastError": self.last_error,
        }

    # -- engine lifecycle / idle management --------------------------------

    def f5_worker_running(self) -> bool:
        return bool(self._f5_process and self._f5_process.poll() is None)

    def reaper_running(self) -> bool:
        return bool(self._reaper_thread and self._reaper_thread.is_alive())

    def runtime_snapshot(self) -> Dict[str, Any]:
        """In-memory view for the dashboard. Never runs the subprocess probe."""
        cached = self._f5_status_cache or {}
        engine_loaded = "f5tts" if self._f5 is not None else "kokoro" if self._kokoro is not None else None
        return {
            "engineLoaded": engine_loaded,
            "kokoroLoaded": self._kokoro is not None,
            "f5TTSLoaded": self._f5 is not None,
            "f5TTSWorkerRunning": self.f5_worker_running(),
            "f5TTSImportable": bool(cached.get("importable")) if cached else None,
            "lastEngineUsed": self._last_engine_used,
            "lastLatencyMs": self._last_latency_ms,
        }

    def _mark_used(self, engine: str) -> None:
        self._last_used[engine] = time.monotonic()
        self._last_engine_used = engine
        if engine == "f5tts" and (self.f5_worker_running() or self._f5 is not None):
            self._ensure_reaper()

    def _ensure_reaper(self) -> None:
        if self._reaper_thread and self._reaper_thread.is_alive():
            return
        self._reaper_stop.clear()
        self._reaper_thread = threading.Thread(target=self._reaper_loop, name="jarvis-tts-reaper", daemon=True)
        self._reaper_thread.start()

    def _reaper_loop(self) -> None:
        while not self._reaper_stop.wait(self.reaper_interval_seconds):
            self._maybe_unload_idle_engines()
            if not self._has_reapable_engine():
                break

    def _has_reapable_engine(self) -> bool:
        if self.f5_worker_running() or self._f5 is not None:
            return True
        if self._kokoro is not None and self._kokoro_idle_unload_enabled():
            return True
        return False

    def _maybe_unload_idle_engines(self) -> None:
        now = time.monotonic()
        if self.f5_worker_running() or self._f5 is not None:
            last = self._last_used.get("f5tts")
            if last is not None and (now - last) >= self._f5_idle_timeout():
                self._unload_f5()
        if self._kokoro is not None and self._kokoro_idle_unload_enabled():
            last = self._last_used.get("kokoro")
            if last is not None and (now - last) >= self._kokoro_idle_timeout():
                self._kokoro = None
                print("[jarvis-brain] tts kokoro unloaded after inactivity", flush=True)

    def _unload_f5(self) -> None:
        self._stop_f5_worker()
        self._f5 = None
        print("[jarvis-brain] tts f5tts unloaded after inactivity", flush=True)

    def _f5_idle_timeout(self) -> float:
        default = self._env_float("JARVIS_TTS_CHATTERBOX_IDLE_SECONDS", self.default_f5_idle_seconds, minimum=30.0)
        return self._env_float("JARVIS_TTS_F5_IDLE_SECONDS", default, minimum=30.0)

    def _kokoro_idle_timeout(self) -> float:
        return self._env_float("JARVIS_TTS_KOKORO_IDLE_SECONDS", self.default_kokoro_idle_seconds, minimum=30.0)

    def _kokoro_idle_unload_enabled(self) -> bool:
        return os.environ.get("JARVIS_TTS_KOKORO_IDLE_UNLOAD", "").strip().lower() in {"1", "true", "yes"}

    def _status_ttl_seconds(self) -> float:
        value = self._env_float("JARVIS_TTS_STATUS_TTL_SECONDS", self.default_status_ttl_seconds, minimum=10.0)
        return min(value, 30.0)  # keep within the 10-30s window from Priority 3

    def _env_float(self, name: str, default: float, minimum: float = 0.0) -> float:
        try:
            value = float(os.environ.get(name, str(default)))
        except ValueError:
            return float(default)
        return max(minimum, value)

    def _cached_f5_status(self, force_refresh: bool = False) -> Dict[str, Any]:
        now = time.monotonic()
        if (
            not force_refresh
            and self._f5_status_cache is not None
            and (now - self._f5_status_at) < self._status_ttl_seconds()
        ):
            return self._f5_status_cache
        status = self._f5_status()
        self._f5_status_cache = status
        self._f5_status_at = now
        return status

    def synthesize(
        self,
        text: str,
        voice: str = "af_heart",
        speed: float = 1.0,
        engine: str = "kokoro",
        reference_audio_path: Optional[str] = None,
        reference_text: Optional[str] = None,
        cfg_strength: Optional[float] = None,
        nfe_step: Optional[int] = None,
    ) -> bytes:
        normalized = " ".join(text.split()).strip()
        if not normalized:
            raise ValueError("No text was provided for speech synthesis.")

        engine = (engine or "kokoro").strip().lower()
        if engine == "chatterbox":
            engine = "f5tts"
        if engine in {"f5-tts", "f5_tts"}:
            engine = "f5tts"
        if engine not in {"kokoro", "f5tts"}:
            raise ValueError(f"Unsupported TTS engine: {engine}")

        started = time.perf_counter()
        if engine == "f5tts":
            wav = self._synthesize_f5(
                normalized,
                reference_audio_path=reference_audio_path,
                reference_text=reference_text,
                speed=speed,
                cfg_strength=cfg_strength,
                nfe_step=nfe_step,
            )
        else:
            wav = self._synthesize_kokoro(normalized, voice=voice, speed=speed)
        self._last_latency_ms = (time.perf_counter() - started) * 1000.0
        self._mark_used(engine)
        return wav

    def _synthesize_kokoro(self, normalized: str, voice: str = "af_heart", speed: float = 1.0) -> bytes:
        voice = voice.strip() or "af_heart"
        speed = min(max(float(speed), 0.5), 1.8)
        cache_path = self._cache_path("kokoro", normalized, voice, speed)
        if cache_path.exists():
            return cache_path.read_bytes()

        try:
            started = time.perf_counter()
            self._ensure_assets()
            kokoro = self._kokoro_client()
            samples, sample_rate = kokoro.create(normalized, voice=voice, speed=speed, lang="en-us")
            wav = self._wav_bytes(samples, sample_rate)
            if len(normalized) <= 120:
                cache_path.parent.mkdir(parents=True, exist_ok=True)
                cache_path.write_bytes(wav)
            self.last_error = None
            print(
                f"[jarvis-brain] tts engine=kokoro chars={len(normalized)} "
                f"elapsed={time.perf_counter() - started:.2f}s",
                flush=True,
            )
            return wav
        except Exception as exc:
            self.last_error = str(exc)
            raise

    def _synthesize_f5(
        self,
        normalized: str,
        reference_audio_path: Optional[str],
        reference_text: Optional[str],
        speed: float,
        cfg_strength: Optional[float],
        nfe_step: Optional[int],
    ) -> bytes:
        speed_value = min(max(float(speed), 0.5), 1.8)
        cfg_strength_value = min(max(float(cfg_strength if cfg_strength is not None else 2.0), 0.5), 5.0)
        nfe_step_value = int(min(max(int(nfe_step if nfe_step is not None else 32), 8), 64))
        reference = (reference_audio_path or "").strip()
        if reference:
            path = Path(reference).expanduser()
            if not path.exists():
                raise ValueError(f"F5-TTS reference audio was not found: {path}")
            reference = str(path)
        ref_text = (reference_text or "").strip()
        cache_key = f"{reference}|{ref_text}"
        cache_path = self._cache_path("f5tts", normalized, cache_key, speed_value, cfg_strength_value, nfe_step_value)
        if cache_path.exists():
            return cache_path.read_bytes()

        try:
            started = time.perf_counter()
            if self._should_use_direct_f5():
                wav = self._synthesize_f5_direct(
                    normalized,
                    reference_audio_path=reference,
                    reference_text=ref_text,
                    speed_value=speed_value,
                    cfg_strength_value=cfg_strength_value,
                    nfe_step_value=nfe_step_value,
                )
            else:
                wav = self._synthesize_f5_worker(
                    normalized,
                    reference_audio_path=reference,
                    reference_text=ref_text,
                    speed_value=speed_value,
                    cfg_strength_value=cfg_strength_value,
                    nfe_step_value=nfe_step_value,
                )
            if len(normalized) <= 120:
                cache_path.parent.mkdir(parents=True, exist_ok=True)
                cache_path.write_bytes(wav)
            self.last_error = None
            print(
                f"[jarvis-brain] tts engine=f5tts device={self._f5_device or 'helper'} "
                f"chars={len(normalized)} elapsed={time.perf_counter() - started:.2f}s",
                flush=True,
            )
            return wav
        except Exception as exc:
            self.last_error = str(exc)
            raise

    def _synthesize_f5_direct(
        self,
        normalized: str,
        reference_audio_path: Optional[str],
        reference_text: str,
        speed_value: float,
        cfg_strength_value: float,
        nfe_step_value: int,
    ) -> bytes:
        model = self._f5_client()
        reference = reference_audio_path or self._default_f5_reference_audio()
        if not reference_text and not reference_audio_path:
            reference_text = "Some call me nature, others call me mother nature."
        with contextlib.redirect_stdout(io.StringIO()):
            samples, sample_rate, _ = model.infer(
                ref_file=reference,
                ref_text=reference_text,
                gen_text=normalized,
                show_info=lambda *_args, **_kwargs: None,
                progress=None,
                cfg_strength=cfg_strength_value,
                nfe_step=nfe_step_value,
                speed=speed_value,
                seed=None,
            )
        if samples is None:
            raise RuntimeError("F5-TTS generated no audio.")
        return self._wav_bytes(samples, sample_rate)

    def _synthesize_f5_worker(
        self,
        normalized: str,
        reference_audio_path: Optional[str],
        reference_text: str,
        speed_value: float,
        cfg_strength_value: float,
        nfe_step_value: int,
    ) -> bytes:
        response = self._f5_request(
            {
                "text": normalized,
                "referenceAudioPath": reference_audio_path or "",
                "referenceText": reference_text,
                "speed": speed_value,
                "cfgStrength": cfg_strength_value,
                "nfeStep": nfe_step_value,
            }
        )
        device = response.get("device")
        if isinstance(device, str) and device:
            self._f5_device = device
        wav_text = response.get("wav")
        if not isinstance(wav_text, str):
            raise RuntimeError("F5-TTS worker returned no audio.")
        return base64.b64decode(wav_text)

    def _kokoro_importable(self) -> bool:
        # Importing kokoro_onnx can pull heavy native deps; cache the result so a
        # frequently-polled /tts/status never repeats the import work.
        if self._kokoro_importable_cache is not None:
            return self._kokoro_importable_cache
        try:
            import kokoro_onnx  # noqa: F401
            import soundfile  # noqa: F401
            self._kokoro_importable_cache = True
        except Exception as exc:
            self.last_error = f"Python TTS dependency missing: {exc}"
            self._kokoro_importable_cache = False
        return self._kokoro_importable_cache

    def _f5_importable(self) -> bool:
        return bool(self._cached_f5_status().get("importable"))

    def _f5_status(self) -> Dict[str, Any]:
        python = self._f5_python()
        worker = self._f5_worker_path()
        if python is None:
            return {
                "importable": False,
                "device": None,
                "error": "F5-TTS helper venv is missing. Run scripts/install_f5_tts.sh.",
            }
        if not worker.exists():
            return {"importable": False, "device": None, "error": f"F5-TTS worker is missing: {worker}"}
        try:
            completed = subprocess.run(
                [str(python), str(worker), "--status"],
                cwd=str(self._brain_dir),
                env=self._f5_environment(),
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                timeout=15,
                check=False,
            )
            lines = [line for line in completed.stdout.splitlines() if line.strip()]
            if not lines:
                return {
                    "importable": False,
                    "device": None,
                    "error": completed.stderr.strip() or "F5-TTS helper returned no status.",
                }
            status = json.loads(lines[-1])
            if not status.get("importable") and status.get("error"):
                self.last_error = str(status["error"])
            return status
        except Exception as exc:
            return {"importable": False, "device": None, "error": str(exc)}

    def _ensure_assets(self) -> None:
        self.kokoro_dir.mkdir(parents=True, exist_ok=True)
        if not self.model_path.exists():
            self._download(self.MODEL_URL, self.model_path)
        if not self.voices_path.exists():
            self._download(self.VOICES_URL, self.voices_path)

    def _download(self, url: str, destination: Path) -> None:
        temporary = destination.with_suffix(destination.suffix + ".download")
        with urllib.request.urlopen(url, timeout=120) as response:
            temporary.write_bytes(response.read())
        temporary.replace(destination)

    def _kokoro_client(self) -> Any:
        if self._kokoro is None:
            from kokoro_onnx import Kokoro

            self._kokoro = Kokoro(str(self.model_path), str(self.voices_path))
        return self._kokoro

    def _f5_client(self) -> Any:
        if self._f5 is None:
            from f5_tts.api import F5TTS

            self._f5 = F5TTS(
                model=os.environ.get("JARVIS_F5_TTS_MODEL", "F5TTS_v1_Base").strip() or "F5TTS_v1_Base",
                device=self._preferred_device(),
                hf_cache_dir=os.environ.get("JARVIS_F5_TTS_HF_CACHE") or None,
            )
        return self._f5

    def _should_use_direct_f5(self) -> bool:
        return "_f5_client" in self.__dict__ or os.environ.get("JARVIS_F5_TTS_DIRECT") == "1"

    def _f5_request(self, payload: Dict[str, Any]) -> Dict[str, Any]:
        with self._f5_lock:
            last_error: Optional[BaseException] = None
            for attempt in range(2):
                process = self._ensure_f5_worker()
                try:
                    assert process.stdin is not None
                    process.stdin.write(json.dumps(payload, separators=(",", ":")) + "\n")
                    process.stdin.flush()
                    line = self._read_f5_response(process, timeout=300)
                    response = json.loads(line)
                    if not response.get("ok"):
                        raise RuntimeError(str(response.get("error") or "F5-TTS worker failed."))
                    return response
                except RuntimeError:
                    raise
                except (BrokenPipeError, EOFError, OSError, TimeoutError, json.JSONDecodeError) as exc:
                    last_error = exc
                    self._stop_f5_worker()
                    if attempt == 0:
                        continue
                    raise RuntimeError(f"F5-TTS worker did not respond: {exc}") from exc
            raise RuntimeError(f"F5-TTS worker did not respond: {last_error}")

    def _ensure_f5_worker(self) -> subprocess.Popen[str]:
        if self._f5_process and self._f5_process.poll() is None:
            return self._f5_process

        python = self._f5_python()
        worker = self._f5_worker_path()
        if python is None:
            raise RuntimeError("F5-TTS helper venv is missing. Run scripts/install_f5_tts.sh.")
        if not worker.exists():
            raise RuntimeError(f"F5-TTS worker is missing: {worker}")

        self._f5_process = subprocess.Popen(
            [str(python), "-u", str(worker)],
            cwd=str(self._brain_dir),
            env=self._f5_environment(),
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
            encoding="utf-8",
            bufsize=1,
        )
        return self._f5_process

    def _read_f5_response(self, process: subprocess.Popen[str], timeout: float) -> str:
        if process.stdout is None:
            raise EOFError("F5-TTS worker stdout is not available.")
        selector = selectors.DefaultSelector()
        try:
            selector.register(process.stdout, selectors.EVENT_READ)
            events = selector.select(timeout)
        finally:
            selector.close()
        if not events:
            self._stop_f5_worker()
            raise TimeoutError("F5-TTS synthesis timed out.")
        line = process.stdout.readline()
        if not line:
            raise EOFError("F5-TTS worker exited before returning audio.")
        return line

    def _stop_f5_worker(self) -> None:
        process = self._f5_process
        self._f5_process = None
        if process is None:
            return
        for stream in (process.stdin, process.stdout):
            try:
                if stream:
                    stream.close()
            except Exception:
                pass
        if process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=2)
            except subprocess.TimeoutExpired:
                process.kill()

    def _f5_python(self) -> Optional[Path]:
        override = os.environ.get("JARVIS_F5_TTS_PYTHON", "").strip()
        candidates = []
        if override:
            candidates.append(Path(override).expanduser())
        candidates.extend(
            [
                self._brain_dir / ".venv-f5-tts/bin/python",
                self._brain_dir / ".venv-f5-tts/bin/python3",
            ]
        )
        for path in candidates:
            if path.exists() and os.access(path, os.X_OK):
                return path
        return None

    def _f5_worker_path(self) -> Path:
        return self._brain_dir / "app" / "f5_tts_worker.py"

    def _f5_environment(self) -> Dict[str, str]:
        env = os.environ.copy()
        env["PYTHONUNBUFFERED"] = "1"
        env.setdefault("HF_HOME", str(self.home / "huggingface"))
        env.setdefault("XDG_CACHE_HOME", str(self.home / "cache"))
        return env

    def _preferred_device(self) -> str:
        if self._f5_device:
            return self._f5_device
        override = os.environ.get("JARVIS_F5_TTS_DEVICE", "").strip().lower()
        if override in {"cpu", "mps", "cuda", "xpu"}:
            self._f5_device = override
            return override
        device = "cpu"
        try:
            import torch

            if torch.cuda.is_available():
                device = "cuda"
            elif getattr(torch, "xpu", None) is not None and torch.xpu.is_available():
                device = "xpu"
            elif getattr(torch.backends, "mps", None) is not None and torch.backends.mps.is_available():
                device = "mps"
        except Exception:
            device = "cpu"
        self._f5_device = device
        return device

    def _default_f5_reference_audio(self) -> str:
        from importlib.resources import files

        return str(files("f5_tts").joinpath("infer/examples/basic/basic_ref_en.wav"))

    def _as_numpy_audio(self, samples: Any) -> Any:
        if hasattr(samples, "detach"):
            samples = samples.detach()
        if hasattr(samples, "cpu"):
            samples = samples.cpu()
        if hasattr(samples, "squeeze"):
            samples = samples.squeeze()
        if hasattr(samples, "numpy"):
            return samples.numpy()
        return samples

    def _wav_bytes(self, samples: Any, sample_rate: int) -> bytes:
        import soundfile as sf

        buffer = io.BytesIO()
        sf.write(buffer, samples, sample_rate, format="WAV")
        return buffer.getvalue()

    def _cache_path(self, engine: str, text: str, voice: str, *parameters: Any) -> Path:
        parameter_text = "|".join(str(parameter) for parameter in parameters)
        digest = hashlib.sha256(f"{engine}|{voice}|{parameter_text}|{text}".encode("utf-8")).hexdigest()
        return self.cache_dir / f"{digest}.wav"
