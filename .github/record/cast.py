#!/usr/bin/env python3
"""The recording of agk against an installation, made ready for the site and checked first.

    python3 cast.py --window 100x38 --prompt pi RAW OUT_DIR

RAW is the cast asciinema wrote. Three files are written in OUT_DIR, which the site takes as they are:

- agk-server-run.cast: RAW with its header cut to the fields the site's other casts carry, version, width, height, idle_time_limit and title, so that it says nothing of the machine it was made on: no timestamp, no environment, no command line.
- agk-server-run.poster.txt: the final screen as text, from its first prompt, which is what the home page shows of a cast before it is played.
- agk-server-run.poster.html: the same lines as the home page writes them inside <pre id="cast-poster"><code>: a prompt as <span class="p">$</span>, its command in <span class="cmd">.

Nothing is written where the recording shows anything of this machine: the credential the session ran with or any other, a path of the machine, a host other than localhost, an address, the machine's own name. A container's paths, under /agk/, are the workflow's and not the machine's.
"""

import argparse
import html
import json
import math
import os
import re
import socket
import subprocess
import sys
import tempfile
import unicodedata

NAME = "agk-server-run"
HEADER = ("version", "width", "height", "idle_time_limit", "title")

ANSI = re.compile(r"\x1b(?:\[[0-?]*[ -/]*[@-~]|\][^\x07\x1b]*(?:\x07|\x1b\\)|[@-Z\\-_])")
# A slash that follows no word, dot, colon or slash, with a name after it: /agk/bin/agk and /home/runner, and neither the path of a URL, nor demo/pi, nor the 1/4 of a shard.
PATH = re.compile(r"(?<![\w.~:/-])/[^\s\"'`<>()\[\]{},;|]+")
URL_HOST = re.compile(r"\b[A-Za-z][A-Za-z0-9+.-]*://\[?([^/\s:\]\"'<>]+)")
IPV4 = re.compile(r"(?<![\d.])\d{1,3}(?:\.\d{1,3}){3}(?![\d.])")
# The prefixes of what an installation mints: API, join, runner, enrolment and recovery tokens.
CREDENTIAL = re.compile(r"\bagk(?:code|enrol|join|runner|token)_[A-Za-z0-9_-]{6,}")


def fail(message):
    print(f"cast.py: {message}", file=sys.stderr)
    sys.exit(1)


def trim(raw, width, height):
    """The cast with its header cut to HEADER and its output events alone, and the text they write.

    asciinema 3 ends even a version 2 cast with an exit event, x, which version 2 does not define and the site's other casts do not carry: what the player shows is the output, and the session's exit is the workflow's to check, which asciinema --return does.
    """
    lines = raw.splitlines()
    header = json.loads(lines[0])
    if header.get("version") != 2:
        fail(f"the cast is asciicast version {header.get('version')}, where the site's are version 2")
    missing = [key for key in HEADER if key not in header]
    if missing:
        fail(f"the cast's header has no {', '.join(missing)}: {lines[0]}")
    if (header["width"], header["height"]) != (width, height):
        fail(f"the cast is {header['width']}x{header['height']}, where it was recorded at {width}x{height}")
    header["idle_time_limit"] = float(header["idle_time_limit"])
    events, written = [], []
    for line in lines[1:]:
        event = json.loads(line)
        if not (isinstance(event, list) and len(event) == 3):
            fail(f"the cast holds an event that is not [time, code, data]: {line}")
        if event[1] == "i":
            fail("the cast holds keyboard input, which the session never types and the site never plays")
        if event[1] == "o":
            events.append(line)
            written.append(event[2])
    kept = json.dumps({key: header[key] for key in HEADER}, ensure_ascii=False, separators=(",", ":"))
    return "\n".join([kept] + events) + "\n", ANSI.sub("", "".join(written))


