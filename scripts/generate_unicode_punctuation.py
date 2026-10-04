"""Regenerate Unicode 15.0.0 punctuation ranges using Python's Unicode database."""
import argparse
from pathlib import Path
import re
import unicodedata

REPO = Path(__file__).resolve().parents[1]


def generate(check=False):
    if unicodedata.unidata_version != "15.0.0":
        raise SystemExit("Requires Python unicodedata 15.0.0; refusing an implicit Unicode upgrade")
    ranges = []
    for value in range(128, 0x110000):
        if unicodedata.category(chr(value)).startswith("P"):
            if ranges and value == ranges[-1][1] + 1:
                ranges[-1][1] = value
            else:
                ranges.append([value, value])
    path = REPO / "document_unicode.mbt"
    original = path.read_text()
    pattern = r"(?s)(let document_unicode_punctuation_ranges : Array\[\(Int, Int\)\] = \[\n).*?(\n\])"
    body = "\n".join(f"  (0x{start:X}, 0x{end:X})," for start, end in ranges)
    generated, count = re.subn(pattern, lambda match: match[1] + body + match[2], original)
    if count != 1:
        raise SystemExit("Cannot locate the generated punctuation table")
    if check:
        if generated != original:
            raise SystemExit("Punctuation table differs from Unicode 15.0.0")
    else:
        path.write_text(generated)
    print(f"Verified {len(ranges)} Unicode 15.0.0 punctuation ranges" if check else f"Generated {len(ranges)} ranges; run moon fmt")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    generate(parser.parse_args().check)
