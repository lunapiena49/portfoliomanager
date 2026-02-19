#!/usr/bin/env python3
"""Build serverless market snapshot from EODHD bulk daily data.

Historical approach: lightweight milestone_prices.db that stores only 3 reference
snapshots (7d, 30d, 365d ago).  No large history dump needed — the file is a few
MB and grows naturally from the first run.

Lifecycle of each slot:
  - First run: slot is empty → mover for that timeframe not computed, slot
    initialised with today's prices.
  - After N calendar days: slot is old enough → comparison yields a meaningful
    return; slot is replaced with today's prices so the window resets.

Comparison accuracy:
  - 5D window:  slot refreshes every  7 calendar days  (~5 trading days)
  - 1M window:  slot refreshes every 30 calendar days
  - 1Y window:  slot refreshes every 365 calendar days
"""

from __future__ import annotations

import argparse
import io
import json
import logging
import math
import os
import sqlite3
import sys
import time
import zipfile
from collections import Counter
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Optional
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen

BULK_LAST_DAY_URL_TEMPLATE = "https://eodhd.com/api/eod-bulk-last-day/{market}"
USER_AGENT = "portfolio-manager-market-pipeline/1.0"
TIMEFRAME_KEYS = ("1D", "5D", "1M", "1Y")


@dataclass(frozen=True)
class MarketDefinition:
    code: str
    name: str
    default_currency: str


KNOWN_MARKET_DEFINITIONS: dict[str, tuple[str, str]] = {
    "US": ("United States", "USD"),
    "LSE": ("United Kingdom", "GBP"),
    "XETRA": ("Germany", "EUR"),
    "PA": ("France", "EUR"),
    "MI": ("Italy", "EUR"),
    "TO": ("Canada", "CAD"),
    "TSE": ("Japan", "JPY"),
    "HK": ("Hong Kong", "HKD"),
    "AU": ("Australia", "AUD"),
    "NSE": ("India", "INR"),
}
DEFAULT_MARKETS = "US,LSE,XETRA,PA,TO,HK,AU,NSE"
# Slot names and their target refresh age in calendar days.
MILESTONE_SLOTS: dict[str, int] = {"7d": 7, "30d": 30, "365d": 365}


@dataclass(frozen=True)
class DailyPriceRow:
    market_code: str
    market_name: str
    ticker: str
    name: str
    currency: str
    close: float
    volume: int
    change_percent: Optional[float]
    as_of_date: str


def sanitize_sensitive_text(text: str, secrets: list[str]) -> str:
    sanitized = text
    for secret in secrets:
        if secret:
            sanitized = sanitized.replace(secret, "***")
    return sanitized


def normalize_market_code(raw_code: str) -> str:
    return raw_code.strip().upper().replace(" ", "")


def resolve_markets(raw_markets: str) -> list[MarketDefinition]:
    resolved: list[MarketDefinition] = []
    seen_codes: set[str] = set()

    for chunk in raw_markets.split(","):
        code = normalize_market_code(chunk)
        if not code or code in seen_codes:
            continue

        seen_codes.add(code)
        known = KNOWN_MARKET_DEFINITIONS.get(code)
        if known is None:
            resolved.append(
                MarketDefinition(
                    code=code,
                    name=code,
                    default_currency="USD",
                )
            )
            continue

        resolved.append(
            MarketDefinition(
                code=code,
                name=known[0],
                default_currency=known[1],
            )
        )

    return resolved


def parse_iso_date(date_text: str) -> datetime:
    return datetime.strptime(date_text, "%Y-%m-%d")


