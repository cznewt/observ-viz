#!/usr/bin/env python3
"""Look things up in the observ-viz catalog (the observ-viz-catalog skill).

docs/boards.json describes every library and mixin board of observ-viz: its
board uid and Grafana folder, tabs, signals (name, unit, PromQL), alerting
rules and recording rules.  docs/exporters/ maps metrics to the exporter and
collector that produce them.  This answers "which board / alert / signal
covers X" without reading the Jsonnet.  Python 3.8+, standard library only.

  catalog.py libs   [--grep REGEX]       every library: uid, folder, counts
  catalog.py lib    NAME                 one library in full
  catalog.py search TERM                 anything matching, grouped by library
  catalog.py metric NAME                 who uses a metric, and who exports it
  catalog.py alert  NAME                 an alerting rule, its library and board
  catalog.py board  UID                  which library or reference set a board uid comes from

The catalog is read from --boards, $OBSERV_VIZ_BOARDS, the observ-viz checkout
this script sits in, or (--fetch, or when none of those exists) GitHub main.
"""
import argparse
import json
import os
import re
import sys
import urllib.request

HERE = os.path.dirname(os.path.realpath(__file__))
REPO = os.path.normpath(os.path.join(HERE, '..', '..', '..'))
RAW = 'https://raw.githubusercontent.com/cznewt/observ-viz/main/'
CACHE = os.path.join(os.path.expanduser('~'), '.cache', 'observ-viz')


