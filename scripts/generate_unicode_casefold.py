"""Reproduce Unicode 15.0.0 default case folding for Markdown reference labels."""
import argparse
from pathlib import Path
import re
import unicodedata

REPO = Path(__file__).resolve().parents[1]


def generate(check=False):
    if unicodedata.unidata_version != "15.0.0":
        raise SystemExit("Requires Python unicodedata 15.0.0; refusing an implicit Unicode upgrade")
    ranges = []
    expansions = []
    for value in range(0x110000):
        folded = chr(value).casefold()
        if folded == chr(value):
            continue
        if len(folded) != 1:
            expansions.append((value, folded))
            continue
        delta = ord(folded) - value
        if ranges and delta == ranges[-1][3]:
            first, last, step, _ = ranges[-1]
            gap = value - last
            if gap in (1, 2) and (first == last or gap == step):
                ranges[-1][1:3] = [value, gap]
                continue
        ranges.append([value, value, 1, delta])
    path = REPO / "document_casefold.mbt"
    original = path.read_text()
    bodies = {
        "ranges": "\n".join(f"  (0x{first:X}, 0x{last:X}, {step}, {delta})," for first, last, step, delta in ranges),
        "expansions": "\n".join(f'  (0x{value:X}, "' + "".join(f"\\u{{{ord(ch):X}}}" for ch in folded) + '"),' for value, folded in expansions),
    }
    generated = original
    for name, body in bodies.items():
        pattern = rf"(?s)(let document_unicode_casefold_{name} : Array\[\([^\n]+\)\] = \[\n).*?(\n\])"
        generated, count = re.subn(pattern, lambda m: m[1] + body + m[2], generated)
        if count != 1:
            raise SystemExit("Cannot locate generated table: " + name)
    if check:
        if generated != original:
            raise SystemExit("Case folding differs from Unicode 15.0.0; regenerate and run moon fmt")
    else:
        path.write_text(generated)
    print("Verified" if check else "Generated", len(ranges), "case-folding ranges and", len(expansions), "expansions")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    generate(parser.parse_args().check)
