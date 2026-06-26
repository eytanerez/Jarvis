from __future__ import annotations

import os
import platform
import re
from datetime import datetime
from typing import Any, Dict, List, Optional

from .skill import LocalSkill, LocalSkillInvocation, LocalSkillResult


def builtin_local_skills() -> List[LocalSkill]:
    return [
        LocalSkill("time.now", "Current Time", "Answer the current local time instantly.", "green", ["*"], _matches_time, _run_time),
        LocalSkill("date.today", "Today Date", "Answer today's date instantly.", "green", ["*"], _matches_date, _run_date),
        LocalSkill("app.open", "Open App", "Open a macOS application by name.", "green", ["*"], _matches_open_app, _run_open_app),
        LocalSkill("browser.open_url", "Open URL", "Open a website or search query with confirmation.", "yellow", ["*"], _matches_open_url, _run_open_url, True),
        LocalSkill("screenshot.take", "Take Screenshot", "Ask the Mac app to take a screenshot safely.", "yellow", ["*"], _matches_screenshot, _run_screenshot, True),
        LocalSkill("joke.tell", "Tell Joke", "Tell a tiny local joke without a model call.", "green", ["*"], _matches_joke, _run_joke),
        LocalSkill("music.play", "Play Music", "Ask the Mac app to start music playback.", "yellow", ["*"], _matches_music, _run_music, True),
        LocalSkill("assistant.pause_listening", "Pause Listening", "Pause assistant listening.", "green", ["*"], _matches_pause, _run_pause),
        LocalSkill("assistant.resume_listening", "Resume Listening", "Resume assistant listening.", "green", ["*"], _matches_resume, _run_resume),
        LocalSkill("assistant.go_offline", "Go Offline", "Switch assistant into local-only mode.", "yellow", ["*"], _matches_offline, _run_offline, True),
        LocalSkill("system.status", "System Status", "Return lightweight local system status.", "green", ["*"], _matches_system_status, _run_system_status),
        LocalSkill("system.sleep_request", "Sleep Mac", "Request Mac sleep with explicit confirmation.", "red", ["*"], _matches_sleep, _run_sleep, True),
        LocalSkill("system.restart_request", "Restart Mac", "Request Mac restart with explicit confirmation.", "red", ["*"], _matches_restart, _run_restart, True),
        LocalSkill("system.shutdown_request", "Shutdown Mac", "Request Mac shutdown with explicit confirmation.", "red", ["*"], _matches_shutdown, _run_shutdown, True),
    ]


def _matches_time(invocation: LocalSkillInvocation) -> bool:
    return bool(re.search(r"\b(what time is it|current time|time now|tell me the time)\b", invocation.lower))


def _run_time(invocation: LocalSkillInvocation) -> LocalSkillResult:
    now = datetime.now().astimezone()
    text = now.strftime("%-I:%M %p")
    return LocalSkillResult(
        answer=f"It's {text}.",
        speak=f"{text}.",
        metadata={"modelRoute": "local_skill", "why": "time query handled locally", "latencyTargetMs": 1000, "privacyLevel": "local"},
    )


def _matches_date(invocation: LocalSkillInvocation) -> bool:
    return bool(re.search(r"\b(what day is it|what'?s today'?s date|today'?s date|date today|current date)\b", invocation.lower))


def _run_date(invocation: LocalSkillInvocation) -> LocalSkillResult:
    today = datetime.now().astimezone().strftime("%A, %B %-d, %Y")
    return LocalSkillResult(
        answer=f"Today is {today}.",
        speak=today,
        metadata={"modelRoute": "local_skill", "why": "date query handled locally", "privacyLevel": "local"},
    )


def _matches_open_app(invocation: LocalSkillInvocation) -> bool:
    return invocation.lower.startswith(("open ", "launch ", "start ")) and not _looks_like_url_request(invocation.lower)


def _run_open_app(invocation: LocalSkillInvocation) -> LocalSkillResult:
    name = _clean_open_target(invocation.message)
    action = {"id": "open_app", "type": "open_app", "payload": {"name": name}}
    return LocalSkillResult(
        answer=f"Opening {name}.",
        speak=f"Opening {name}.",
        actions=[action],
        metadata={"modelRoute": "local_skill", "why": "open app handled locally"},
    )


