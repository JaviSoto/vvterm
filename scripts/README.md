# Scripts

## Terminal keytrace capture (VVTerm vs other terminals)

Use these scripts to capture and compare raw input bytes from terminal apps.

### 1) Record bytes

```bash
python3 scripts/record_terminal_keys.py --label vvterm
```

- Default output directory: `~/vvterm-keylogs`
- Stop capture with `Ctrl+C` (the stop byte is logged too).
- Optional:
  - `--no-echo` to avoid writing captured bytes back to screen
  - `--max-seconds 30` to auto-stop after 30 seconds
  - `--stop-byte 04` to stop on `Ctrl+D` instead

### 2) Compare two captures

```bash
python3 scripts/compare_terminal_keylogs.py \
  ~/vvterm-keylogs/keytrace-vvterm-<timestamp>.jsonl \
  ~/vvterm-keylogs/keytrace-termius-<timestamp>.jsonl
```

- Prints byte length, hex previews, and first differing byte offset.
- Exit code:
  - `0` when logs are byte-identical
  - `1` when a difference is found