def iso_days_ago(reference_date: str, days: int) -> str:
    reference = parse_iso_date(reference_date)
    target = reference - timedelta(days=days)
    return target.strftime("%Y-%m-%d")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Download EODHD bulk daily data, generate compressed SQLite snapshot "
            "and top movers JSON."
        )
    )
    parser.add_argument(
        "--output-dir",
        default="dist/market-data",
        help="Directory for generated files.",
    )
    parser.add_argument(
        "--api-key-env",
        default="EODHD_API_KEY",
        help="Environment variable name containing EODHD API key.",
    )
    parser.add_argument(
        "--markets",
        default=DEFAULT_MARKETS,
        help=(
            "Comma-separated EODHD market codes to process "
            "(example: US,LSE,XETRA,PA,TO,HK,AU,NSE)."
        ),
    )
    parser.add_argument(
        "--top-limit",
        type=int,
        default=20,
        help="Number of gainers/losers to keep in top_movers.json.",
    )
    parser.add_argument(
        "--max-retries",
        type=int,
        default=4,
        help="Maximum retries for EODHD download.",
    )
    parser.add_argument(
        "--timeout-seconds",
        type=int,
        default=90,
        help="HTTP timeout in seconds for EODHD request.",
    )
    parser.add_argument(
        "--log-file",
        default="pipeline.log",
        help="Log filename (relative to output dir) or absolute log path.",
    )
    parser.add_argument(
        "--milestone-db-name",
        default="milestone_prices.db",
        help="Filename for the lightweight milestone SQLite database.",
    )
    parser.add_argument(
        "--milestone-db-zip-name",
        default="milestone_prices.db.zip",
        help="Filename for the compressed milestone database.",
    )
    parser.add_argument(
        "--milestone-db-url",
        default="",
        help=(
            "URL of the existing milestone_prices.db.zip published on GitHub Pages. "
            "The script downloads it at the start of each run and updates it in place."
        ),
    )
    parser.add_argument(
        "--keep-uncompressed-db",
        action="store_true",
        help="Keep uncompressed SQLite files next to their .zip counterparts.",
    )
    return parser.parse_args()


def configure_logger(log_path: Path) -> logging.Logger:
    log_path.parent.mkdir(parents=True, exist_ok=True)

    logger = logging.getLogger("market_snapshot")
    logger.setLevel(logging.INFO)
    logger.handlers.clear()

    formatter = logging.Formatter("%(asctime)s | %(levelname)s | %(message)s")

    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setFormatter(formatter)
    logger.addHandler(console_handler)

    file_handler = logging.FileHandler(log_path, encoding="utf-8")
    file_handler.setFormatter(formatter)
    logger.addHandler(file_handler)

    return logger


def parse_float(raw: Any) -> Optional[float]:
    if raw is None:
        return None

    if isinstance(raw, (int, float)):
        value = float(raw)
    elif isinstance(raw, str):
        text = raw.strip().replace("%", "")
        if not text:
            return None

        # Handle both decimal comma and thousand separators.
        if "," in text and "." not in text:
            text = text.replace(",", ".")
        else:
            text = text.replace(",", "")

        try:
            value = float(text)
        except ValueError:
            return None
    else:
        return None

    return value if math.isfinite(value) else None


def parse_int(raw: Any) -> Optional[int]:
    value = parse_float(raw)
    if value is None:
        return None
    return int(value)


def normalize_date(raw: Any, fallback_date: str) -> str:
    if isinstance(raw, str):
        candidate = raw.strip()[:10]
        if candidate:
            try:
                datetime.strptime(candidate, "%Y-%m-%d")
                return candidate
            except ValueError:
                pass
    return fallback_date


def extract_change_percent(record: dict[str, Any], close: float) -> Optional[float]:
    for key in ("change_p", "changePercent", "change_percent", "changesPercentage"):
        value = parse_float(record.get(key))
        if value is not None:
            return value

    previous_close = (
        parse_float(record.get("previousClose"))
        or parse_float(record.get("previous_close"))
        or parse_float(record.get("prevClose"))
        or parse_float(record.get("prev_close"))
    )
    if previous_close not in (None, 0):
        return (close - previous_close) / previous_close * 100.0

    # Last fallback when only absolute daily change is available.
    absolute_change = parse_float(record.get("change"))
    if absolute_change is not None:
        derived_previous = close - absolute_change
        if derived_previous != 0:
            return absolute_change / derived_previous * 100.0

    # Bulk endpoint fallback: many exchanges expose open/close only.
    # This is an intraday move proxy (close vs open), not close vs prev close.
    open_price = parse_float(record.get("open"))
    if open_price not in (None, 0):
        return (close - open_price) / open_price * 100.0

    return None


