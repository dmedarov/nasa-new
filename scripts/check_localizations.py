#!/usr/bin/env python3

from __future__ import annotations

import argparse
import re
import sys
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path


ENTRY_PATTERN = re.compile(r'^\s*"((?:[^"\\]|\\.)+)"\s*=\s*"(?:[^"\\]|\\.)*"\s*;\s*$')


@dataclass
class StringsFileReport:
    path: Path
    keys: list[str]
    duplicates: dict[str, list[int]]
    malformed_lines: list[int]


def parse_strings_file(path: Path) -> StringsFileReport:
    keys: list[str] = []
    seen_lines: dict[str, list[int]] = defaultdict(list)
    malformed_lines: list[int] = []
    in_block_comment = False

    for line_number, raw_line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        line = raw_line.strip()

        if in_block_comment:
            if "*/" in line:
                in_block_comment = False
            continue

        if not line:
            continue

        if line.startswith("/*"):
            if "*/" not in line:
                in_block_comment = True
            continue

        if line.startswith("//"):
            continue

        match = ENTRY_PATTERN.match(raw_line)
        if not match:
            malformed_lines.append(line_number)
            continue

        key = match.group(1)
        keys.append(key)
        seen_lines[key].append(line_number)

    duplicates = {
        key: line_numbers
        for key, line_numbers in seen_lines.items()
        if len(line_numbers) > 1
    }

    return StringsFileReport(
        path=path,
        keys=keys,
        duplicates=duplicates,
        malformed_lines=malformed_lines,
    )


def format_key_list(keys: list[str], limit: int = 12) -> str:
    if not keys:
        return "none"
    if len(keys) <= limit:
        return ", ".join(keys)
    preview = ", ".join(keys[:limit])
    return f"{preview}, ... (+{len(keys) - limit} more)"


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Check Space Briefing localization key parity across locale files."
    )
    parser.add_argument(
        "--root",
        type=Path,
        default=Path(__file__).resolve().parents[1],
        help="Repository root containing the `NASA New` app folder.",
    )
    parser.add_argument(
        "--base-locale",
        default="en",
        help="Base locale to compare against.",
    )
    parser.add_argument(
        "--locales",
        nargs="+",
        default=["bg", "es"],
        help="Locales that must match the base locale key set.",
    )
    args = parser.parse_args()

    app_root = args.root / "NASA New"
    base_path = app_root / f"{args.base_locale}.lproj" / "Localizable.strings"
    compare_paths = [
        app_root / f"{locale}.lproj" / "Localizable.strings"
        for locale in args.locales
    ]

    all_paths = [base_path, *compare_paths]
    missing_files = [str(path) for path in all_paths if not path.exists()]
    if missing_files:
        print("Missing localization files:")
        for path in missing_files:
            print(f"  - {path}")
        return 1

    reports = [parse_strings_file(path) for path in all_paths]
    reports_by_locale = {
        path.parent.name.replace(".lproj", ""): report
        for path, report in zip(all_paths, reports, strict=True)
    }

    has_failure = False

    print("Localization parity report")
    print(f"Base locale: {args.base_locale}")

    for locale, report in reports_by_locale.items():
        print(
            f"- {locale}: {len(report.keys)} entries, "
            f"{len(report.duplicates)} duplicate keys, "
            f"{len(report.malformed_lines)} malformed lines"
        )

    for locale, report in reports_by_locale.items():
        if report.malformed_lines:
            has_failure = True
            line_list = ", ".join(str(line) for line in report.malformed_lines)
            print(f"\n[FAIL] {locale} has malformed lines at: {line_list}")

        if report.duplicates:
            has_failure = True
            print(f"\n[FAIL] {locale} has duplicate keys:")
            for key, line_numbers in sorted(report.duplicates.items()):
                joined = ", ".join(str(line) for line in line_numbers)
                print(f"  - {key}: lines {joined}")

    base_keys = set(reports_by_locale[args.base_locale].keys)
    for locale in args.locales:
        report = reports_by_locale[locale]
        locale_keys = set(report.keys)
        missing = sorted(base_keys - locale_keys)
        extra = sorted(locale_keys - base_keys)

        if missing:
            has_failure = True
            print(f"\n[FAIL] {locale} is missing {len(missing)} keys:")
            print(f"  {format_key_list(missing)}")

        if extra:
            has_failure = True
            print(f"\n[FAIL] {locale} has {len(extra)} extra keys:")
            print(f"  {format_key_list(extra)}")

    if has_failure:
        print("\nLocalization parity check failed.")
        return 1

    print("\nLocalization parity check passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
