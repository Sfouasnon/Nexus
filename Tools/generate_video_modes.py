#!/usr/bin/env python3
"""Generate the ATEM CNTRL video-standard label table from the installed SDK header.

Why this exists
---------------
`BMDSwitcherVideoMode` gains new members with every Blackmagic SDK release — 30 and
60 fps variants, higher resolutions, and whatever comes next. A table hand-written
in C++ is wrong in two directions at once: it silently omits modes the switcher can
actually run, and it fails to compile when it names a symbol the installed header
does not define.

So the table is generated from `BMDSwitcherAPI.h` instead. Every symbol emitted is
one the parser just read out of that header, so it always compiles, and every mode
the SDK knows about is always present. The switcher is still asked which of them it
supports at connect time via `DoesSupportVideoMode`.

Emits enumerator *names*, never values: the compiler resolves them, so this script
never has to care whether Blackmagic used sequential integers or FourCC constants.

Usage:
    generate_video_modes.py --header <path to BMDSwitcherAPI.h> --output <path .inc>
"""

import argparse
import re
import sys

PREFIX = "bmdSwitcherVideoMode"

# An enumerator mention, as opposed to the same name appearing in prose: the token
# must be followed by '=' or ',' or the closing brace of the enum.
ENUMERATOR_RE = re.compile(
    r"\b" + PREFIX + r"([A-Za-z0-9_]+)\s*(?==|,|\})"
)

ENUM_BLOCK_RE = re.compile(
    r"enum\s+_?BMDSwitcherVideoMode\s*(?::[^{]*)?\{(?P<body>.*?)\}", re.S
)

# Standard-definition modes name their line count and colour system rather than a
# raster height, and mark widescreen with "Anamorphic".
SD_RE = re.compile(r"^(?P<lines>525|625)(?P<scan>[ip])(?P<rate>\d+)(?P<system>NTSC|PAL|Anamorphic)$")
# 720p50, 1080i5994, 1080p30, 2160p60 ...
HD_RE = re.compile(r"^(?P<height>\d{3,4})(?P<scan>[ip])(?P<rate>\d+)$")
# 4KHDp2398, 8KHDp5994, and any future <n>K form.
K_RE = re.compile(r"^(?P<multiple>\d+)K(?:HD)?(?P<scan>[ip])(?P<rate>\d+)$")

SD_HEIGHT = {"525": 480, "625": 576}
SD_SYSTEM = {"525": "NTSC", "625": "PAL"}
# A "<n>K" name refers to a multiple of the 1080-line raster, not to a pixel count.
K_HEIGHT_MULTIPLIER = 1080 // 2


def decode_rate(digits: str) -> str:
    """'5994' -> '59.94', '2398' -> '23.98', '30' -> '30', '11988' -> '119.88'.

    Blackmagic writes fractional rates by dropping the decimal point and keeping two
    decimal places, so anything longer than the integer part carries a fraction.
    """
    if len(digits) == 4:
        return f"{digits[:2]}.{digits[2:]}"
    if len(digits) == 5:
        return f"{digits[:3]}.{digits[3:]}"
    return digits


def rate_sort_key(rate: str) -> float:
    try:
        return float(rate)
    except ValueError:
        return 0.0