def fetch_bulk_last_day(
    api_key: str,
    market_code: str,
    timeout_seconds: int,
    max_retries: int,
    logger: logging.Logger,
) -> list[dict[str, Any]]:
    params = {
        "api_token": api_key,
        "fmt": "json",
    }
    request_url = (
        f"{BULK_LAST_DAY_URL_TEMPLATE.format(market=market_code)}?{urlencode(params)}"
    )

    last_error: Optional[Exception] = None
    for attempt in range(1, max_retries + 1):
        try:
            logger.info(
                "Downloading EODHD %s bulk daily data (attempt %s/%s)...",
                market_code,
                attempt,
                max_retries,
            )
            request = Request(request_url, headers={"User-Agent": USER_AGENT})
            with urlopen(request, timeout=timeout_seconds) as response:
                payload = response.read()

            data = json.loads(payload.decode("utf-8"))
            if not isinstance(data, list):
                raise ValueError(f"Unexpected EODHD payload type: {type(data).__name__}")

            logger.info(
                "EODHD payload downloaded successfully for %s. Rows: %s",
                market_code,
                len(data),
            )
            return [item for item in data if isinstance(item, dict)]
        except HTTPError as exc:
            last_error = RuntimeError(
                "HTTP error while downloading EODHD bulk data "
                f"for {market_code}: status={exc.code}, reason={exc.reason}"
            )
            logger.warning("EODHD request failed: %s", last_error)
            if attempt < max_retries:
                wait_seconds = min(5 * attempt, 30)
                logger.info("Retrying in %s seconds...", wait_seconds)
                time.sleep(wait_seconds)
        except URLError as exc:
            safe_reason = sanitize_sensitive_text(str(exc.reason), [api_key])
            last_error = RuntimeError(
                f"Network error while downloading EODHD bulk data for {market_code}: {safe_reason}"
            )
            logger.warning("EODHD request failed: %s", last_error)
            if attempt < max_retries:
                wait_seconds = min(5 * attempt, 30)
                logger.info("Retrying in %s seconds...", wait_seconds)
                time.sleep(wait_seconds)
        except (TimeoutError, json.JSONDecodeError, ValueError) as exc:
            safe_detail = sanitize_sensitive_text(str(exc), [api_key])
            last_error = RuntimeError(
                f"{exc.__class__.__name__} while downloading EODHD bulk data for {market_code}: {safe_detail}"
            )
            logger.warning("EODHD request failed: %s", last_error)
            if attempt < max_retries:
                wait_seconds = min(5 * attempt, 30)
                logger.info("Retrying in %s seconds...", wait_seconds)
                time.sleep(wait_seconds)
        except Exception as exc:
            safe_detail = sanitize_sensitive_text(str(exc), [api_key])
            last_error = RuntimeError(
                "Unexpected error while downloading EODHD bulk data "
                f"for {market_code}: "
                f"{exc.__class__.__name__}: {safe_detail}"
            )
            logger.warning("EODHD request failed: %s", last_error)
            if attempt < max_retries:
                wait_seconds = min(5 * attempt, 30)
                logger.info("Retrying in %s seconds...", wait_seconds)
                time.sleep(wait_seconds)

    raise RuntimeError(
        f"Unable to download EODHD {market_code} bulk data after {max_retries} attempts."
    ) from last_error


