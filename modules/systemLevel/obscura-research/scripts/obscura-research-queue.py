#!/usr/bin/env python3
"""Process an Obsidian research queue with Obscura-rendered page captures.

Queue convention:
- Input markdown files live under: <vault>/00 Queue/Research
- Each queue note can contain one or more http(s) URLs.
- Processed notes get an HTML marker to avoid duplicate captures.
- Generated capture notes are written to: <vault>/05 Generated/Research
"""
from __future__ import annotations

import argparse
import datetime as dt
import os
import re
import subprocess
import sys
from pathlib import Path
from urllib.parse import urlparse

URL_RE = re.compile(r"https?://[^\s)\]>\"']+")
PROCESSED_RE = re.compile(r"<!--\s*obscura-processed:.*?-->", re.DOTALL)


def slugify(text: str, limit: int = 70) -> str:
    text = re.sub(r"[^A-Za-z0-9]+", "-", text).strip("-").lower()
    return (text or "research")[:limit].strip("-") or "research"


def default_vault() -> Path:
    env = os.environ.get("OBSIDIAN_VAULT_PATH")
    if env:
        return Path(env).expanduser()
    return Path("/home/damajha/Documents/Obsidian Vault")


def extract_urls(text: str) -> list[str]:
    seen: set[str] = set()
    urls: list[str] = []
    for raw in URL_RE.findall(text):
        url = raw.rstrip(".,;:")
        if url not in seen:
            seen.add(url)
            urls.append(url)
    return urls


def fetch_markdown(obscura_bin: str, url: str, timeout: int, wait: int, max_chars: int) -> tuple[bool, str, str]:
    cmd = [
        obscura_bin,
        "fetch",
        url,
        "--dump",
        "markdown",
        "--timeout",
        str(timeout),
        "--wait",
        str(wait),
        "--quiet",
    ]
    try:
        proc = subprocess.run(cmd, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=timeout + wait + 20)
    except subprocess.TimeoutExpired as exc:
        return False, "", f"Timed out after {exc.timeout}s"
    output = proc.stdout or ""
    if max_chars and len(output) > max_chars:
        output = output[:max_chars] + f"\n\n<!-- truncated by obscura-research-queue at {max_chars} chars -->\n"
    return proc.returncode == 0, output, (proc.stderr or "").strip()


def build_generated_note(
    *,
    queue_note: Path,
    queue_rel: str,
    urls: list[str],
    captures: list[tuple[str, bool, str, str]],
    captured_at: str,
) -> str:
    title = queue_note.stem
    lines: list[str] = [
        "---",
        f"title: Obscura Research Capture - {title}",
        "type: generated-research-capture",
        "status: draft",
        f"source_note: \"{queue_rel}\"",
        f"captured_at: {captured_at}",
        "tool: obscura",
        "---",
        "",
        f"# Obscura Research Capture - {title}",
        "",
        f"Source queue note: [[{queue_note.stem}]]",
        "",
        "## Sources",
        "",
    ]
    for url in urls:
        lines.append(f"- {url}")
    lines.extend([
        "",
        "## Extraction notes",
        "",
        "This is a raw rendered-page capture. Treat it as source material, not verified truth. Summarize/promote durable facts into canonical notes after review.",
        "",
    ])
    for idx, (url, ok, markdown, err) in enumerate(captures, 1):
        host = urlparse(url).netloc or "source"
        lines.extend([
            f"## Source {idx}: {host}",
            "",
            f"URL: {url}",
            f"Status: {'ok' if ok else 'failed'}",
            "",
        ])
        if err:
            lines.extend(["### Tool stderr", "", "```text", err[:4000], "```", ""])
        if markdown:
            lines.extend(["### Rendered markdown", "", markdown, ""])
    return "\n".join(lines).rstrip() + "\n"


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description="Process Obsidian research queue notes with Obscura")
    ap.add_argument("--vault", type=Path, default=default_vault(), help="Obsidian vault path")
    ap.add_argument("--queue", default="00 Queue/Research", help="Queue folder relative to vault")
    ap.add_argument("--generated", default="05 Generated/Research", help="Generated output folder relative to vault")
    ap.add_argument("--obscura-bin", default=os.environ.get("OBSCURA_BIN", "obscura"), help="Obscura executable")
    ap.add_argument("--limit", type=int, default=5, help="Max queue notes to process")
    ap.add_argument("--timeout", type=int, default=45, help="Obscura navigation timeout seconds")
    ap.add_argument("--wait", type=int, default=3, help="Obscura post-load wait seconds")
    ap.add_argument("--max-chars-per-url", type=int, default=60000, help="Truncate each rendered capture to this many chars; 0 disables")
    ap.add_argument("--dry-run", action="store_true", help="Print what would be processed without writing")
    args = ap.parse_args(argv)

    vault = args.vault.expanduser().resolve()
    queue_dir = vault / args.queue
    gen_dir = vault / args.generated
    if not queue_dir.exists():
        print(f"Queue directory does not exist: {queue_dir}", file=sys.stderr)
        return 2
    if not args.dry_run:
        gen_dir.mkdir(parents=True, exist_ok=True)

    notes = sorted(queue_dir.glob("*.md"))
    processed_count = 0
    for note in notes:
        if processed_count >= args.limit:
            break
        text = note.read_text(encoding="utf-8", errors="ignore")
        if PROCESSED_RE.search(text):
            continue
        urls = extract_urls(text)
        if not urls:
            continue
        rel = str(note.relative_to(vault))
        print(f"Processing {rel}: {len(urls)} URL(s)")
        if args.dry_run:
            for url in urls:
                print(f"  - {url}")
            processed_count += 1
            continue
        captured_at = dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat()
        captures = []
        for url in urls:
            print(f"  fetching {url}")
            ok, md, err = fetch_markdown(args.obscura_bin, url, args.timeout, args.wait, args.max_chars_per_url)
            captures.append((url, ok, md, err))
        out_name = f"{dt.datetime.now().strftime('%Y-%m-%d-%H%M%S')}-{slugify(note.stem)}.md"
        out_path = gen_dir / out_name
        out_path.write_text(
            build_generated_note(queue_note=note, queue_rel=rel, urls=urls, captures=captures, captured_at=captured_at),
            encoding="utf-8",
        )
        marker = f"\n\n<!-- obscura-processed: {captured_at} output: {args.generated}/{out_name} -->\n"
        note.write_text(text.rstrip() + marker, encoding="utf-8")
        print(f"  wrote {out_path}")
        processed_count += 1
    if processed_count == 0:
        print("No unprocessed queue notes with URLs found.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
