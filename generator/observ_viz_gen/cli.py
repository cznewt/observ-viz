"""Command-line entry point.

Usage:
    python -m observ_viz_gen [all|variable|panel|query|dashboard|annotation|
                              timeSettings|versions|main] [--out DIR] [--check]

--out defaults to gen/observ-viz-v2beta1 (resolved relative to the repo root,
which is the parent of the generator/ package directory). The observ-viz-latest/
redirect is written beside it under the shared gen/ root.

--check diffs the would-be output against what is on disk and exits non-zero on
any mismatch, without writing.
"""
from __future__ import annotations

import argparse
import difflib
import os
import sys

from . import generate
from . import validate

# repo root = two levels up from this file: generator/observ_viz_gen/cli.py
_PKG_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(os.path.dirname(_PKG_DIR))
DEFAULT_OUT = os.path.join("gen", generate.V2)


def _resolve_out(out: str) -> str:
    if os.path.isabs(out):
        return out
    return os.path.join(REPO_ROOT, out)


def main(argv=None) -> int:
    p = argparse.ArgumentParser(prog="observ-viz-gen")
    p.add_argument(
        "target",
        nargs="?",
        default="all",
        help="all (default) or a group: %s" % ", ".join(generate.all_groups()),
    )
    p.add_argument(
        "--out",
        default=DEFAULT_OUT,
        help="output dir (the observ-viz-v2beta1 dir); default %s" % DEFAULT_OUT,
    )
    p.add_argument(
        "--check",
        action="store_true",
        help="diff against disk without writing; non-zero exit on mismatch",
    )
    args = p.parse_args(argv)

    out_dir = _resolve_out(args.out)
    root = generate.gen_root(out_dir)
    specs = generate.files_for(args.target)

    # Schema cross-check: prove the curated manifest is a faithful subset of the
    # authoritative v2beta1 JSON schema before emitting / checking anything.
    schema_problems = validate.check_all()
    if schema_problems:
        sys.stderr.write("SCHEMA CROSS-CHECK FAILED:\n")
        for p in schema_problems:
            sys.stderr.write("  - %s\n" % p)
        return 1

    mismatches = 0
    written = 0
    for rel_path, emitter in specs:
        dest = os.path.join(root, rel_path)
        content = emitter()
        if args.check:
            existing = ""
            if os.path.exists(dest):
                with open(dest, "r", encoding="utf-8") as fh:
                    existing = fh.read()
            if existing != content:
                mismatches += 1
                sys.stderr.write("DIFFERS: %s\n" % rel_path)
                diff = difflib.unified_diff(
                    existing.splitlines(keepends=True),
                    content.splitlines(keepends=True),
                    fromfile=rel_path + " (on disk)",
                    tofile=rel_path + " (generated)",
                )
                sys.stderr.writelines(diff)
        else:
            os.makedirs(os.path.dirname(dest), exist_ok=True)
            with open(dest, "w", encoding="utf-8") as fh:
                fh.write(content)
            written += 1
            print("wrote %s" % rel_path)

    if args.check:
        if mismatches:
            print("CHECK FAILED: %d file(s) differ" % mismatches, file=sys.stderr)
            return 1
        print("CHECK OK: %d file(s) match" % len(specs))
        return 0
    print("generated %d file(s)" % written)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
