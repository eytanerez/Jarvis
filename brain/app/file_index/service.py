from __future__ import annotations

import csv
import hashlib
import json
import mimetypes
import os
import re
import subprocess
import threading
import time
import zipfile
from datetime import datetime, timezone
from fnmatch import fnmatch
from html.parser import HTMLParser
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional
import xml.etree.ElementTree as ET


class _HTMLTextExtractor(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self._ignored: List[str] = []
        self.parts: List[str] = []

    def handle_starttag(self, tag: str, attrs: List[tuple[str, Optional[str]]]) -> None:
        if tag.lower() in {"script", "style", "noscript", "svg", "canvas"}:
            self._ignored.append(tag.lower())

    def handle_endtag(self, tag: str) -> None:
        if self._ignored and self._ignored[-1] == tag.lower():
            self._ignored.pop()

    def handle_data(self, data: str) -> None:
        if not self._ignored:
            text = " ".join(data.split())
            if text:
                self.parts.append(text)


class FileIndexService:
    preview_limit = 24_000
    max_file_bytes = 12 * 1024 * 1024
    supported_extensions = {
        ".txt",
        ".md",
        ".rtf",
        ".pdf",
        ".docx",
        ".html",
        ".htm",
        ".csv",
        ".json",
        ".swift",
        ".py",
        ".js",
        ".ts",
    }
    default_exclusions = [
        ".*",
        ".env",
        "*.env",
        "*.pem",
        "*.key",
        "id_rsa",
        "id_ed25519",
        "secrets.*",
        "credentials.*",
        "node_modules",
        ".git",
        "build",
        ".build",
        "DerivedData",
        "__pycache__",
        ".venv",
        "venv",
        "Library/Caches",
    ]

    def __init__(self) -> None:
        self.home = Path(os.environ.get("JARVIS_BRAIN_HOME", Path.home() / "Library/Application Support/JarvisNotch"))
        self.home.mkdir(parents=True, exist_ok=True)
        self.index_path = self.home / "file_index.json"
        self.lock = threading.RLock()
        self.currently_indexing = False
        self.watching = False
        self.failed_files: List[str] = []
        self._watch_thread: Optional[threading.Thread] = None
        self._stop_event = threading.Event()
        self._index: Dict[str, Dict[str, Any]] = self._load_index()

    def start(self, folders: Optional[List[str]] = None, exclusions: Optional[List[str]] = None) -> Dict[str, Any]:
        if folders:
            os.environ["JARVIS_FILE_INDEX_APPROVED_FOLDERS"] = "\n".join(folders)
        if exclusions:
            os.environ["JARVIS_FILE_INDEX_EXCLUSIONS"] = "\n".join(exclusions)
        if not self.enabled:
            return self.status()
        if self.watching:
            return self.status()
        self.watching = True
        self._stop_event.clear()
        self._watch_thread = threading.Thread(target=self._watch_loop, name="jarvis-file-index", daemon=True)
        self._watch_thread.start()
        return self.status()

    def stop(self) -> Dict[str, Any]:
        self.watching = False
        self._stop_event.set()
        return self.status()

    def reindex(self, folders: Optional[List[str]] = None, exclusions: Optional[List[str]] = None) -> Dict[str, Any]:
        if folders:
            os.environ["JARVIS_FILE_INDEX_APPROVED_FOLDERS"] = "\n".join(folders)
        if exclusions:
            os.environ["JARVIS_FILE_INDEX_EXCLUSIONS"] = "\n".join(exclusions)
        if not self.enabled:
            return self.status()

        with self.lock:
            self.currently_indexing = True
            self.failed_files = []
        try:
            indexed: Dict[str, Dict[str, Any]] = {}
            for folder in self.approved_folders:
                if not folder.exists() or not folder.is_dir():
                    continue
                for path in self._walk(folder):
                    item = self._index_file(path)
                    if item is not None:
                        indexed[item["id"]] = item
            with self.lock:
                self._index = indexed
                self._save_index()
        finally:
            with self.lock:
                self.currently_indexing = False
        return self.status()

    def status(self) -> Dict[str, Any]:
        with self.lock:
            last_index_time = self._last_index_time()
            storage_size = self.index_path.stat().st_size if self.index_path.exists() else 0
            return {
                "indexedFolders": [str(folder) for folder in self.approved_folders],
                "fileCount": len(self._index),
                "lastIndexTime": self._iso(last_index_time) if last_index_time else None,
                "currentlyIndexing": self.currently_indexing,
                "watching": self.watching,
                "failedFiles": self.failed_files[:50],
                "storageSize": storage_size,
                "embeddingBackend": "none_mvp",
            }

    def search(
        self,
        query: str = "",
        limit: int = 8,
        folders: Optional[List[str]] = None,
        extensions: Optional[List[str]] = None,
        modified_after: Optional[datetime] = None,
        modified_before: Optional[datetime] = None,
        created_after: Optional[datetime] = None,
        created_before: Optional[datetime] = None,
    ) -> List[Dict[str, Any]]:
        terms = [term for term in re.findall(r"[A-Za-z0-9_'-]+", query.lower()) if len(term) > 1]
        folder_filters = [str(Path(folder).expanduser()) for folder in folders or []]
        extension_filters = {self._normalize_extension(ext) for ext in extensions or []}
        scored: List[tuple[float, str, Dict[str, Any]]] = []

        with self.lock:
            items = list(self._index.values())

        for item in items:
            if not self._matches_filters(
                item,
                folder_filters,
                extension_filters,
                modified_after,
                modified_before,
                created_after,
                created_before,
            ):
                continue
            score = self._score(item, terms)
            if terms and score <= 0:
                continue
            result = dict(item)
            result["score"] = score
            scored.append((score, item.get("modifiedAt") or "", result))

        scored.sort(key=lambda row: (row[0], row[1]), reverse=True)
        return [item for _, _, item in scored[: max(1, min(limit, 50))]]

    def read(self, file_id: Optional[str] = None, path: Optional[str] = None, max_chars: int = 24_000) -> Dict[str, Any]:
        item = self._find_item(file_id=file_id, path=path)
        if item is None:
            raise FileNotFoundError("File is not indexed or is outside approved folders.")
        file_path = Path(item["path"])
        if not self._is_allowed_path(file_path):
            raise PermissionError("File is outside approved folders or matches an exclusion.")
        text = self._extract_text(file_path) or ""
        limit = max(1, min(max_chars, 120_000))
        return {
            "file": item,
            "content": text[:limit],
            "truncated": len(text) > limit,
        }

    def summarize(self, file_id: Optional[str] = None, path: Optional[str] = None, max_chars: int = 24_000) -> Dict[str, Any]:
        read = self.read(file_id=file_id, path=path, max_chars=max_chars)
        content = read["content"]
        sentences = re.split(r"(?<=[.!?])\s+", " ".join(content.split()))
        summary = " ".join(sentences[:5]).strip()
        if not summary:
            summary = content[:600].strip()
        return {
            "file": read["file"],
            "summary": summary,
            "truncated": read["truncated"],
            "summaryBackend": "local_extractive_mvp",
        }

    @property
    def enabled(self) -> bool:
        return os.environ.get("JARVIS_FILE_INDEX_ENABLED", "1") != "0"

    @property
    def approved_folders(self) -> List[Path]:
        configured = [line.strip() for line in os.environ.get("JARVIS_FILE_INDEX_APPROVED_FOLDERS", "").splitlines() if line.strip()]
        if not configured:
            home = Path.home()
            configured = [str(home / "Desktop"), str(home / "Documents"), str(home / "Downloads")]
        folders: List[Path] = []
        for value in configured:
            path = Path(value).expanduser()
            try:
                resolved = path.resolve()
            except OSError:
                resolved = path
            if self._folder_is_safe(resolved):
                folders.append(resolved)
        return folders

    @property
    def exclusions(self) -> List[str]:
        configured = [line.strip() for line in os.environ.get("JARVIS_FILE_INDEX_EXCLUSIONS", "").splitlines() if line.strip()]
        merged = list(dict.fromkeys(self.default_exclusions + configured))
        return merged

    def _watch_loop(self) -> None:
        self.reindex()
        while not self._stop_event.wait(30):
            self.reindex()

    def _walk(self, folder: Path) -> Iterable[Path]:
        for root, dirs, files in os.walk(folder):
            root_path = Path(root)
            dirs[:] = [name for name in dirs if not self._is_excluded(root_path / name)]
            for filename in files:
                path = root_path / filename
                if not self._is_excluded(path):
                    yield path

    def _index_file(self, path: Path) -> Optional[Dict[str, Any]]:
        try:
            if not path.is_file() or path.suffix.lower() not in self.supported_extensions:
                return None
            stat = path.stat()
            if stat.st_size > self.max_file_bytes:
                self._record_failure(path, "too_large")
                return None
            text = self._extract_text(path)
            if text is None:
                self._record_failure(path, "no_text")
                return None
            now = datetime.now(timezone.utc)
            created = datetime.fromtimestamp(getattr(stat, "st_birthtime", stat.st_ctime), tz=timezone.utc)
            modified = datetime.fromtimestamp(stat.st_mtime, tz=timezone.utc)
            mime_type, _ = mimetypes.guess_type(str(path))
            return {
                "id": hashlib.sha256(str(path).encode("utf-8")).hexdigest(),
                "path": str(path),
                "filename": path.name,
                "extension": path.suffix.lower().lstrip("."),
                "mimeType": mime_type,
                "createdAt": self._iso(created),
                "modifiedAt": self._iso(modified),
                "lastIndexedAt": self._iso(now),
                "textPreview": text[: self.preview_limit],
                "embedding": None,
                "tags": [],
                "source": "local_file",
            }
        except Exception as exc:
            self._record_failure(path, str(exc))
            return None

    def _extract_text(self, path: Path) -> Optional[str]:
        suffix = path.suffix.lower()
        if suffix in {".txt", ".md", ".swift", ".py", ".js", ".ts", ".json"}:
            return self._read_text(path)
        if suffix == ".csv":
            return self._read_csv(path)
        if suffix in {".html", ".htm"}:
            return self._read_html(path)
        if suffix == ".rtf":
            return self._read_rtf(path)
        if suffix == ".docx":
            return self._read_docx(path)
        if suffix == ".pdf":
            return self._read_pdf(path)
        return None

    def _read_text(self, path: Path) -> Optional[str]:
        data = path.read_bytes()
        for encoding in ("utf-8", "utf-16", "latin-1"):
            try:
                return data.decode(encoding, errors="ignore")
            except Exception:
                continue
        return None

    def _read_csv(self, path: Path) -> Optional[str]:
        text = self._read_text(path)
        if text is None:
            return None
        rows = []
        for row in csv.reader(text.splitlines()):
            rows.append(" | ".join(row))
            if len(rows) >= 300:
                break
        return "\n".join(rows)

    def _read_html(self, path: Path) -> Optional[str]:
        html = self._read_text(path)
        if html is None:
            return None
        parser = _HTMLTextExtractor()
        parser.feed(html)
        return "\n".join(parser.parts)

    def _read_rtf(self, path: Path) -> Optional[str]:
        textutil = Path("/usr/bin/textutil")
        if not textutil.exists():
            return self._read_text(path)
        result = subprocess.run(
            [str(textutil), "-convert", "txt", "-stdout", str(path)],
            capture_output=True,
            text=True,
            timeout=10,
            check=False,
        )
        if result.returncode != 0:
            return None
        return result.stdout

    def _read_docx(self, path: Path) -> Optional[str]:
        ns = {"w": "http://schemas.openxmlformats.org/wordprocessingml/2006/main"}
        parts: List[str] = []
        with zipfile.ZipFile(path) as archive:
            xml = archive.read("word/document.xml")
        root = ET.fromstring(xml)
        for paragraph in root.findall(".//w:p", ns):
            texts = [node.text or "" for node in paragraph.findall(".//w:t", ns)]
            text = "".join(texts).strip()
            if text:
                parts.append(text)
        return "\n".join(parts)

    def _read_pdf(self, path: Path) -> Optional[str]:
        try:
            from pypdf import PdfReader  # type: ignore

            reader = PdfReader(str(path))
            return "\n".join((page.extract_text() or "").strip() for page in reader.pages).strip()
        except Exception:
            pdftotext = shutil_which("pdftotext")
            if not pdftotext:
                return None
            result = subprocess.run(
                [pdftotext, str(path), "-"],
                capture_output=True,
                text=True,
                timeout=20,
                check=False,
            )
            if result.returncode != 0:
                return None
            return result.stdout

    def _matches_filters(
        self,
        item: Dict[str, Any],
        folders: List[str],
        extensions: set[str],
        modified_after: Optional[datetime],
        modified_before: Optional[datetime],
        created_after: Optional[datetime],
        created_before: Optional[datetime],
    ) -> bool:
        path = item.get("path", "")
        if folders and not any(path.startswith(folder) for folder in folders):
            return False
        if extensions and f".{item.get('extension', '')}" not in extensions:
            return False
        modified = self._parse_dt(item.get("modifiedAt"))
        created = self._parse_dt(item.get("createdAt"))
        if modified_after and (modified is None or modified < self._aware(modified_after)):
            return False
        if modified_before and (modified is None or modified > self._aware(modified_before)):
            return False
        if created_after and (created is None or created < self._aware(created_after)):
            return False
        if created_before and (created is None or created > self._aware(created_before)):
            return False
        return True

    def _score(self, item: Dict[str, Any], terms: List[str]) -> float:
        if not terms:
            return 0.0
        filename = str(item.get("filename", "")).lower()
        preview = str(item.get("textPreview", "")).lower()
        score = 0.0
        for term in terms:
            if term in filename:
                score += 4.0
            if term in preview:
                score += min(6.0, preview.count(term) * 0.75)
        query = " ".join(terms)
        if query and query in preview:
            score += 5.0
        return score

    def _find_item(self, file_id: Optional[str], path: Optional[str]) -> Optional[Dict[str, Any]]:
        with self.lock:
            if file_id and file_id in self._index:
                return dict(self._index[file_id])
            if path:
                normalized = str(Path(path).expanduser())
                for item in self._index.values():
                    if item.get("path") == normalized:
                        return dict(item)
        return None

    def _is_allowed_path(self, path: Path) -> bool:
        try:
            resolved = path.expanduser().resolve()
        except OSError:
            return False
        return any(self._is_relative_to(resolved, folder) for folder in self.approved_folders) and not self._is_excluded(resolved)

    def _folder_is_safe(self, folder: Path) -> bool:
        try:
            resolved = folder.resolve()
        except OSError:
            resolved = folder
        if resolved == Path("/"):
            return False
        system_roots = [
            Path("/System"),
            Path("/Library"),
            Path("/usr"),
            Path("/bin"),
            Path("/sbin"),
            Path("/private/etc"),
            Path("/private/var/db"),
            Path("/private/var/root"),
        ]
        if any(self._is_relative_to(resolved, root) for root in system_roots):
            return False
        return True

    def _is_excluded(self, path: Path) -> bool:
        name = path.name
        path_string = str(path)
        relative_matches = [name, path_string]
        for pattern in self.exclusions:
            if fnmatch(name, pattern) or any(fnmatch(value, pattern) for value in relative_matches):
                return True
            if pattern in path.parts:
                return True
        return False

    def _normalize_extension(self, extension: str) -> str:
        stripped = extension.strip().lower()
        return stripped if stripped.startswith(".") else f".{stripped}"

    def _load_index(self) -> Dict[str, Dict[str, Any]]:
        if not self.index_path.exists():
            return {}
        try:
            data = json.loads(self.index_path.read_text(encoding="utf-8"))
            if isinstance(data, dict):
                items = data.get("files", [])
            else:
                items = data
            return {str(item["id"]): item for item in items if isinstance(item, dict) and item.get("id")}
        except Exception:
            return {}

    def _save_index(self) -> None:
        payload = {
            "version": 1,
            "savedAt": self._iso(datetime.now(timezone.utc)),
            "files": list(self._index.values()),
        }
        temp_path = self.index_path.with_suffix(".tmp")
        temp_path.write_text(json.dumps(payload, indent=2), encoding="utf-8")
        temp_path.replace(self.index_path)

    def _last_index_time(self) -> Optional[datetime]:
        times = [self._parse_dt(item.get("lastIndexedAt")) for item in self._index.values()]
        valid = [value for value in times if value is not None]
        return max(valid) if valid else None

    def _record_failure(self, path: Path, reason: str) -> None:
        entry = f"{path}: {reason}"
        with self.lock:
            self.failed_files.append(entry)
            if len(self.failed_files) > 100:
                self.failed_files = self.failed_files[-100:]

    def _parse_dt(self, value: Any) -> Optional[datetime]:
        if not value:
            return None
        try:
            text = str(value)
            if text.endswith("Z"):
                text = text[:-1] + "+00:00"
            return datetime.fromisoformat(text)
        except Exception:
            return None

    def _aware(self, value: datetime) -> datetime:
        if value.tzinfo is None:
            return value.replace(tzinfo=timezone.utc)
        return value

    def _iso(self, value: datetime) -> str:
        return value.astimezone(timezone.utc).isoformat().replace("+00:00", "Z")

    def _is_relative_to(self, path: Path, parent: Path) -> bool:
        try:
            path.relative_to(parent)
            return True
        except ValueError:
            return False


def shutil_which(command: str) -> Optional[str]:
    paths = os.environ.get("PATH", "").split(os.pathsep)
    for folder in paths:
        candidate = Path(folder) / command
        if candidate.exists() and os.access(candidate, os.X_OK):
            return str(candidate)
    return None
