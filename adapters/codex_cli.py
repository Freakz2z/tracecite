#!/usr/bin/env python3
"""Convert one `codex exec --json` turn to TraceCite JSONL."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path
from typing import Any


CITATION_RE = re.compile(r"\[(source-\d+)\]")


class ExportError(ValueError):
    pass


def _string(value: Any, field: str) -> str:
    if not isinstance(value, str) or not value:
        raise ExportError(f"{field} must be a nonempty string")
    return value


def export(events: list[dict[str, Any]], bindings: dict[str, str] | None = None) -> list[dict[str, Any]]:
    """Use observed command events and exact output excerpts as evidence."""
    thread_ids = [event.get("thread_id") for event in events if event.get("type") == "thread.started"]
    if len(thread_ids) != 1:
        raise ExportError("expected exactly one thread.started event")
    run_id = _string(thread_ids[0], "thread_id")
    if sum(event.get("type") == "turn.started" for event in events) != 1:
        raise ExportError("expected exactly one turn.started event")
    if sum(event.get("type") == "turn.completed" for event in events) != 1:
        raise ExportError("expected exactly one turn.completed event")
    if any(event.get("type") == "turn.failed" for event in events):
        raise ExportError("turn failed")

    trace: list[dict[str, Any]] = []
    bindings = bindings or {}
    used_bindings: set[str] = set()
    final_answer: str | None = None
    source_number = 0
    for event in events:
        kind = event.get("type")
        item = event.get("item")
        if kind not in ("item.started", "item.completed") or not isinstance(item, dict):
            continue
        if item.get("type") == "command_execution":
            call_id = _string(item.get("id"), "command item id")
            if kind == "item.started":
                trace.append({"type": "tool_call", "run_id": run_id, "call_id": call_id, "tool": "command_execution"})
            else:
                ok = item.get("status") == "completed" and item.get("exit_code") == 0
                output = item.get("aggregated_output")
                sources: list[dict[str, str]] = []
                if ok and isinstance(output, str) and output:
                    source_number += 1
                    source_id = f"source-{source_number}"
                    command = _string(item.get("command"), "command")
                    identity = hashlib.sha256(command.encode("utf-8")).hexdigest()
                    uri = f"urn:tracecite:command:sha256:{identity}"
                    if source_id in bindings:
                        uri = f"file:{bindings[source_id]}"
                        used_bindings.add(source_id)
                    sources.append({
                        "id": source_id,
                        "uri": uri,
                        "title": f"Command result {source_number}",
                        "content": output,
                    })
                trace.append({"type": "tool_result", "run_id": run_id, "call_id": call_id, "ok": ok, "sources": sources})
        elif kind == "item.completed" and item.get("type") == "agent_message":
            final_answer = _string(item.get("text"), "agent message")

    if final_answer is None:
        raise ExportError("no final agent message")
    if used_bindings != set(bindings):
        raise ExportError("binding names a source absent from successful tool output")
    claims = []
    for line_number, line in enumerate(final_answer.splitlines(), start=1):
        ids = list(dict.fromkeys(CITATION_RE.findall(line)))
        if ids:
            quote = CITATION_RE.sub("", line).strip().strip("`\"' ")
            if not quote:
                raise ExportError(f"answer line {line_number} has citation but no quoted content")
            claims.append({
                "text": f"answer line {line_number} (content omitted)",
                "citations": [{"source_id": source_id, "quote": quote} for source_id in ids],
            })
    trace.append({"type": "answer", "run_id": run_id, "claims": claims})
    return trace


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("events", type=Path, help="Codex CLI JSONL event stream")
    parser.add_argument("--out", type=Path, help="output JSONL file; default stdout")
    parser.add_argument("--bind", action="append", default=[], metavar="SOURCE_ID=FILE", help="bind observed output to a local file for independent verification")
    args = parser.parse_args()
    try:
        events = [json.loads(line) for line in args.events.read_text(encoding="utf-8").splitlines() if line.strip()]
        if any(not isinstance(event, dict) for event in events):
            raise ExportError("every event must be a JSON object")
        bindings: dict[str, str] = {}
        for spec in args.bind:
            source_id, separator, file_path = spec.partition("=")
            if not separator or not source_id or not file_path or source_id in bindings:
                raise ExportError("--bind must be unique SOURCE_ID=FILE")
            bindings[source_id] = file_path
        output = "".join(json.dumps(event, ensure_ascii=False) + "\n" for event in export(events, bindings))
        if args.out:
            args.out.write_text(output, encoding="utf-8")
        else:
            sys.stdout.write(output)
        return 0
    except (OSError, json.JSONDecodeError, ExportError) as error:
        print(f"Cannot export Codex CLI events: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