def _matches_open_url(invocation: LocalSkillInvocation) -> bool:
    return invocation.lower.startswith(("open ", "go to ", "visit ")) and _looks_like_url_request(invocation.lower)


def _run_open_url(invocation: LocalSkillInvocation) -> LocalSkillResult:
    target = _clean_open_target(invocation.message)
    url = _normalize_url(target)
    action = {"id": "open_url", "type": "open_url", "payload": {"url": url}}
    return _confirmation_result(
        answer=f"I can open {url}.",
        speak="Want me to open it?",
        action=action,
        risk="yellow",
        title="Open website?",
        description=f"Open {url} in your browser.",
        model_route_reason="open URL planned locally",
    )


def _matches_screenshot(invocation: LocalSkillInvocation) -> bool:
    return "screenshot" in invocation.lower or "screen shot" in invocation.lower


def _run_screenshot(invocation: LocalSkillInvocation) -> LocalSkillResult:
    action = {"id": "take_screenshot", "type": "take_screenshot", "payload": {"scope": "screen"}}
    return _confirmation_result(
        answer="I can take a screenshot.",
        speak="Take a screenshot?",
        action=action,
        risk="yellow",
        title="Take screenshot?",
        description="Capture the current screen.",
        model_route_reason="screenshot requires lightweight confirmation",
    )


def _matches_joke(invocation: LocalSkillInvocation) -> bool:
    return "joke" in invocation.lower


def _run_joke(invocation: LocalSkillInvocation) -> LocalSkillResult:
    return LocalSkillResult(
        answer="Why did the function bring a notebook? It wanted to keep its promises.",
        speak="Why did the function bring a notebook? It wanted to keep its promises.",
        metadata={"modelRoute": "local_skill", "why": "simple joke handled locally"},
    )


def _matches_music(invocation: LocalSkillInvocation) -> bool:
    return any(phrase in invocation.lower for phrase in ["play music", "start music", "resume music"])


def _run_music(invocation: LocalSkillInvocation) -> LocalSkillResult:
    action = {"id": "music_play", "type": "music_play", "payload": {}}
    return _confirmation_result(
        answer="I can start playback.",
        speak="Start music?",
        action=action,
        risk="yellow",
        title="Play music?",
        description="Ask the Mac app to start media playback.",
        model_route_reason="music command planned locally",
    )


def _matches_pause(invocation: LocalSkillInvocation) -> bool:
    return invocation.lower in {"pause listening", "stop listening", "pause jarvis"}


def _run_pause(invocation: LocalSkillInvocation) -> LocalSkillResult:
    action = {"id": "assistant_pause_listening", "type": "assistant_pause_listening", "payload": {}}
    return LocalSkillResult("Paused listening.", speak="Paused.", actions=[action], metadata={"modelRoute": "local_skill"})


def _matches_resume(invocation: LocalSkillInvocation) -> bool:
    return invocation.lower in {"resume listening", "start listening", "resume jarvis"}


def _run_resume(invocation: LocalSkillInvocation) -> LocalSkillResult:
    action = {"id": "assistant_resume_listening", "type": "assistant_resume_listening", "payload": {}}
    return LocalSkillResult("Listening is back on.", speak="I'm listening.", actions=[action], metadata={"modelRoute": "local_skill"})


def _matches_offline(invocation: LocalSkillInvocation) -> bool:
    return any(phrase in invocation.lower for phrase in ["go offline", "local only", "offline mode"])


def _run_offline(invocation: LocalSkillInvocation) -> LocalSkillResult:
    action = {"id": "assistant_go_offline", "type": "assistant_go_offline", "payload": {"localOnly": True}}
    return _confirmation_result(
        answer="I can switch to local-only mode.",
        speak="Switch to local-only mode?",
        action=action,
        risk="yellow",
        title="Go offline?",
        description="Stop cloud model routing until you turn it back on.",
        model_route_reason="privacy mode change requires confirmation",
    )


