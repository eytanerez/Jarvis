# Jarvis

Personal macOS 26+ notch assistant built on a vendored Atoll notch shell, with the Jarvis brain/STT/TTS/context services kept as separate modules.

## Build And Run

```sh
./script/build_and_run.sh
./script/build_and_run.sh --verify
```

## Test

```sh
scripts/test.sh
```

## Architecture

- `Atoll/` is the app shell: notch window positioning, tabs, animation, media UI, settings, and fallback behavior.
- `Atoll/DynamicIsland/Jarvis/` is the thin Jarvis presentation bridge and assistant pane.
- `Sources/JarvisCore`, `Sources/JarvisMac`, `Sources/JarvisContext`, and `Sources/JarvisUI` own Jarvis intelligence, capture, speech, actions, and service integration.
- `brain/` remains the FastAPI brain service bundle copied into `Jarvis.app`.

## Notes

- `Option + Space` opens Atoll directly into the Jarvis assistant tab.
- The existing Atoll tabs and UI patterns are preserved.
- API keys are stored in macOS Keychain by the app.
- The Python brain uses `mem0ai` when installed, with a local fallback for development.
- Kokoro remains the default local TTS engine. Chatterbox runs in a separate helper venv because its NumPy requirements conflict with Kokoro:
  `scripts/install_chatterbox.sh`.
