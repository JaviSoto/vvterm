#!/usr/bin/env python3
"""TCP <-> PTY proxy for running zellij in the iOS input harness loop."""

from __future__ import annotations

import argparse
import json
import os
import pty
import select
import shlex
import signal
import socket
import subprocess
import sys
import time
from pathlib import Path

stop_requested = False


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run zellij behind a local TCP proxy for VVTerm input-harness verification."
    )
    parser.add_argument("--log-dir", required=True, help="Directory for logs/artifacts.")
    parser.add_argument("--port-file", required=True, help="File that receives selected TCP port.")
    parser.add_argument("--summary-file", required=True, help="JSON summary output path.")
    parser.add_argument(
        "--zellij-bin",
        default="/opt/homebrew/bin/zellij",
        help="Path to zellij executable.",
    )
    parser.add_argument(
        "--session-name",
        default=f"vvterm-harness-{int(time.time())}",
        help="Unique zellij session name.",
    )
    parser.add_argument(
        "--profile",
        choices=("tab-new-tab", "resize-plus-new-tab"),
        default="tab-new-tab",
        help="Harness keybinding profile to load.",
    )
    return parser.parse_args()


def zellij_config_for_profile(profile: str) -> str:
    if profile == "tab-new-tab":
        return """keybinds clear-defaults=true {
    normal {
        bind "Ctrl t" { SwitchToMode "tab"; }
    }
    tab {
        bind "Ctrl t" { SwitchToMode "normal"; }
        bind "n" { NewTab; SwitchToMode "normal"; }
    }
}
"""

    if profile == "resize-plus-new-tab":
        return """keybinds clear-defaults=true {
    normal {
        bind "Ctrl n" { SwitchToMode "resize"; }
    }
    resize {
        bind "=" "+" { NewTab; SwitchToMode "normal"; }
    }
}
"""

    raise ValueError(f"Unsupported zellij harness profile: {profile}")


def write_text(path: Path, contents: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(contents, encoding="utf-8")


def log(message: str) -> None:
    sys.stderr.write(f"{message}\n")
    sys.stderr.flush()


def request_stop(signum: int, _frame: object) -> None:
    global stop_requested
    stop_requested = True
    log(f"received signal {signum}, shutting down")


def terminate_process(proc: subprocess.Popen[bytes]) -> None:
    if proc.poll() is not None:
        return
    proc.terminate()
    try:
        proc.wait(timeout=2.0)
    except subprocess.TimeoutExpired:
        proc.kill()
        proc.wait(timeout=2.0)


def main() -> int:
    global stop_requested
    signal.signal(signal.SIGTERM, request_stop)
    signal.signal(signal.SIGINT, request_stop)

    args = parse_args()
    log_dir = Path(args.log_dir).resolve()
    port_file = Path(args.port_file).resolve()
    summary_file = Path(args.summary_file).resolve()
    zellij_bin = Path(args.zellij_bin).resolve()

    log_dir.mkdir(parents=True, exist_ok=True)

    if not zellij_bin.exists():
        log(f"zellij binary not found: {zellij_bin}")
        return 2

    pane_input_path = log_dir / "pane-input.bin"
    client_to_zellij_path = log_dir / "client-to-zellij.bin"
    zellij_to_client_path = log_dir / "zellij-to-client.bin"
    zellij_config_path = log_dir / "zellij-config.kdl"
    sink_script_path = log_dir / "zellij-pane-sink.sh"

    pane_input_path.write_bytes(b"")
    client_to_zellij_path.write_bytes(b"")
    zellij_to_client_path.write_bytes(b"")

    sink_script = f"""#!/bin/bash
set -euo pipefail
cat >> {shlex.quote(str(pane_input_path))}
"""
    write_text(sink_script_path, sink_script)
    sink_script_path.chmod(0o755)

    zellij_config = zellij_config_for_profile(args.profile)
    write_text(zellij_config_path, zellij_config)

    master_fd, slave_fd = pty.openpty()
    env = os.environ.copy()
    env["SHELL"] = str(sink_script_path)
    env["TERM"] = "xterm-256color"

    zellij_cmd = [
        str(zellij_bin),
        "-c",
        str(zellij_config_path),
        "--session",
        args.session_name,
    ]
    log(f"starting zellij: {' '.join(shlex.quote(part) for part in zellij_cmd)}")
    proc = subprocess.Popen(
        zellij_cmd,
        stdin=slave_fd,
        stdout=slave_fd,
        stderr=slave_fd,
        env=env,
        close_fds=True,
    )
    os.close(slave_fd)

    bytes_client_to_zellij = 0
    bytes_zellij_to_client = 0
    connection_opened = False

    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind(("127.0.0.1", 0))
    server.listen(1)
    server.settimeout(0.5)
    selected_port = server.getsockname()[1]
    write_text(port_file, f"{selected_port}\n")
    log(f"listening on 127.0.0.1:{selected_port}")

    conn: socket.socket | None = None
    exit_code = 0
    try:
        while not stop_requested:
            try:
                conn, _ = server.accept()
                conn.setblocking(False)
                connection_opened = True
                log("client connected")
                break
            except socket.timeout:
                if proc.poll() is not None:
                    log(f"zellij exited before client connect: {proc.returncode}")
                    break
                continue
        if conn is None and not connection_opened:
            if stop_requested:
                log("stopped before client connection")
            else:
                log("timed out waiting for harness connection")
            exit_code = 3

        while conn is not None and not stop_requested:
            if proc.poll() is not None:
                log(f"zellij exited early with code {proc.returncode}")
                break

            read_targets: list[int | socket.socket] = [master_fd]
            if conn is not None:
                read_targets.append(conn)
            ready, _, _ = select.select(read_targets, [], [], 0.1)
            if not ready:
                continue

            for target in ready:
                if target == master_fd:
                    try:
                        data = os.read(master_fd, 65536)
                    except OSError:
                        data = b""
                    if not data:
                        continue
                    bytes_zellij_to_client += len(data)
                    with zellij_to_client_path.open("ab") as handle:
                        handle.write(data)
                    if conn is not None:
                        try:
                            conn.sendall(data)
                        except OSError:
                            conn.close()
                            conn = None
                            log("client send failed, closing connection")
                else:
                    assert conn is not None
                    try:
                        incoming = conn.recv(65536)
                    except BlockingIOError:
                        incoming = b""
                    except OSError:
                        incoming = b""
                    if incoming == b"":
                        conn.close()
                        conn = None
                        log("client disconnected")
                        break
                    bytes_client_to_zellij += len(incoming)
                    with client_to_zellij_path.open("ab") as handle:
                        handle.write(incoming)
                    os.write(master_fd, incoming)

            if conn is None:
                break
    finally:
        if conn is not None:
            conn.close()
        server.close()
        terminate_process(proc)
        os.close(master_fd)

    summary = {
        "zellij_bin": str(zellij_bin),
        "session_name": args.session_name,
        "connection_opened": connection_opened,
        "zellij_exit_code": proc.returncode,
        "bytes_client_to_zellij": bytes_client_to_zellij,
        "bytes_zellij_to_client": bytes_zellij_to_client,
        "pane_input_bytes": pane_input_path.stat().st_size if pane_input_path.exists() else 0,
        "pane_input_path": str(pane_input_path),
        "client_to_zellij_path": str(client_to_zellij_path),
        "zellij_to_client_path": str(zellij_to_client_path),
    }
    write_text(summary_file, json.dumps(summary, indent=2) + "\n")

    if exit_code == 0 and not connection_opened:
        return 4
    return exit_code


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        raise SystemExit(130)
