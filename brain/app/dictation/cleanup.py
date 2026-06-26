from __future__ import annotations

import re


class DictationCleanup:
    FILLERS = re.compile(r"\b(um+|uh+|erm|like|you know)\b[, ]*", re.IGNORECASE)

    def clean(self, text: str) -> str:
        cleaned = self.FILLERS.sub("", text or "")
        cleaned = self._apply_corrections(cleaned)
        cleaned = self._normalize_time_words(cleaned)
        cleaned = self._spoken_extensions(cleaned)
        cleaned = self._spoken_punctuation(cleaned)
        cleaned = self._spoken_emojis(cleaned)
        cleaned = re.sub(r"\s+", " ", cleaned).strip()
        if cleaned:
            cleaned = cleaned[0].upper() + cleaned[1:]
        return cleaned

    def _apply_corrections(self, text: str) -> str:
        # Handles simple "no X" self-correction by keeping the later phrase.
        time_words = r"(?:one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|\d{1,2})"
        text = re.sub(
            rf"\b(at\s+)?{time_words}\s*(?:am|pm)\s+no\s+({time_words}\s*(?:am|pm))\b",
            lambda match: f"{match.group(1) or ''}{match.group(2)}",
            text,
            flags=re.IGNORECASE,
        )
        return re.sub(r"\b(no|scratch that|correction)\s+", "", text, flags=re.IGNORECASE)

    def _normalize_time_words(self, text: str) -> str:
        numbers = {
            "one": "1",
            "two": "2",
            "three": "3",
            "four": "4",
            "five": "5",
            "six": "6",
            "seven": "7",
            "eight": "8",
            "nine": "9",
            "ten": "10",
            "eleven": "11",
            "twelve": "12",
        }

        def replace(match: re.Match[str]) -> str:
            hour = numbers.get(match.group(1).lower(), match.group(1))
            return f"{hour} {match.group(2).upper()}"

        return re.sub(r"\b(one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|\d{1,2})\s*(am|pm)\b", replace, text, flags=re.IGNORECASE)

    def _spoken_extensions(self, text: str) -> str:
        replacements = {
            " dot md": ".md",
            " dot txt": ".txt",
            " dot py": ".py",
            " dot swift": ".swift",
            " dot json": ".json",
            " dot com": ".com",
        }
        result = text
        for spoken, symbol in replacements.items():
            result = re.sub(re.escape(spoken), symbol, result, flags=re.IGNORECASE)
        return result

    def _spoken_punctuation(self, text: str) -> str:
        replacements = {
            " comma": ",",
            " period": ".",
            " full stop": ".",
            " question mark": "?",
            " exclamation point": "!",
            " colon": ":",
            " semicolon": ";",
            " new line": "\n",
            " new paragraph": "\n\n",
        }
        result = text
        for spoken, symbol in replacements.items():
            result = re.sub(re.escape(spoken), symbol, result, flags=re.IGNORECASE)
        return result

    def _spoken_emojis(self, text: str) -> str:
        replacements = {
            "smiley face": ":)",
            "heart emoji": "<3",
            "thumbs up emoji": "+1",
        }
        result = text
        for spoken, symbol in replacements.items():
            result = re.sub(re.escape(spoken), symbol, result, flags=re.IGNORECASE)
        return result
