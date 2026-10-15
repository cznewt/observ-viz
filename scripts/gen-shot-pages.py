#!/usr/bin/env python3
"""Generate the docs gallery from the dashboard screenshots (docs/shots).

The shots come from `just docs-shots` (scripts/shots.py against a live
Grafana) and live on the orphan `docs-shots` branch; the docs workflow unpacks
that branch into docs/shots and runs this before `mkdocs build`. Writes:
  docs/dashboards/index.md       every board, grouped by Grafana folder
  docs/dashboards/<uid>.md       one page per board: every tab rendered (a
                                 placeholder for an observ-libs board the docs
                                 Grafana does not have, so its page link works)
  docs/visualizations/index.md   the chart types (reference boards, folder Panels)
  docs/visualizations/<uid>.md   one page per chart type board
Without docs/shots/manifest.json the index pages say so and every board gets a
placeholder page.
"""
import collections
import glob
import json
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DOCS = os.path.join(ROOT, 'docs')
SHOTS = os.path.join(DOCS, 'shots')
PANELS_FOLDER = 'Panels'


def lib_pages():
    """uid -> (page file name, library title) from docs/observ-libs."""
    out = {}
    for f in sorted(glob.glob(os.path.join(DOCS, 'observ-libs', '*.md'))):
        text = open(f).read()
        m = re.search(r'Dashboard uid `([^`]+)`', text)
        if m:
            title = text.splitlines()[0].lstrip('# ').strip()
            out[m.group(1)] = (os.path.basename(f), title)
    return out


def write(path, lines):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w') as f:
        f.write('\n'.join(lines) + '\n')


def board_page(b, libs, rendered, grafana, masked=False):
    lines = [f'# {b["title"]}', '']
    meta = [f'uid `{b["uid"]}`']
    if b['uid'] in libs:
        meta.append(f'library: [{libs[b["uid"]][1]}](../observ-libs/{libs[b["uid"]][0]})')
    if b.get('folder'):
        meta.append(f'folder: {b["folder"]}')
    lines += [' · '.join(meta) + '.', '',
              f'Rendered from {grafana} on {rendered}: each tab as Grafana draws it with that '
              'Grafana\'s data, so a panel without data there shows "No data"'
              + ('; log lines are masked.' if masked else '.'), '']
    for t in b['tabs']:
        if len(b['tabs']) > 1:
            lines += [f'## {t["title"]}', '']
        if t.get('loading'):
            lines += ['*Some queries were still running when this was captured, so a panel may be empty.*', '']
        lines += [f'![{b["title"]} - {t["title"]}](../shots/{t["file"]})', '']
    return lines


def main():
    libs = lib_pages()
    manifest_path = os.path.join(SHOTS, 'manifest.json')
    manifest = json.load(open(manifest_path)) if os.path.exists(manifest_path) else {'boards': [], 'grafana': '', 'rendered': ''}
    grafana, rendered = manifest.get('grafana', ''), manifest.get('rendered', '')
    boards = [b for b in manifest['boards'] if b.get('tabs')]
    charts = [b for b in boards if b.get('folder') == PANELS_FOLDER]
    dashboards = [b for b in boards if b.get('folder') != PANELS_FOLDER]

    for b in dashboards:
        write(os.path.join(DOCS, 'dashboards', b['uid'] + '.md'), board_page(b, libs, rendered, grafana, manifest.get('logsMasked', False)))
    for b in charts:
        write(os.path.join(DOCS, 'visualizations', b['uid'] + '.md'), board_page(b, libs, rendered, grafana, manifest.get('logsMasked', False)))
    done = {b['uid'] for b in boards}
    missing = sorted((uid for uid in libs if uid not in done), key=lambda u: libs[u][1].lower())
    for uid in missing:
        page, title = libs[uid]
        write(os.path.join(DOCS, 'dashboards', uid + '.md'), [
            f'# {title}', '',
            f'uid `{uid}` · library: [{title}](../observ-libs/{page}).', '',
            'Not rendered: the docs Grafana' + (f' ({grafana})' if grafana else '') + ' does not have this board.', ''])

    # Dashboards index, grouped by folder
    idx = ['# Dashboards', '']
    if boards:
        idx += [f'Every observ-viz board on {grafana}, each tab rendered with its data ({rendered}). '
                'Refresh with `just docs-shots` + `just docs-shots-publish`.', '']
    else:
        idx += ['No screenshots yet: run `just docs-shots` and `just docs-shots-publish`.', '']
    by_folder = collections.defaultdict(list)
    for b in dashboards:
        by_folder[b.get('folder') or 'General'].append(b)
    for folder in sorted(by_folder, key=str.lower):
        idx += [f'## {folder}', '', '| Board | Tabs | Library |', '| --- | --- | --- |']
        for b in sorted(by_folder[folder], key=lambda x: x['title'].lower()):
            lib = f'[{libs[b["uid"]][1]}](../observ-libs/{libs[b["uid"]][0]})' if b['uid'] in libs else ''
            idx.append(f'| [{b["title"]}]({b["uid"]}.md) | {len(b["tabs"])} | {lib} |')
        idx.append('')
    if missing:
        idx += ['## Not rendered', '', 'observ-libs boards the docs Grafana does not have:', '']
        idx += [f'- [{libs[u][1]}](../observ-libs/{libs[u][0]}) (`{u}`)' for u in missing]
        idx.append('')
    write(os.path.join(DOCS, 'dashboards', 'index.md'), idx)

    # Visualizations index
    vis = ['# Visualizations', '']
    if charts:
        vis += [f'Every chart-type reference board (folder {PANELS_FOLDER}) rendered on {grafana} ({rendered}); '
                'the examples run on Grafana\'s testdata datasource, so they look the same anywhere. '
                'The panel options themselves are on [Chart types](../panels.md).', '']
        vis += ['| Chart type | Board |', '| --- | --- |']
        vis += [f'| [{b["title"]}]({b["uid"]}.md) | `{b["uid"]}` |' for b in sorted(charts, key=lambda x: x['title'].lower())]
    else:
        vis += ['No screenshots yet: run `just docs-shots` and `just docs-shots-publish`.']
    write(os.path.join(DOCS, 'visualizations', 'index.md'), vis + [''])

    print(f'{len(dashboards)} dashboard pages, {len(charts)} visualization pages, {len(missing)} placeholders')


if __name__ == '__main__':
    main()
