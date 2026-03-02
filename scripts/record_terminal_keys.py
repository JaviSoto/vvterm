#!/usr/bin/env python3
"""Capture raw terminal input bytes into a timestamped JSONL log."""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import select
import sys
import termios
import tty
from pathlib import Path


def now_iso() -> str:
    return dt.datetime.now(dt.timezone.utc).astimezone().isoformat(timespec="milliseconds")


def bytes_to_hex(data: bytes) -> str:
    return " ".join(f"{byte:02X}" for byte in data)


def bytes_to_escaped(data: bytes) -> str:
    out: list[str] = []
    for byte in data:
        if 32 <= byte <= 126:
            out.append(chr(byte))
            continue
        if byte == 0x0A:
            out.append("\\n")
            continue
        if byte == 0x0D:
            out.append("\\r")
            continue
        if byte == 0x09:
            out.append("\\t")
            continue
        if byte == 0x1B:
            out.append("\\e")
            continue
        out.append(f"\\x{byte:02x}")
    return "".join(out)


def sanitize_label(label: str) -> str:
    safe = "".join(ch if ch.isalnum() or ch in ("-", "_") else "-" for ch in label.strip())
    return safe.strip("-_") or "session"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Record raw stdin bytes from this terminal session.\n"
            "Default stop key is Ctrl+C (byte 0x03), which is logged before exit."
        )
    )
    parser.add_argument(
        "--label",
        default="session",
        help="Label to include in output filename (example: vvterm or termius).",
    )
    parser.add_argument(
        "--output-dir",
        default=str(Path.home() / "vvterm-keylogs"),
        help="Directory where the JSONL log file is written.",
    )
    parser.add_argument(
        "--stop-byte",
        default="03",
        help="Hex byte that ends capture after logging it (default: 03 for Ctrl+C).",
    )
    parser.add_argument(
        "--max-seconds",
        type=float,
        default=0.0,
        help="Optional max capture duration; 0 means unlimited.",
    )
    parser.add_argument(
        "--no-echo",
        action="store_true",
        help="Do not mirror captured bytes back to stdout while recording.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    if not sys.stdin.isatty():
        print("stdin is not a TTY. Run this directly in an interactive terminal.", file=sys.stderr)
        return 2

    try:
        stop_byte = int(args.stop_byte, 16)
    except ValueError:
        print(f"Invalid --stop-byte value: {args.stop_byte!r} (expected hex, e.g. 03)", file=sys.stderr)
        return 2

    if not 0 <= stop_byte <= 0xFF:
        print("stop-byte must be in range 00..FF", file=sys.stderr)
        return 2

    out_dir = Path(args.output_dir).expanduser().resolve()
    out_dir.mkdir(parents=True, exist_ok=True)

    timestamp = dt.datetime.now().strftime("%Y%m%d-%H%M%S")
    label = sanitize_label(args.label)
    log_path = out_dir / f"keytrace-{label}-{timestamp}.jsonl"

    stdin_fd = sys.stdin.fileno()
    stdout_fd = sys.stdout.fileno()
    original_attrs = termios.tcgetattr(stdin_fd)
    stop_seen = False
    total_bytes = 0
    start_mono = dt.datetime.now().timestamp()

    with log_path.open("w", encoding="utf-8") as handle:
        header = {
            "event": "session_start",
            "ts": now_iso(),
            "label": label,
            "pid": os.getpid(),
            "cwd": str(Path.cwd()),
            "tty": os.ttyname(stdin_fd),
            "env": {
                "TERM": os.environ.get("TERM"),
                "COLORTERM": os.environ.get("COLORTERM"),
                "LC_CTYPE": os.environ.get("LC_CTYPE"),
                "LANG": os.environ.get("LANG"),
            },
            "stop_byte_hex": f"{stop_byte:02X}",
            "echo": not args.no_echo,
        }
        handle.write(json.dumps(header, ensure_ascii=True) + "\n")
        handle.flush()

        print(f"Recording started: {log_path}")
        print("Type normally. Press Ctrl+C to end capture (it will be logged).")
        print("")

        tty.setraw(stdin_fd, when=termios.TCSANOW)
        try:
            while True:
                if args.max_seconds > 0:
                    elapsed = dt.datetime.now().timestamp() - start_mono
                    if elapsed >= args.max_seconds:
                        break

                readable, _, _ = select.select([stdin_fd], [], [], 0.25)
                if not readable:
                    continue

                data = os.read(stdin_fd, 4096)
                if not data:
                    break

                total_bytes += len(data)
                row = {
                    "event": "chunk",
                    "ts": now_iso(),
                    "len": len(data),
                    "hex": bytes_to_hex(data),
                    "escaped": bytes_to_escaped(data),
                }
                handle.write(json.dumps(row, ensure_ascii=True) + "\n")
                handle.flush()

                if not args.no_echo:
                    os.write(stdout_fd, data)

                if stop_byte in data:
                    stop_seen = True
                    break
        finally:
            termios.tcsetattr(stdin_fd, termios.TCSANOW, original_attrs)

        footer = {
            "event": "session_end",
            "ts": now_iso(),
            "total_bytes": total_bytes,
            "stop_seen": stop_seen,
        }
        handle.write(json.dumps(footer, ensure_ascii=True) + "\n")
        handle.flush()

    print("")
    print(f"Recording saved: {log_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