def leaks(raw, text):
    """What of this machine the recording shows, one sentence each."""
    found = []
    token = os.environ.get("AGENTIIK_TOKEN", "")
    if token and (token in raw or token in text):
        found.append("the token the session ran with")
    found += [f"a credential, {m.group(0)[:12]}..." for m in CREDENTIAL.finditer(text)]
    found += [f"the path {m.group(0)}" for m in PATH.finditer(text) if not m.group(0).startswith("/agk/")]
    found += [f"the host {m.group(1)}" for m in URL_HOST.finditer(text) if m.group(1).lower() != "localhost"]
    found += [f"the address {m.group(0)}" for m in IPV4.finditer(text)]
    names = {socket.gethostname(), socket.getfqdn(), os.uname().nodename}
    for name in names | {n.split(".")[0] for n in names}:
        if len(name) >= 3 and name.lower() != "localhost" and name.lower() in text.lower():
            found.append(f"this machine's name, {name}")
    for variable in ("HOME", "RUNNER_TEMP", "GITHUB_WORKSPACE", "RUNNER_TOOL_CACHE"):
        value = os.environ.get(variable, "")
        if len(value) > 1 and value in text:
            found.append(f"${variable}, {value}")
    return sorted(set(found))


def columns(line):
    """The columns a line takes on a terminal: two for a wide character, none for a combining one."""
    return sum(0 if unicodedata.combining(c) else 2 if unicodedata.east_asian_width(c) in "WF" else 1 for c in line)


def final_screen(lines, width, height, marker):
    """The lines on the final screen, whole, from its first prompt.

    The session ends on a new line, so the cursor waits on the last row and the text has the others. A line longer than the width wraps onto as many rows as it needs, and one that does not fit whole is left out, as is what stands above the first prompt, so that the poster opens on a command rather than in the middle of what one printed.
    """
    room, kept = height - 1, []
    for line in reversed(lines):
        rows = max(1, math.ceil(columns(line) / width))
        if rows > room:
            break
        kept.append(line)
        room -= rows
    kept.reverse()
    first = next((i for i, line in enumerate(kept) if line.startswith(marker)), 0)
    return kept[first:]


def poster_html(lines, marker):
    out = []
    for line in lines:
        if line.startswith(marker):
            command = html.escape(line[len(marker):], quote=False)
            out.append(f'<span class="p">$</span> <span class="cmd">{command}</span>')
        else:
            out.append(html.escape(line, quote=False))
    return "\n".join(out) + "\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--window", required=True, help="COLSxROWS, as the session was recorded")
    parser.add_argument("--prompt", required=True, help="the directory name the session's prompt shows")
    parser.add_argument("raw")
    parser.add_argument("out_dir")
    args = parser.parse_args()
    width, height = (int(n) for n in args.window.split("x"))
    marker = f"{args.prompt} $ "

    with open(args.raw, encoding="utf-8") as f:
        raw = f.read()
    cast, written = trim(raw, width, height)

    # The text as asciinema's own terminal leaves it, read back from the trimmed cast, which is also what shows that asciinema reads the file the site is given.
    with tempfile.TemporaryDirectory() as tmp:
        path = os.path.join(tmp, NAME + ".cast")
        with open(path, "w", encoding="utf-8") as f:
            f.write(cast)
        text = subprocess.run(["asciinema", "convert", "-f", "txt", path, "-"],
                              check=True, capture_output=True, text=True).stdout

    found = leaks(raw, written + "\n" + text)
    if found:
        fail("the recording shows what it must not, and nothing was written:\n  " + "\n  ".join(found))

    lines = [line.rstrip() for line in text.rstrip("\n").split("\n")]
    screen = final_screen(lines, width, height, marker)
    if not screen or not screen[0].startswith(marker):
        fail(f"the final screen holds no prompt {marker!r}, so it has no command to open the poster on")

    os.makedirs(args.out_dir, exist_ok=True)
    with open(os.path.join(args.out_dir, NAME + ".cast"), "w", encoding="utf-8") as f:
        f.write(cast)
    with open(os.path.join(args.out_dir, NAME + ".poster.txt"), "w", encoding="utf-8") as f:
        f.write("\n".join(screen) + "\n")
    with open(os.path.join(args.out_dir, NAME + ".poster.html"), "w", encoding="utf-8") as f:
        f.write(poster_html(screen, marker))


if __name__ == "__main__":
    main()