def build_price_rows(
    market: MarketDefinition,
    raw_rows: list[dict[str, Any]],
    fallback_date: str,
    logger: logging.Logger,
) -> list[DailyPriceRow]:
    rows_by_ticker: dict[str, DailyPriceRow] = {}
    skipped_rows = 0
    duplicate_tickers = 0

    for row in raw_rows:
        ticker_raw = row.get("code") or row.get("symbol") or row.get("ticker")
        ticker = str(ticker_raw).strip().upper() if ticker_raw is not None else ""
        close = parse_float(row.get("close"))

        if not ticker or close is None:
            skipped_rows += 1
            continue

        security_name = (row.get("name") or row.get("short_name") or ticker)
        normalized_name = str(security_name).strip() if security_name is not None else ticker
        if not normalized_name:
            normalized_name = ticker

        currency_raw = row.get("currency")
        normalized_currency = (
            str(currency_raw).strip().upper()
            if currency_raw is not None and str(currency_raw).strip()
            else market.default_currency
        )

        volume = parse_int(row.get("volume")) or 0
        as_of_date = normalize_date(row.get("date"), fallback_date)
        change_percent = extract_change_percent(row, close)

        if ticker in rows_by_ticker:
            duplicate_tickers += 1

        rows_by_ticker[ticker] = DailyPriceRow(
            market_code=market.code,
            market_name=market.name,
            ticker=ticker,
            name=normalized_name,
            currency=normalized_currency,
            close=close,
            volume=volume,
            change_percent=change_percent,
            as_of_date=as_of_date,
        )

    cleaned_rows = list(rows_by_ticker.values())

    logger.info(
        "Rows prepared for SQLite [%s]. Valid unique: %s | Skipped invalid: %s | Duplicate tickers replaced: %s",
        market.code,
        len(cleaned_rows),
        skipped_rows,
        duplicate_tickers,
    )

    if not cleaned_rows:
        raise RuntimeError("No valid market rows extracted from EODHD payload.")

    return cleaned_rows