def fetch(rel):
    path = os.path.join(CACHE, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with urllib.request.urlopen(RAW + rel, timeout=60) as resp, open(path, 'wb') as out:
        out.write(resp.read())
    print(f'(fetched {RAW + rel})', file=sys.stderr)
    return path


def load(a):
    candidates = [a.boards, os.environ.get('OBSERV_VIZ_BOARDS'), os.path.join(REPO, 'docs', 'boards.json')]
    path = next((p for p in candidates if p and os.path.exists(p)), None)
    if a.fetch or path is None:
        path = fetch('docs/boards.json')
    docs = os.path.dirname(path)
    return json.load(open(path)), docs


def folder(entry):
    return '/'.join(entry.get('folder') or []) or 'General'


def token_re(name):
    return re.compile(r'(?<![A-Za-z0-9_:])' + re.escape(name) + r'(?![A-Za-z0-9_:])')


def cut(text, width):
    text = ' '.join(str(text).split())
    return text if width <= 0 or len(text) <= width else text[:width - 1] + '…'


def txt(value):
    """The catalog's text fields; a broken rule can carry a non-string expression."""
    return value if isinstance(value, str) else '' if value is None else f'<not a string: {json.dumps(value)}>'


def find_lib(libs, name):
    if name in libs:
        return name
    hits = [k for k in libs if k.lower() == name.lower()] or \
           [k for k in libs if name.lower() in k.lower() or name == libs[k].get('uid')]
    if len(hits) == 1:
        return hits[0]
    if not hits:
        raise SystemExit(f'no library matches {name!r}; try `catalog.py libs`')
    raise SystemExit(f'{name!r} matches {len(hits)} libraries: {", ".join(sorted(hits))}')


def cmd_libs(data, docs, a):
    out = []
    for name, lib in sorted(data['libs'].items()):
        line = (f'{name:34} uid={lib.get("uid", "-"):38} {folder(lib)}  signals={len(lib.get("signals", []))} '
                f'alerts={len(lib.get("alerts", []))} records={len(lib.get("records", []))}')
        if not a.grep or re.search(a.grep, line + ' ' + lib.get('title', '') + ' ' + lib.get('description', ''), re.I):
            out.append(line)
    return [f'# {len(out)} libraries'] + out


def cmd_lib(data, docs, a):
    name = find_lib(data['libs'], a.name)
    lib = data['libs'][name]
    if a.json:
        return lib
    w = 0 if a.full else a.width
    out = [f'{name}: {lib.get("title")}', f'board uid: {lib.get("uid")}   folder: {folder(lib)}'
           + (f'   wraps whitebox board: {lib["whitebox"]}' if lib.get('whitebox') else ''),
           cut(lib.get('description', ''), 0) or '(no description)']
    if lib.get('groups'):
        out += ['', 'tabs / rows (element names):'] + [f'  {g["t"]}: {", ".join(g.get("els", []))}' for g in lib['groups']]
    if lib.get('signals'):
        out += ['', f'signals ({len(lib["signals"])}):'] + [f'  {s["n"]} [{s.get("u", "")}]  {cut(txt(s.get("e")), w)}' for s in lib['signals']]
    if lib.get('alerts'):
        out += ['', f'alerts ({len(lib["alerts"])}):']
        for r in lib['alerts']:
            out += [f'  {r["n"]}  {r.get("sev", "-")}  for {r.get("f") or "-"}  - {txt(r.get("s"))}', f'      {cut(txt(r.get("e")), w)}']
    if lib.get('records'):
        out += ['', f'recording rules ({len(lib["records"])}):'] + [f'  {r["n"]} = {cut(txt(r.get("e")), w)}' for r in lib['records']]
    if lib.get('queries'):
        out += ['', 'log queries:'] + [f'  {q["n"]}: {cut(txt(q.get("e")), w)}' for q in lib['queries']]
    return out


def cmd_search(data, docs, a):
    rx = re.compile(a.term, re.I)
    w = a.width
    out, n = [], 0
    for name, lib in sorted(data['libs'].items()):
        hits = []
        if rx.search(name) or rx.search(lib.get('title', '')) or rx.search(lib.get('description', '')):
            hits.append(f'  library: {lib.get("title")} - {cut(lib.get("description", ""), w)}')
        hits += [f'  signal {s["n"]}: {cut(txt(s.get("e")), w)}' for s in lib.get('signals', []) if rx.search(s['n']) or rx.search(txt(s.get('e')))]
        hits += [f'  alert {r["n"]} ({r.get("sev", "-")}): {cut(txt(r.get("s")) or txt(r.get("e")), w)}' for r in lib.get('alerts', [])
                 if rx.search(r['n']) or rx.search(txt(r.get('e'))) or rx.search(txt(r.get('s')))]
        hits += [f'  record {r["n"]}' for r in lib.get('records', []) if rx.search(r['n']) or rx.search(txt(r.get('e')))]
        hits += [f'  tab {g["t"]}' for g in lib.get('groups', []) if rx.search(g['t'])]
        if hits:
            n += len(hits)
            out += [f'{name}  (board {lib.get("uid")}, {folder(lib)})'] + hits[:a.per_lib] + ([f'  … {len(hits) - a.per_lib} more'] if len(hits) > a.per_lib else [])
    for uid, b in sorted(data.get('boards', {}).items()):
        if rx.search(uid) or rx.search(b.get('title', '')) or rx.search(b.get('description', '')):
            n += 1
            out += [f'board {uid}  ({b.get("source")} set, {folder(b)}): {b.get("title")} - {cut(b.get("description", ""), w)}']
    return [f'# {n} matches for /{a.term}/'] + out


def exporter_docs(docs):
    """[(exporter, collector, exact metric names, patterns)] from docs/exporters/*.md."""
    out = []
    root = os.path.join(docs, 'exporters')
    if not os.path.isdir(root):
        return out
    for fn in sorted(os.listdir(root)):
        if not fn.endswith('.md') or fn in ('index.md', 'signals.md'):
            continue
        exporter, collector, names, patterns = fn[:-3], '', set(), []
        for line in open(os.path.join(root, fn)):
            if line.startswith('# '):
                exporter = line[2:].strip()
            elif line.startswith('## '):
                if collector:
                    out.append((exporter, collector, names, patterns))
                collector, names, patterns = line[3:].strip(), set(), []
            elif line.startswith('- **patterns**:'):
                patterns = re.findall(r'`([^`]+)`', line)
            elif re.match(r'- `[A-Za-z_:][A-Za-z0-9_:]*`\s*$', line):
                names.add(line.strip()[3:-1])
        if collector:
            out.append((exporter, collector, names, patterns))
    return out


def cmd_metric(data, docs, a):
    rx = token_re(a.name)
    out = []
    for name, lib in sorted(data['libs'].items()):
        hits = [f'signal {s["n"]}' for s in lib.get('signals', []) if rx.search(txt(s.get('e')))]
        hits += [f'alert {r["n"]}' for r in lib.get('alerts', []) if rx.search(txt(r.get('e')))]
        hits += [f'record {r["n"]}' for r in lib.get('records', []) if rx.search(txt(r.get('e')))]
        if hits:
            out.append(f'  {name} (board {lib.get("uid")}): {", ".join(hits)}')
    seen, matched = [], []
    for exporter, collector, names, patterns in exporter_docs(docs):
        if a.name in names:
            seen.append(f'  {exporter} / {collector} (seen live)')
        elif any(re.fullmatch(p, a.name) for p in patterns):
            matched.append(f'  {exporter} / {collector} (matches its patterns)')
    sources = seen or matched
    return ([f'# {a.name}: used by {len(out)} libraries'] + out
            + ['', '# exported by:'] + (sources or ['  not in docs/exporters - an application metric, or not inventoried']))


def runbook_rows(docs, alert):
    root = os.path.join(docs, 'runbooks')
    if not os.path.isdir(root):
        return []
    return [f'  docs/runbooks/{fn}: {cut(line, 220)}' for fn in sorted(os.listdir(root)) if fn.endswith('.md')
            for line in open(os.path.join(root, fn)) if f'`{alert}`' in line]


def cmd_alert(data, docs, a):
    exact, partial = [], []
    for name, lib in data['libs'].items():
        for r in lib.get('alerts', []):
            if r['n'] == a.name:
                exact.append((name, lib, r))
            elif a.name.lower() in r['n'].lower():
                partial.append((name, lib, r))
    hits = exact or partial
    if not hits:
        return [f'no observ-viz alert named like {a.name!r} - it may come from an upstream mixin (kubernetes-mixin, Pyrra, ...)']
    out = []
    for name, lib, r in sorted(hits, key=lambda h: (h[2]['n'], h[0])):
        out += [f'{r["n"]}  severity={r.get("sev", "-")}  for={r.get("f") or "-"}',
                f'  library: {name}   board: {lib.get("uid")} ({folder(lib)}) - its Runbooks tab (variable signals=Show) carries the runbook',
                f'  summary: {txt(r.get("s"))}', f'  description: {txt(r.get("d"))}', f'  expr: {txt(r.get("e"))}']
        out += runbook_rows(docs, r['n'])
        out.append('')
    return out


def cmd_board(data, docs, a):
    out = [f'library {name}: {lib.get("title")} ({folder(lib)})' for name, lib in data['libs'].items() if lib.get('uid') == a.uid]
    out += [f'library {name} wraps it as its whitebox board' for name, lib in data['libs'].items() if lib.get('whitebox') == a.uid]
    b = data.get('boards', {}).get(a.uid)
    if b:
        out.append(f'{b.get("source")} board: {b.get("title")} ({folder(b)}) - {b.get("description", "")}')
    return out or [f'{a.uid} is not an observ-viz board (an upstream mixin board, or hand-made)']


COMMANDS = {'libs': cmd_libs, 'lib': cmd_lib, 'search': cmd_search, 'metric': cmd_metric, 'alert': cmd_alert, 'board': cmd_board}


def main(argv=None):
    p = argparse.ArgumentParser(prog='catalog.py', description=__doc__.split('\n')[0])
    p.add_argument('--boards', help='path to docs/boards.json')
    p.add_argument('--fetch', action='store_true', help='read the catalog from GitHub main')
    common = argparse.ArgumentParser(add_help=False)
    common.add_argument('--width', type=int, default=180, help='cut long text (0 = never)')
    common.add_argument('--json', action='store_true')
    sub = p.add_subparsers(dest='command', required=True)
    sub.add_parser('libs', parents=[common]).add_argument('--grep')
    s = sub.add_parser('lib', parents=[common])
    s.add_argument('name')
    s.add_argument('--full', action='store_true', help='do not cut expressions')
    s = sub.add_parser('search', parents=[common])
    s.add_argument('term', help='regex, case-insensitive')
    s.add_argument('--per-lib', type=int, default=8)
    sub.add_parser('metric', parents=[common]).add_argument('name')
    sub.add_parser('alert', parents=[common]).add_argument('name')
    sub.add_parser('board', parents=[common]).add_argument('uid')
    a = p.parse_args(argv)
    data, docs = load(a)
    out = COMMANDS[a.command](data, docs, a)
    print(json.dumps(out, indent=1) if isinstance(out, dict) else '\n'.join(out))
    return 0


if __name__ == '__main__':
    sys.exit(main())
