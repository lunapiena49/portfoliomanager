"""Cleanup orphan i18n keys across all 6 locale files.

Removes keys identified as unused in CODE_AUDIT_REPORT.md Fase 1.
"""

import json
import sys
from pathlib import Path


ORPHAN_PATHS = [
    ("app", "tagline"),
    ("portfolio", "daily_change"),
    ("portfolio", "sort_by"),
    ("analysis", "metrics"),
    ("settings", "notifications"),
    ("settings", "data", "backup"),
    ("settings", "data", "restore"),
    ("settings", "about", "privacy"),
    ("settings", "about", "terms"),
    ("settings", "about", "licenses"),
    ("settings", "about", "rate"),
    ("settings", "about", "contact"),
    ("market", "event_labels"),
    ("rebalancing", "messages", "import_portfolio_first"),
    # top-level duplicates
    ("sectors",),
    ("currencies",),
]


def remove_path(data, path):
    node = data
    for key in path[:-1]:
        if not isinstance(node, dict) or key not in node:
            return False
        node = node[key]
    if isinstance(node, dict) and path[-1] in node:
        del node[path[-1]]
        return True
    return False


def main():
    base = Path(__file__).resolve().parent.parent / "assets" / "translations"
    locales = ["it", "en", "es", "fr", "de", "pt"]
    for locale in locales:
        target = base / f"{locale}.json"
        with target.open("r", encoding="utf-8") as fh:
            data = json.load(fh)
        removed = 0
        for path in ORPHAN_PATHS:
            if remove_path(data, path):
                removed += 1
        with target.open("w", encoding="utf-8", newline="\n") as fh:
            json.dump(data, fh, ensure_ascii=False, indent=2)
            fh.write("\n")
        print(f"{locale}.json: removed {removed} orphan keys")


if __name__ == "__main__":
    main()
