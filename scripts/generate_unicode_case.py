"""Reproduce Unicode 15.0.0 lowercase mappings and Final_Sigma properties offline."""
import argparse
import hashlib
from pathlib import Path
import re
import unicodedata

REPO = Path(__file__).resolve().parents[1]
DATA = REPO / "third_party/unicode/DerivedCoreProperties-case-15.0.0.txt"
UCD_SHA256 = "d367290bc0867e6b484c68370530bdd1a08b6b32404601b8c7accaf83e05628d"
CASE_DATA_SHA256 = "95b12ed9ca51c02a8bd89d521d30e0f64f4185e31907d6b031441e83a10193ed"


def property_ranges(text, name):
    ranges = []
    for line in text.splitlines():
        if "; " + name + " #" not in line:
            continue
        bounds = line.split(";", 1)[0].strip().split("..")
        first, last = int(bounds[0], 16), int(bounds[-1], 16)
        if ranges and first == ranges[-1][1] + 1:
            ranges[-1][1] = last
        else:
            ranges.append([first, last])
    return ranges


def generate(check=False, from_ucd=None):
    if unicodedata.unidata_version != "15.0.0":
        raise SystemExit("Requires Python unicodedata 15.0.0; refusing an implicit Unicode upgrade")
    if hashlib.sha256(DATA.read_bytes()).hexdigest() != CASE_DATA_SHA256:
        raise SystemExit("Checked-in case properties differ from the pinned Unicode data")
    if from_ucd:
        raw = from_ucd.read_bytes()
        if hashlib.sha256(raw).hexdigest() != UCD_SHA256:
            raise SystemExit("DerivedCoreProperties.txt differs from the pinned Unicode 15.0.0 source")
        lines = raw.decode().splitlines()
        extracted = "\n".join(lines[:9]) + "\n\n# Cased and Case_Ignorable records retained verbatim; other properties omitted.\n"
        extracted += "\n".join(line for line in lines if "; Cased #" in line or "; Case_Ignorable #" in line) + "\n"
        if extracted != DATA.read_text():
            raise SystemExit("Checked-in case properties differ from the pinned source")
    properties = DATA.read_text()
    mappings = []
    expansions = []
    for value in range(0x110000):
        lowered = chr(value).lower()
        if lowered == chr(value):
            continue
        if len(lowered) != 1:
            expansions.append((value, lowered))
            continue
        delta = ord(lowered) - value
        if mappings and delta == mappings[-1][3]:
            first, last, step, _ = mappings[-1]
            gap = value - last
            if gap in (1, 2) and (first == last or gap == step):
                mappings[-1][1:3] = [value, gap]
                continue
        mappings.append([value, value, 1, delta])
    # U+0130 is the only unconditional multi-character lowercase mapping in
    # Unicode 15.0.0. Context-sensitive U+03A3 is implemented by the caller.
    if expansions != [(0x130, "i\u0307")]:
        raise SystemExit("Unexpected lowercase expansions; review the runtime implementation")
    tables = {
        "document_unicode_lowercase_ranges": mappings,
        "document_unicode_cased_ranges": property_ranges(properties, "Cased"),
        "document_unicode_case_ignorable_ranges": property_ranges(properties, "Case_Ignorable"),
    }
    path = REPO / "document_case.mbt"
    generated = path.read_text()
    for name, ranges in tables.items():
        body = "\n".join("  (" + ", ".join(f"0x{n:X}" if i < 2 else str(n) for i, n in enumerate(row)) + ")," for row in ranges)
        pattern = rf"(?s)(let {name} : Array\[\([^\n]+\)\] = \[\n).*?(\n\])"
        generated, count = re.subn(pattern, lambda match: match[1] + body + match[2], generated)
        if count != 1:
            raise SystemExit("Cannot locate generated table: " + name)
    if check:
        if generated != path.read_text():
            raise SystemExit("Case tables differ from Unicode 15.0.0; regenerate and run moon fmt")
    else:
        path.write_text(generated)
    print("Verified" if check else "Generated", ", ".join(f"{len(ranges)} {name}" for name, ranges in tables.items()))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--from-ucd", type=Path, help="Also verify extraction from the original pinned Unicode file")
    options = parser.parse_args()
    generate(options.check, options.from_ucd)