def _matches_system_status(invocation: LocalSkillInvocation) -> bool:
    return any(phrase in invocation.lower for phrase in ["system status", "how is my mac", "battery status", "memory usage", "cpu usage"])


def _run_system_status(invocation: LocalSkillInvocation) -> LocalSkillResult:
    load = _load_average()
    bits = [f"macOS host: {platform.node() or 'this Mac'}", f"Python brain PID: {os.getpid()}"]
    if load:
        bits.append(f"Load average: {load}")
    answer = "System status:\n" + "\n".join(f"- {bit}" for bit in bits)
    return LocalSkillResult(answer=answer, speak="System status is available.", metadata={"modelRoute": "local_skill", "why": "system status handled locally"})


def _matches_sleep(invocation: LocalSkillInvocation) -> bool:
    return "sleep" in invocation.lower and any(word in invocation.lower for word in ["mac", "computer", "system"])


def _run_sleep(invocation: LocalSkillInvocation) -> LocalSkillResult:
    return _red_system_confirmation("sleep_mac", "sleep", "Put Mac to sleep?", "Put this Mac to sleep.")


def _matches_restart(invocation: LocalSkillInvocation) -> bool:
    return "restart" in invocation.lower and any(word in invocation.lower for word in ["mac", "computer", "system"])


def _run_restart(invocation: LocalSkillInvocation) -> LocalSkillResult:
    return _red_system_confirmation("restart_mac", "restart", "Restart Mac?", "Restart this Mac.", typed=True)


def _matches_shutdown(invocation: LocalSkillInvocation) -> bool:
    return any(word in invocation.lower for word in ["shutdown", "shut down", "power off"]) and any(word in invocation.lower for word in ["mac", "computer", "system"])


def _run_shutdown(invocation: LocalSkillInvocation) -> LocalSkillResult:
    return _red_system_confirmation("shutdown_mac", "shutdown", "Shut down Mac?", "Shut down this Mac.", typed=True)


def _red_system_confirmation(action_type: str, command: str, title: str, description: str, typed: bool = False) -> LocalSkillResult:
    action = {"id": action_type, "type": action_type, "payload": {}}
    return _confirmation_result(
        answer=f"I can {command} your Mac after confirmation.",
        speak=f"Confirm {command}?",
        action=action,
        risk="red",
        title=title,
        description=description,
        model_route_reason="red system action requires explicit confirmation",
        typed=typed,
    )


def _confirmation_result(
    answer: str,
    speak: str,
    action: Dict[str, Any],
    risk: str,
    title: str,
    description: str,
    model_route_reason: str,
    typed: bool = False,
) -> LocalSkillResult:
    return LocalSkillResult(
        answer=answer,
        speak=speak,
        actions=[action],
        requires_confirmation=True,
        confirmation={
            "id": f"confirm_{action['id']}",
            "risk": risk,
            "title": title,
            "description": description,
            "action": action,
            "requiresTypedConfirmation": typed,
        },
        metadata={"modelRoute": "local_skill", "why": model_route_reason},
    )


def _looks_like_url_request(lower: str) -> bool:
    return bool(re.search(r"https?://|www\.|\.com\b|\.org\b|\.net\b|\.io\b|website|site|url", lower))


def _clean_open_target(message: str) -> str:
    text = re.sub(r"^(open|launch|start|go to|visit)\s+", "", message.strip(), flags=re.IGNORECASE)
    text = re.sub(r"\b(website|site|url)\b", "", text, flags=re.IGNORECASE)
    return text.strip(" .") or "that"


def _normalize_url(target: str) -> str:
    value = target.strip()
    if value.startswith(("http://", "https://")):
        return value
    if value.startswith("www."):
        return f"https://{value}"
    if "." in value and " " not in value:
        return f"https://{value}"
    query = re.sub(r"\s+", "+", value)
    return f"https://www.google.com/search?q={query}"


def _load_average() -> Optional[str]:
    try:
        values = os.getloadavg()
    except (AttributeError, OSError):
        return None
    return ", ".join(f"{value:.2f}" for value in values)