def write_sqlite_snapshot(
    db_path: Path,
    rows: list[DailyPriceRow],
    markets: list[MarketDefinition],
    logger: logging.Logger,
) -> None:
    db_path.parent.mkdir(parents=True, exist_ok=True)
    if db_path.exists():
        db_path.unlink()

    with sqlite3.connect(db_path) as connection:
        connection.execute(
            """
            CREATE TABLE daily_prices (
                market_code TEXT NOT NULL,
                market_name TEXT NOT NULL,
                ticker TEXT NOT NULL,
                name TEXT NOT NULL,
                currency TEXT NOT NULL,
                close REAL NOT NULL,
                volume INTEGER NOT NULL,
                change_percent REAL,
                as_of_date TEXT NOT NULL,
                PRIMARY KEY (market_code, ticker)
            )
            """
        )
        connection.execute(
            "CREATE INDEX idx_daily_prices_market_code ON daily_prices(market_code)"
        )
        connection.execute(
            "CREATE INDEX idx_daily_prices_as_of_date ON daily_prices(as_of_date)"
        )
        connection.execute(
            "CREATE INDEX idx_daily_prices_change_percent ON daily_prices(change_percent)"
        )

        connection.executemany(
            """
            INSERT INTO daily_prices (
                market_code,
                market_name,
                ticker,
                name,
                currency,
                close,
                volume,
                change_percent,
                as_of_date
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                (
                    r.market_code,
                    r.market_name,
                    r.ticker,
                    r.name,
                    r.currency,
                    r.close,
                    r.volume,
                    r.change_percent,
                    r.as_of_date,
                )
                for r in rows
            ),
        )

        serialized_markets = ",".join(market.code for market in markets)

        connection.execute(
            """
            CREATE TABLE snapshot_meta (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL
            )
            """
        )
        connection.executemany(
            "INSERT INTO snapshot_meta(key, value) VALUES (?, ?)",
            [
                ("markets", serialized_markets),
                ("source", "EODHD_BULK_LAST_DAY"),
                ("generated_at_utc", datetime.now(timezone.utc).isoformat()),
                ("rows", str(len(rows))),
                ("market_count", str(len(markets))),
            ],
        )
        connection.commit()

    logger.info("SQLite snapshot generated: %s", db_path)


def compress_file(source_path: Path, zip_path: Path, logger: logging.Logger) -> None:
    if zip_path.exists():
        zip_path.unlink()

    with zipfile.ZipFile(
        zip_path,
        mode="w",
        compression=zipfile.ZIP_DEFLATED,
        compresslevel=9,
    ) as archive:
        archive.write(source_path, arcname=source_path.name)

    logger.info("Compressed file generated: %s", zip_path)


# ---------------------------------------------------------------------------
# Milestone DB helpers
# ---------------------------------------------------------------------------

def fetch_milestone_db(
    db_path: Path,
    milestone_url: str,
    timeout_seconds: int,
    logger: logging.Logger,
) -> None:
    """Download and extract milestone_prices.db.zip from GitHub Pages if available."""
    url = milestone_url.strip()
    if not url or db_path.exists():
        return
    try:
        logger.info("Fetching existing milestone DB from %s", url)
        req = Request(url, headers={"User-Agent": USER_AGENT})
        with urlopen(req, timeout=timeout_seconds) as resp:
            data = resp.read()
        with zipfile.ZipFile(io.BytesIO(data)) as zf:
            entry = next(
                (n for n in zf.namelist() if n.lower().endswith(".db")), None
            )
            if entry is None:
                raise RuntimeError("No .db file found in milestone archive.")
            db_path.parent.mkdir(parents=True, exist_ok=True)
            with zf.open(entry) as src, db_path.open("wb") as dst:
                dst.write(src.read())
        logger.info("Milestone DB fetched: %s", db_path)
    except Exception as exc:
        logger.warning(
            "Could not fetch milestone DB (will start fresh): %s", exc
        )


def ensure_milestone_schema(conn: sqlite3.Connection) -> None:
    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS milestone_prices (
            slot        TEXT NOT NULL,
            market_code TEXT NOT NULL,
            ticker      TEXT NOT NULL,
            name        TEXT NOT NULL,
            currency    TEXT NOT NULL,
            close       REAL NOT NULL,
            as_of_date  TEXT NOT NULL,
            PRIMARY KEY (slot, market_code, ticker)
        )
        """
    )
    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS milestone_meta (
            key   TEXT PRIMARY KEY,
            value TEXT NOT NULL
        )
        """
    )


def get_milestone_meta(conn: sqlite3.Connection) -> dict[str, str]:
    rows = conn.execute("SELECT key, value FROM milestone_meta").fetchall()
    return {k: v for k, v in rows}


def load_milestone_prices(
    conn: sqlite3.Connection, slot: str
) -> dict[tuple[str, str], tuple[float, str, str, str]]:
    """Return {(market_code, ticker): (close, currency, name, as_of_date)} for a slot."""
    cursor = conn.execute(
        "SELECT market_code, ticker, close, currency, name, as_of_date FROM milestone_prices WHERE slot = ?",
        (slot,),
    )
    return {(r[0], r[1]): (float(r[2]), r[3], r[4], r[5]) for r in cursor}


def replace_milestone_slot(
    conn: sqlite3.Connection,
    slot: str,
    rows: list[DailyPriceRow],
    today: str,
    logger: logging.Logger,
) -> None:
    conn.execute("DELETE FROM milestone_prices WHERE slot = ?", (slot,))
    conn.executemany(
        """
        INSERT INTO milestone_prices (slot, market_code, ticker, name, currency, close, as_of_date)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        """,
        [
            (slot, r.market_code, r.ticker, r.name, r.currency, r.close, r.as_of_date)
            for r in rows
        ],
    )
    conn.execute(
        "INSERT OR REPLACE INTO milestone_meta(key, value) VALUES (?, ?)",
        (f"{slot}_date", today),
    )
    logger.info("Milestone slot '%s' updated with %d rows (%s)", slot, len(rows), today)


def safe_percent_change(current: float, reference: float) -> Optional[float]:
    if reference <= 0:
        return None
    value = (current - reference) / reference * 100.0
    return value if math.isfinite(value) else None



def row_to_mover_json(row: DailyPriceRow, change_percent: float) -> dict[str, Any]:
    return {
        "symbol": row.ticker,
        "ticker": row.ticker,
        "name": row.name,
        "price": round(row.close, 6),
        "close": round(row.close, 6),
        "volume": row.volume,
        "currency": row.currency,
        "change_percent": round(change_percent, 6),
        "changePercent": round(change_percent, 6),
        "as_of_date": row.as_of_date,
        "asOfDate": row.as_of_date,
    }


def build_top_movers_payload(
    rows: list[DailyPriceRow],
    markets: list[MarketDefinition],
    top_limit: int,
    milestone_db_path: Path,
    logger: logging.Logger,
) -> dict[str, Any]:
    """Compute top movers for all markets using milestone reference prices."""
    rows_by_market: dict[str, list[DailyPriceRow]] = {}
    for row in rows:
        rows_by_market.setdefault(row.market_code, []).append(row)

    # Load milestone reference prices for all slots.
    with sqlite3.connect(milestone_db_path) as conn:
        ensure_milestone_schema(conn)
        meta = get_milestone_meta(conn)
        slot_prices: dict[str, dict[tuple[str, str], tuple[float, str, str, str]]] = {
            slot: load_milestone_prices(conn, slot) for slot in MILESTONE_SLOTS
        }

    markets_payload: list[dict[str, Any]] = []

    for market in markets:
        market_rows = rows_by_market.get(market.code, [])
        if not market_rows:
            continue

        as_of_date = Counter(
            row.as_of_date for row in market_rows
        ).most_common(1)[0][0]

        # Slot → timeframe label mapping.
        slot_to_tf: dict[str, str] = {"7d": "5D", "30d": "1M", "365d": "1Y"}

        ranked: dict[str, list[tuple[DailyPriceRow, float]]] = {
            tf: [] for tf in TIMEFRAME_KEYS
        }

        for row in market_rows:
            # 1D: from EODHD change_percent field.
            if row.change_percent is not None and math.isfinite(row.change_percent):
                ranked["1D"].append((row, row.change_percent))

            # Multi-day: compare to milestone slot.
            for slot, tf_label in slot_to_tf.items():
                slot_date = meta.get(f"{slot}_date", "")
                if not slot_date:
                    # Slot not initialised yet.
                    continue
                ref = slot_prices[slot].get((row.market_code, row.ticker))
                if ref is None:
                    continue

                ref_close, _, _, ref_as_of_date = ref
                # Skip non-older references; prevents zeroed movers on re-runs
                # when milestone rows and current rows share the same market date.
                if ref_as_of_date:
                    if ref_as_of_date >= row.as_of_date:
                        continue
                elif slot_date == as_of_date:
                    continue

                pct = safe_percent_change(row.close, ref_close)
                if pct is not None:
                    ranked[tf_label].append((row, pct))

        timeframes_payload: dict[str, Any] = {}
        for tf in TIMEFRAME_KEYS:
            pool = ranked[tf]
            positive_pool = [item for item in pool if item[1] > 0]
            negative_pool = [item for item in pool if item[1] < 0]
            gainers = sorted(positive_pool, key=lambda x: x[1], reverse=True)[:top_limit]
            losers = sorted(negative_pool, key=lambda x: x[1])[:top_limit]
            timeframes_payload[tf] = {
                "eligible_symbols": len(positive_pool) + len(negative_pool),
                "gainers": [row_to_mover_json(r, c) for r, c in gainers],
                "losers": [row_to_mover_json(r, c) for r, c in losers],
            }

        logger.info(
            "Top movers [%s] 1D=%d 5D=%d 1M=%d 1Y=%d eligible",
            market.code,
            len(ranked["1D"]),
            len(ranked["5D"]),
            len(ranked["1M"]),
            len(ranked["1Y"]),
        )

        markets_payload.append(
            {
                "code": market.code,
                "name": market.name,
                "currency": market.default_currency,
                "as_of_date": as_of_date,
                "timeframes": timeframes_payload,
            }
        )

    payload: dict[str, Any] = {
        "generated_at_utc": datetime.now(timezone.utc).isoformat(),
        "source": "EODHD_BULK_LAST_DAY",
        "timeframes": list(TIMEFRAME_KEYS),
        "markets": markets_payload,
        "counts": {"input_rows": len(rows), "markets": len(markets_payload)},
    }

    us_payload = next((m for m in markets_payload if m["code"] == "US"), None)
    if us_payload:
        payload["market"] = "US"
        payload["as_of_date"] = us_payload["as_of_date"]
        payload["gainers"] = us_payload["timeframes"]["1D"]["gainers"]
        payload["losers"] = us_payload["timeframes"]["1D"]["losers"]

    return payload


def build_prices_index_payload(
    rows: list[DailyPriceRow],
    markets: list[MarketDefinition],
) -> dict[str, Any]:
    """Build a flat ticker→price lookup map for client-side portfolio quote lookup.

    Each entry is stored twice:
    - ``TICKER``          – flat key (US has priority; last market wins for others)
    - ``MARKET:TICKER``   – unambiguous key, always accurate

    Clients should prefer the market-prefixed key when the exchange is known.
    """
    market_priority: dict[str, int] = {m.code: i for i, m in enumerate(markets)}

    flat: dict[str, dict[str, Any]] = {}
    best_priority: dict[str, int] = {}

    prices: dict[str, dict[str, Any]] = {}

    for row in rows:
        entry = {
            "c": round(row.close, 6),
            "cu": row.currency,
            "m": row.market_code,
            "d": row.as_of_date,
        }

        mkt_key = f"{row.market_code}:{row.ticker}"
        prices[mkt_key] = entry

        priority = market_priority.get(row.market_code, 9999)
        current_best = best_priority.get(row.ticker, 9999)
        if priority < current_best:
            flat[row.ticker] = entry
            best_priority[row.ticker] = priority

    prices.update(flat)

    return {
        "v": 1,
        "generated_at_utc": datetime.now(timezone.utc).isoformat(),
        "source": "EODHD_BULK_LAST_DAY",
        "prices": prices,
    }


def write_json(path: Path, payload: dict[str, Any], logger: logging.Logger) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    logger.info("JSON file generated: %s", path)


def resolve_log_path(output_dir: Path, raw_log_file: str) -> Path:
    candidate = Path(raw_log_file)
    return candidate if candidate.is_absolute() else output_dir / candidate


def main() -> int:
    args = parse_args()

    api_key = os.getenv(args.api_key_env, "").strip()
    if not api_key:
        print(
            f"ERROR: missing API key in environment variable '{args.api_key_env}'.",
            file=sys.stderr,
        )
        return 2

    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    log_path = resolve_log_path(output_dir, args.log_file)

    markets = resolve_markets(args.markets)
    if not markets:
        print(
            "ERROR: no valid markets configured. Use --markets with at least one code.",
            file=sys.stderr,
        )
        return 2

    logger = configure_logger(log_path)
    logger.info(
        "Market snapshot workflow started (milestone mode). Markets: %s",
        ", ".join(m.code for m in markets),
    )

    try:
        today_utc = datetime.now(timezone.utc).strftime("%Y-%m-%d")

        # --- 1. Fetch today's bulk prices for all markets ---
        rows: list[DailyPriceRow] = []
        failed_markets: list[str] = []
        for market in markets:
            try:
                raw_data = fetch_bulk_last_day(
                    api_key=api_key,
                    market_code=market.code,
                    timeout_seconds=args.timeout_seconds,
                    max_retries=args.max_retries,
                    logger=logger,
                )
                market_rows = build_price_rows(
                    market=market,
                    raw_rows=raw_data,
                    fallback_date=today_utc,
                    logger=logger,
                )
                rows.extend(market_rows)
            except Exception as market_error:
                failed_markets.append(market.code)
                logger.error(
                    "Market %s skipped: %s",
                    market.code,
                    sanitize_sensitive_text(str(market_error), [api_key]),
                )

        if not rows:
            raise RuntimeError("No market rows were generated from configured markets.")
        if failed_markets:
            logger.warning("Markets skipped: %s", ", ".join(failed_markets))

        # --- 2. Prepare paths ---
        db_path = output_dir / "daily_market.db"
        db_zip_path = output_dir / "daily_market.db.zip"
        milestone_db_path = output_dir / args.milestone_db_name
        milestone_zip_path = output_dir / args.milestone_db_zip_name
        top_movers_path = output_dir / "top_movers.json"
        prices_index_path = output_dir / "prices_index.json"

        # --- 3. Download existing milestone DB from GitHub Pages (if configured) ---
        fetch_milestone_db(
            db_path=milestone_db_path,
            milestone_url=args.milestone_db_url,
            timeout_seconds=args.timeout_seconds,
            logger=logger,
        )

        # --- 4. Compute top movers using milestone reference prices ---
        payload = build_top_movers_payload(
            rows=rows,
            markets=markets,
            top_limit=args.top_limit,
            milestone_db_path=milestone_db_path,
            logger=logger,
        )
        write_json(top_movers_path, payload, logger)

        # --- 5. Update milestone slots (AFTER computing movers) ---
        with sqlite3.connect(milestone_db_path) as conn:
            ensure_milestone_schema(conn)
            meta = get_milestone_meta(conn)
            for slot, target_days in MILESTONE_SLOTS.items():
                slot_date = meta.get(f"{slot}_date", "")
                needs_update = (
                    not slot_date
                    or (
                        datetime.strptime(today_utc, "%Y-%m-%d")
                        - datetime.strptime(slot_date, "%Y-%m-%d")
                    ).days
                    >= target_days
                )
                if needs_update:
                    replace_milestone_slot(conn, slot, rows, today_utc, logger)
                else:
                    logger.info(
                        "Milestone slot '%s' is %s days old — no update needed.",
                        slot,
                        (
                            datetime.strptime(today_utc, "%Y-%m-%d")
                            - datetime.strptime(slot_date, "%Y-%m-%d")
                        ).days,
                    )
            conn.execute(
                "INSERT OR REPLACE INTO milestone_meta(key, value) VALUES (?, ?)",
                ("last_run_utc", datetime.now(timezone.utc).isoformat()),
            )
            conn.commit()

        # --- 6. Write today's daily snapshot DB (for reference / debugging) ---
        write_sqlite_snapshot(db_path=db_path, rows=rows, markets=markets, logger=logger)
        compress_file(source_path=db_path, zip_path=db_zip_path, logger=logger)

        # --- 7. Compress updated milestone DB for GitHub Pages upload ---
        compress_file(source_path=milestone_db_path, zip_path=milestone_zip_path, logger=logger)

        # --- 8. Write prices_index.json ---
        prices_index_payload = build_prices_index_payload(rows=rows, markets=markets)
        write_json(prices_index_path, prices_index_payload, logger)

        # --- 9. Cleanup uncompressed files ---
        if not args.keep_uncompressed_db:
            for p in (db_path, milestone_db_path):
                if p.exists():
                    p.unlink()
                    logger.info("Removed uncompressed file: %s", p)

        logger.info("Workflow completed successfully.")
        return 0

    except Exception as exc:
        safe_error = sanitize_sensitive_text(
            f"{exc.__class__.__name__}: {exc}", [api_key]
        )
        logger.error("Workflow failed. %s", safe_error)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
