from __future__ import annotations

import os
from typing import Any, Dict, List


class WebSearch:
    @property
    def mode(self) -> str:
        mode = os.environ.get("JARVIS_WEB_SEARCH_MODE", "demo").strip().lower()
        if mode in {"disabled", "demo", "real_provider"}:
            return mode
        return "demo"

    def search(self, query: str, limit: int = 5) -> List[Dict[str, Any]]:
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
