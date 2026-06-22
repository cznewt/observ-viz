"""Parity test: regenerating every target must byte-match the committed gen/.

This is the guard that keeps the manifest the single source of truth: if anyone
hand-edits gen/ (or the emitter drifts), this fails. Run via `make gen-test` or
`pytest -q` from the generator/ dir.
"""
import os
import sys

try:
    import pytest
except ImportError:  # allow running as a plain script without pytest installed
    pytest = None

# Make the generator package importable when run as `python3 tests/test_parity.py`.
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from observ_viz_gen import generate

PKG_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REPO_ROOT = os.path.dirname(PKG_DIR)
GEN_ROOT = os.path.join(REPO_ROOT, "gen")

ALL_SPECS = generate.files_for("all")

_parametrize = (
    pytest.mark.parametrize("rel_path,emitter", ALL_SPECS, ids=[s[0] for s in ALL_SPECS])
    if pytest is not None
    else (lambda fn: fn)
)


@_parametrize
def test_generated_matches_committed(rel_path, emitter):
    dest = os.path.join(GEN_ROOT, rel_path)
    assert os.path.exists(dest), "committed file missing: %s" % rel_path
    with open(dest, "r", encoding="utf-8") as fh:
        committed = fh.read()
    assert emitter() == committed, "generated output drifted from %s" % rel_path


def test_every_committed_file_is_generated():
    """No committed gen/ file is left unaccounted for by the manifest."""
    generated = {p for p, _ in ALL_SPECS}
    on_disk = set()
    for dirpath, _dirs, files in os.walk(GEN_ROOT):
        for fn in files:
            full = os.path.join(dirpath, fn)
            on_disk.add(os.path.relpath(full, GEN_ROOT))
    assert on_disk == generated, (
        "mismatch between committed files and generated set:\n"
        "  only on disk: %s\n  only generated: %s"
        % (sorted(on_disk - generated), sorted(generated - on_disk))
    )


def _run_as_script():
    """Plain-script fallback (no pytest): run every parity assertion."""
    failures = 0
    for rel_path, emitter in ALL_SPECS:
        try:
            test_generated_matches_committed(rel_path, emitter)
            print("OK   %s" % rel_path)
        except AssertionError as exc:
            failures += 1
            print("FAIL %s: %s" % (rel_path, exc))
    try:
        test_every_committed_file_is_generated()
        print("OK   <file-set coverage>")
    except AssertionError as exc:
        failures += 1
        print("FAIL <file-set coverage>: %s" % exc)
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(_run_as_script())
