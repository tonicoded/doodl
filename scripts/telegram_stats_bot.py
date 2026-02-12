#!/usr/bin/env python3
import os
import sqlite3
import time
from datetime import datetime, timezone
from typing import Any, Dict, Optional

import requests


BOT_TOKEN = os.getenv("TELEGRAM_BOT_TOKEN")
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_SERVICE_ROLE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY")
ALLOWED_CHAT_ID = os.getenv("TELEGRAM_ALLOWED_CHAT_ID")
FREE_STATS_LIMIT = int(os.getenv("TELEGRAM_FREE_STATS_LIMIT", "3"))
PRO_USER_IDS = {
    int(value)
    for value in os.getenv("TELEGRAM_PRO_USER_IDS", "").split(",")
    if value.strip().isdigit()
}
UPGRADE_URL = os.getenv("TELEGRAM_UPGRADE_URL", "").strip()
USAGE_DB_PATH = os.getenv(
    "TELEGRAM_USAGE_DB_PATH",
    os.path.join(os.path.dirname(__file__), "telegram_stats_usage.sqlite3"),
)

if not BOT_TOKEN:
    raise SystemExit("Missing TELEGRAM_BOT_TOKEN")
if not SUPABASE_URL:
    raise SystemExit("Missing SUPABASE_URL")
if not SUPABASE_SERVICE_ROLE_KEY:
    raise SystemExit("Missing SUPABASE_SERVICE_ROLE_KEY")

API_BASE = f"https://api.telegram.org/bot{BOT_TOKEN}"


