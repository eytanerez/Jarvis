from __future__ import annotations

import os


def main() -> None:
    port = int(os.environ.get("JARVIS_BRAIN_PORT", "8765"))
    try:
        import uvicorn

        uvicorn.run("app.main:app", host="127.0.0.1", port=port, log_level="warning")
    except Exception as exc:
        print(f"[jarvis-brain] FastAPI unavailable, using fallback server: {exc}", flush=True)
        from app.standalone import run

        run(port=port)


if __name__ == "__main__":
    main()
