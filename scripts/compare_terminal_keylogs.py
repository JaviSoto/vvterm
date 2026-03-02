#!/usr/bin/env python3
"""Compare two keytrace JSONL files produced by record_terminal_keys.py."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Compare two terminal keytrace logs.")
    parser.add_argument("left", help="First JSONL log (for example: vvterm)")
    parser.add_argument("right", help="Second JSONL log (for example: termius)")
    parser.add_argument(
        "--preview-bytes",
        type=int,
        default=160,
        help="How many bytes to preview from each side (default: 160).",
    )
    return parser.parse_args()


def read_chunks(path: Path) -> bytes:
    chunks: list[int] = []
    with path.open("r", encoding="utf-8") as handle:
        for raw in handle:
            line = raw.strip()
            if not line:
                continue
            event = json.loads(line)
            if event.get("event") != "chunk":
                continue
            hex_text = event.get("hex", "")
            if not isinstance(hex_text, str) or not hex_text:
                continue
            for part in hex_text.split():
                chunks.append(int(part, 16))
    return bytes(chunks)


def format_preview(data: bytes, limit: int) -> str:
    clipped = data[:limit]
    return " ".join(f"{value:02X}" for value in clipped)


def first_diff(left: bytes, right: bytes) -> int | None:
    min_len = min(len(left), len(right))
    for idx in range(min_len):
        if left[idx] != right[idx]:
            return idx
    if len(left) != len(right):
        return min_len
    return None


def main() -> int:
    args = parse_args()
    left_path = Path(args.left).expanduser().resolve()
    right_path = Path(args.right).expanduser().resolve()

    left = read_chunks(left_path)
    right = read_chunks(right_path)
    diff_index = first_diff(left, right)

    print(f"Left:  {left_path} ({len(left)} bytes)")
    print(f"Right: {right_path} ({len(right)} bytes)")
    print("")
    print(f"Left preview:  {format_preview(left, args.preview_bytes)}")
    print(f"Right preview: {format_preview(right, args.preview_bytes)}")
    print("")

    if diff_index is None:
        print("Result: logs are byte-identical.")
        return 0

    left_byte = left[diff_index] if diff_index < len(left) else None
    right_byte = right[diff_index] if diff_index < len(right) else None
    print(f"Result: first difference at byte offset {diff_index}.")
    print(f"Left byte:  {left_byte:02X}" if left_byte is not None else "Left byte:  <EOF>")
    print(f"Right byte: {right_byte:02X}" if right_byte is not None else "Right byte: <EOF>")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