def init_usage_db() -> None:
    with sqlite3.connect(USAGE_DB_PATH, timeout=30) as conn:
        conn.execute("PRAGMA journal_mode=WAL;")
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS usage (
                actor_id INTEGER NOT NULL,
                day TEXT NOT NULL,
                action TEXT NOT NULL,
                count INTEGER NOT NULL,
                PRIMARY KEY (actor_id, day, action)
            );
            """
        )


def utc_day_key() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%d")


def get_usage_count(actor_id: int, action: str, day_key: str) -> int:
    with sqlite3.connect(USAGE_DB_PATH, timeout=30) as conn:
        row = conn.execute(
            "SELECT count FROM usage WHERE actor_id = ? AND day = ? AND action = ?",
            (actor_id, day_key, action),
        ).fetchone()
        return int(row[0]) if row else 0


def increment_usage(actor_id: int, action: str, day_key: str) -> int:
    with sqlite3.connect(USAGE_DB_PATH, timeout=30) as conn:
        conn.execute(
            """
            INSERT INTO usage (actor_id, day, action, count)
            VALUES (?, ?, ?, 1)
            ON CONFLICT(actor_id, day, action) DO UPDATE SET count = count + 1
            """,
            (actor_id, day_key, action),
        )
        row = conn.execute(
            "SELECT count FROM usage WHERE actor_id = ? AND day = ? AND action = ?",
            (actor_id, day_key, action),
        ).fetchone()
        return int(row[0]) if row else 0


def supabase_stats() -> Dict[str, Any]:
    url = f"{SUPABASE_URL.rstrip('/')}/rest/v1/rpc/get_app_stats"
    headers = {
        "apikey": SUPABASE_SERVICE_ROLE_KEY,
        "Authorization": f"Bearer {SUPABASE_SERVICE_ROLE_KEY}",
        "Content-Type": "application/json",
    }
    response = requests.post(url, headers=headers, json={}, timeout=20)
    response.raise_for_status()
    payload = response.json()
    if not payload:
        raise RuntimeError("No stats returned")
    return payload[0]


def fmt_int(value: Any) -> str:
    if value is None:
        return "-"
    try:
        return str(int(value))
    except Exception:
        return str(value)


def fmt_time(value: Any) -> str:
    if not value:
        return "-"
    if isinstance(value, str):
        try:
            parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
            return parsed.strftime("%Y-%m-%d %H:%M:%S")
        except Exception:
            return value
    return str(value)


def format_stats(row: Dict[str, Any]) -> str:
    number_fields = [
        row.get("online_2m"),
        row.get("online_10m"),
        row.get("active_24h"),
        row.get("active_7d"),
        row.get("new_users_last_hour"),
        row.get("new_users_last_day"),
        row.get("new_users_last_week"),
        row.get("total_users"),
        row.get("doodles_last_hour"),
        row.get("doodles_last_day"),
        row.get("doodles_last_week"),
        row.get("total_doodles"),
        row.get("push_pending"),
        row.get("xp_pending"),
    ]
    width = max(len(fmt_int(value)) for value in number_fields) if number_fields else 1

    def pad(value: Any) -> str:
        return fmt_int(value).rjust(width)

    lines = [
        "DOODL. stats (UTC)",
        f"Updated: {fmt_time(row.get('now'))}",
        "",
        "USERS",
        f"Online: 2m {pad(row.get('online_2m'))} | 10m {pad(row.get('online_10m'))}",
        f"Active: 24h {pad(row.get('active_24h'))} | 7d {pad(row.get('active_7d'))}",
        (
            "New:    1h "
            f"{pad(row.get('new_users_last_hour'))} | 24h {pad(row.get('new_users_last_day'))} | 7d {pad(row.get('new_users_last_week'))}"
        ),
        f"Total users: {pad(row.get('total_users'))}",
        "",
        "DOODLES",
        f"Last:   1h {pad(row.get('doodles_last_hour'))} | 24h {pad(row.get('doodles_last_day'))} | 7d {pad(row.get('doodles_last_week'))}",
        f"Total doodles: {pad(row.get('total_doodles'))}",
        "",
        "QUEUES",
        f"Push pending: {pad(row.get('push_pending'))}",
        f"XP pending:   {pad(row.get('xp_pending'))}",
    ]
    return "```\n" + "\n".join(lines) + "\n```"


def send_message(chat_id: int, text: str, parse_mode: Optional[str] = None) -> None:
    response = requests.post(
        f"{API_BASE}/sendMessage",
        json={"chat_id": chat_id, "text": text, "parse_mode": parse_mode},
        timeout=20,
    )
    response.raise_for_status()


def allowed_chat(chat_id: int) -> bool:
    if not ALLOWED_CHAT_ID:
        return True
    try:
        return int(ALLOWED_CHAT_ID) == chat_id
    except ValueError:
        return False


def actor_id_from_message(message: Dict[str, Any]) -> Optional[int]:
    sender = message.get("from")
    if isinstance(sender, dict) and isinstance(sender.get("id"), int):
        return sender["id"]
    chat = message.get("chat") or {}
    chat_id = chat.get("id")
    return chat_id if isinstance(chat_id, int) else None


def paywall_text() -> str:
    if UPGRADE_URL:
        return (
            f"Free limit reached for today. Upgrade to Pro to continue: {UPGRADE_URL}"
        )
    return "Free limit reached for today. Upgrade to Pro to continue."


def handle_command(chat_id: int, actor_id: int, text: str) -> None:
    if not allowed_chat(chat_id):
        return

    if text.startswith("/start"):
        if FREE_STATS_LIMIT > 0 and actor_id not in PRO_USER_IDS:
            send_message(
                chat_id,
                f"Send /stats to get the latest DOODL. stats.\n\nFree: {FREE_STATS_LIMIT}/day. Pro: unlimited.",
            )
        else:
            send_message(chat_id, "Send /stats to get the latest DOODL. stats.")
        return

    if text.startswith("/stats"):
        if FREE_STATS_LIMIT > 0 and actor_id not in PRO_USER_IDS:
            day_key = utc_day_key()
            used = get_usage_count(actor_id, "/stats", day_key)
            if used >= FREE_STATS_LIMIT:
                send_message(chat_id, paywall_text())
                return
            now_used = increment_usage(actor_id, "/stats", day_key)
        else:
            now_used = 0

        try:
            stats = supabase_stats()
            message = format_stats(stats)
            if FREE_STATS_LIMIT > 0 and actor_id not in PRO_USER_IDS:
                remaining = max(FREE_STATS_LIMIT - now_used, 0)
                message = (
                    f"{message}\n\nFree uses left today: {remaining}/{FREE_STATS_LIMIT}"
                )
            send_message(chat_id, message, parse_mode="Markdown")
        except Exception as exc:
            send_message(chat_id, f"Failed to fetch stats: {exc}")
        return

    if text.startswith("/upgrade"):
        send_message(chat_id, paywall_text())
        return

    send_message(chat_id, "Unknown command. Try /stats.")


def extract_message(update: Dict[str, Any]) -> Optional[Dict[str, Any]]:
    message = update.get("message")
    if not isinstance(message, dict):
        return None
    return message


def main() -> None:
    init_usage_db()
    offset: Optional[int] = None
    while True:
        try:
            params = {"timeout": 60}
            if offset is not None:
                params["offset"] = offset
            response = requests.get(f"{API_BASE}/getUpdates", params=params, timeout=70)
            response.raise_for_status()
            data = response.json()
            if not data.get("ok"):
                time.sleep(2)
                continue
            for update in data.get("result", []):
                offset = update.get("update_id", 0) + 1
                message = extract_message(update)
                if not message:
                    continue
                text = message.get("text")
                chat = message.get("chat") or {}
                chat_id = chat.get("id")
                actor_id = actor_id_from_message(message)
                if (
                    isinstance(text, str)
                    and isinstance(chat_id, int)
                    and isinstance(actor_id, int)
                ):
                    handle_command(chat_id, actor_id, text.strip())
        except Exception:
            time.sleep(2)


if __name__ == "__main__":
    main()