def classify(suffix: str):
    """Return (format_label, rate_label, height, interlaced, widescreen) or None."""
    match = SD_RE.match(suffix)
    if match:
        lines = match.group("lines")
        system = SD_SYSTEM[lines]
        widescreen = match.group("system") == "Anamorphic"
        label = f"{system} {'16:9' if widescreen else '4:3'}"
        return (
            label,
            decode_rate(match.group("rate")),
            SD_HEIGHT[lines],
            match.group("scan") == "i",
            widescreen,
        )

    match = HD_RE.match(suffix)
    if match:
        height = int(match.group("height"))
        scan = match.group("scan")
        return (
            f"{height}{scan}",
            decode_rate(match.group("rate")),
            height,
            scan == "i",
            False,
        )

    match = K_RE.match(suffix)
    if match:
        height = int(match.group("multiple")) * K_HEIGHT_MULTIPLIER
        scan = match.group("scan")
        return (
            f"{height}{scan}",
            decode_rate(match.group("rate")),
            height,
            scan == "i",
            False,
        )

    return None


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--header", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument(
        "--min-modes",
        type=int,
        default=8,
        help="Fail if fewer modes than this are found, which means parsing broke.",
    )
    args = parser.parse_args()

    try:
        with open(args.header, "r", encoding="utf-8", errors="replace") as handle:
            text = handle.read()
    except OSError as error:
        print(f"generate_video_modes: cannot read {args.header}: {error}", file=sys.stderr)
        return 1

    # Prefer the enum body so unrelated prose elsewhere in the header cannot leak in.
    block = ENUM_BLOCK_RE.search(text)
    # The trailing brace is a sentinel: the last enumerator in an enum body has no
    # comma after it, so without this the final mode would be silently dropped.
    scope = (block.group("body") + "\n}") if block else text
    if not block:
        print(
            "generate_video_modes: BMDSwitcherVideoMode enum block not found, "
            "falling back to a whole-header scan",
            file=sys.stderr,
        )

    suffixes = []
    for suffix in ENUMERATOR_RE.findall(scope):
        if suffix not in suffixes:
            suffixes.append(suffix)

    if len(suffixes) < args.min_modes:
        print(
            f"generate_video_modes: only {len(suffixes)} video mode enumerators found "
            f"in {args.header}; expected at least {args.min_modes}. The header layout "
            "probably changed — fix this script rather than lowering --min-modes.",
            file=sys.stderr,
        )
        return 1

    known, unknown = [], []
    for suffix in suffixes:
        classified = classify(suffix)
        if classified is None:
            unknown.append(suffix)
            continue
        label, rate, height, interlaced, widescreen = classified
        known.append(
            {
                "symbol": PREFIX + suffix,
                "format": label,
                "rate": rate,
                # Interlaced variants sort ahead of progressive at the same height,
                # matching how ATEM Software Control lists them.
                "sort": (height, 0 if interlaced else 1, widescreen, rate_sort_key(rate)),
            }
        )

    known.sort(key=lambda entry: entry["sort"])

    all_symbols = [entry["symbol"] for entry in known] + [PREFIX + s for s in unknown]
    symbol_width = max((len(name) for name in all_symbols), default=0) + 1
    format_width = max((len(entry["format"]) for entry in known), default=0) + 3

    lines = [
        "// GENERATED by Tools/generate_video_modes.py — do not edit by hand.",
        f"// Source: {args.header}",
        "// Regenerate with: make video-modes",
        "",
    ]
    for entry in known:
        symbol = (entry["symbol"] + ",").ljust(symbol_width)
        label = (f'"{entry["format"]}",').ljust(format_width)
        lines.append(f'    {{ {symbol} {label} "{entry["rate"]}" }},')

    if unknown:
        # Still reachable: refreshSupportedVideoModesLocked probes numerically for
        # anything absent from this table and shows it as "Mode <n>".
        lines.append("")
        lines.append("    // Unrecognised name patterns, listed with the raw suffix as the label:")
        for suffix in unknown:
            symbol = (PREFIX + suffix + ",").ljust(symbol_width)
            label = (f'"{suffix}",').ljust(format_width)
            lines.append(f'    {{ {symbol} {label} "" }},')

    with open(args.output, "w", encoding="utf-8") as handle:
        handle.write("\n".join(lines) + "\n")

    formats = []
    for entry in known:
        if entry["format"] not in formats:
            formats.append(entry["format"])
    print(
        f"generate_video_modes: {len(known)} labelled + {len(unknown)} unlabelled modes "
        f"across {len(formats)} formats -> {args.output}"
    )
    if unknown:
        print("  unlabelled: " + ", ".join(unknown))
    return 0


if __name__ == "__main__":
    sys.exit(main())
