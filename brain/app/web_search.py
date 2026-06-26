from __future__ import annotations

import os
from typing import Any, Dict, List, Optional


class WebSearchUnavailable(RuntimeError):
    """Raised when a real-provider web search is attempted but fails."""


class WebSearch:
    @property
    def mode(self) -> str:
        mode = os.environ.get("JARVIS_WEB_SEARCH_MODE", "demo").strip().lower()
        if mode in {"disabled", "demo", "real_provider"}:
            return mode
        return "demo"

    @property
    def real_provider_configured(self) -> bool:
        """True when a real search endpoint + key are available to call."""
        return bool(self._provider_endpoint() and self._provider_key())

    def search(self, query: str, limit: int = 5) -> List[Dict[str, Any]]:
        """Dispatch on ``self.mode`` instead of always returning demo links.

        - ``disabled``: no results.
        - ``demo``: the canned shortcut links (clearly labelled as demo).
        - ``real_provider``: a live HTTP search when one is configured; returns
          [] if not configured, and raises ``WebSearchUnavailable`` if the
          configured provider request itself fails.
        """
        mode = self.mode
        if mode == "disabled":
            return []
        if mode == "real_provider":
            return self._real_provider_search(query, limit)
        return self._demo_search(query, limit)

    # -- real provider -------------------------------------------------------

    def _real_provider_search(self, query: str, limit: int) -> List[Dict[str, Any]]:
        endpoint = self._provider_endpoint()
        key = self._provider_key()
        if not endpoint or not key:
            # Not configured: let the caller decide how to message it.
            return []
        try:
            import httpx
        except Exception as exc:  # pragma: no cover - httpx ships with the brain
            raise WebSearchUnavailable(f"httpx is unavailable: {exc}") from exc

        header_name = os.environ.get("JARVIS_WEB_SEARCH_API_KEY_HEADER", "X-Subscription-Token").strip() or "X-Subscription-Token"
        query_param = os.environ.get("JARVIS_WEB_SEARCH_QUERY_PARAM", "q").strip() or "q"
        try:
            with httpx.Client(timeout=15) as client:
                response = client.get(
                    endpoint,
                    params={query_param: query},
                    headers={header_name: key, "Accept": "application/json"},
                )
                response.raise_for_status()
                data = response.json()
        except Exception as exc:
            raise WebSearchUnavailable(f"Real web search request failed: {exc}") from exc
        return self._normalize(data, query, limit)

    def _provider_endpoint(self) -> str:
        return os.environ.get("JARVIS_WEB_SEARCH_API_URL", "").strip()

    def _provider_key(self) -> str:
        return os.environ.get("JARVIS_WEB_SEARCH_API_KEY", "").strip()

    def _normalize(self, data: Any, query: str, limit: int) -> List[Dict[str, Any]]:
        results: List[Dict[str, Any]] = []
        for index, item in enumerate(self._extract_items(data)[:limit], start=1):
            url = item.get("url") or item.get("link") or item.get("href")
            if not url:
                continue
            name = item.get("title") or item.get("name") or url
            reason = (
                item.get("description")
                or item.get("snippet")
                or item.get("content")
                or item.get("reason")
                or ""
            )
            results.append(
                {
                    "id": f"result_{index}",
                    "rank": index,
                    "name": str(name),
                    "url": str(url),
                    "reason": str(reason),
                    "metadata": {"query": query, "source": "real_provider"},
                }
            )
        return results

    def _extract_items(self, data: Any) -> List[Dict[str, Any]]:
        """Pull the result list out of common search-API response shapes."""
        if isinstance(data, list):
            return [item for item in data if isinstance(item, dict)]
        if not isinstance(data, dict):
            return []
        # Brave: {"web": {"results": [...]}}
        web = data.get("web")
        if isinstance(web, dict) and isinstance(web.get("results"), list):
            return [item for item in web["results"] if isinstance(item, dict)]
        # Tavily / generic: {"results": [...]}; SerpAPI: {"organic_results": [...]};
        # Google CSE: {"items": [...]}.
        for key in ("results", "organic_results", "items", "data"):
            node = data.get(key)
            if isinstance(node, list):
                return [item for item in node if isinstance(item, dict)]
        return []

    # -- demo ----------------------------------------------------------------

    def _demo_search(self, query: str, limit: int) -> List[Dict[str, Any]]:
        lower = query.lower()
        if "ipad" in lower:
            return self._ipad_results()[:limit]
        return [
            {
                "id": f"result_{index}",
                "rank": index,
                "name": name,
                "url": url,
                "reason": reason,
                "metadata": {"query": query},
            }
            for index, (name, url, reason) in enumerate(
                [
                    ("Google Search", f"https://www.google.com/search?q={query.replace(' ', '+')}", "General web search."),
                    ("Perplexity", f"https://www.perplexity.ai/search?q={query.replace(' ', '+')}", "Useful research answer engine."),
                    ("DuckDuckGo", f"https://duckduckgo.com/?q={query.replace(' ', '+')}", "Privacy-focused search results."),
                ],
                start=1,
            )
        ][:limit]

    def _ipad_results(self) -> List[Dict[str, Any]]:
        return [
            {
                "id": "result_1",
                "rank": 1,
                "name": "Apple",
                "url": "https://www.apple.com/ipad/",
                "reason": "Best official pricing, education options, and refurbished inventory.",
                "metadata": {},
            },
            {
                "id": "result_2",
                "rank": 2,
                "name": "Best Buy",
                "url": "https://www.bestbuy.com/site/ipad-tablets/apple-ipad/pcmcat209000050008.c",
                "reason": "Good for sales, pickup, and open-box availability.",
                "metadata": {},
            },
            {
                "id": "result_3",
                "rank": 3,
                "name": "Costco",
                "url": "https://www.costco.com/ipad.html",
                "reason": "Strong return policy and member bundles.",
                "metadata": {},
            },
            {
                "id": "result_4",
                "rank": 4,
                "name": "Amazon",
                "url": "https://www.amazon.com/s?k=ipad",
                "reason": "Broad availability and frequent discounts.",
                "metadata": {},
            },
            {
                "id": "result_5",
                "rank": 5,
                "name": "B&H Photo",
                "url": "https://www.bhphotovideo.com/c/search?q=iPad",
                "reason": "Good for configurations, accessories, and tax considerations in some states.",
                "metadata": {},
            },
        ]
