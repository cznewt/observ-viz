#!/usr/bin/env python3
"""Run every panel query of a Grafana board the way the board would (the board-verify skill).

Resolves the board's variables (datasource, query, custom, constant), honours
the show/hide conditions on tabs, rows and panels, runs each visible panel's
queries through /api/ds/query and reports, per tab and row, which panels
return data, which come back empty, which fail and which are slow.  Works on
schema v2 boards (observ-viz) and on v1 boards (upstream mixins).

  board_check.py UID [--var NAME=VALUE[,VALUE]] [--from now-6h] [--to now]
                     [--tab TITLE] [--hidden] [--jobs 4] [--slow 5] [--json]

Needs ovq.py from the telemetry-query skill next to this skill
(skills/telemetry-query/scripts); GRAFANA_URL / GRAFANA_TOKEN as for ovq.py.
Exit status: 0 = no query failed, 1 = some query failed (or, with --strict,
a visible panel came back empty), 2 = could not check at all.
"""
import argparse
import concurrent.futures
import json
import os
import re
import sys
import time

sys.path.insert(0, os.path.join(os.path.dirname(os.path.realpath(__file__)), '..', '..', 'telemetry-query', 'scripts'))
import ovq  # noqa: E402

VAR_RE = re.compile(r'\$(\w+)|\$\{(\w+)(?::(\w+))?\}|\[\[(\w+)(?::(\w+))?\]\]')
REGEX_SPECIAL = re.compile(r'([\\^$.|?*+()\[\]{}])')
NO_QUERY_PANELS = {'text', 'news', 'dashlist', 'welcome', 'gettingstarted', 'alertlist', 'annolist'}


class Var:
    def __init__(self, name, kind, multi=False, include_all=False, all_value=None):
        self.name, self.kind = name, kind
        self.multi, self.include_all, self.all_value = multi, include_all, all_value
        self.options, self.values, self.is_all, self.note = [], [], False, ''

    def describe(self):
        if self.kind == 'DatasourceVariable':
            return f'{self.name}={self.values[0] if self.values else "-"}' + (f' ({self.note})' if self.note else '')
        if self.is_all:
            return f'{self.name}=All[{len(self.options)}]'
        shown = ','.join(self.values) if self.values else '""'
        return f'{self.name}={ovq.cut(shown, 60)}' + (f' ({self.note})' if self.note else '')


def regex_escape(value):
    return REGEX_SPECIAL.sub(r'\\\\\1', value)


def render(var, fmt):
    values = var.options if var.is_all and not var.all_value else var.values
    if var.is_all and var.all_value and fmt in (None, 'regex', 'pipe', 'raw'):
        return var.all_value
    if fmt == 'csv' or (fmt == 'raw' and len(values) > 1):
        return ','.join(values)
    if fmt == 'pipe':
        return '|'.join(values)
    if fmt == 'json':
        return json.dumps(values)
    if fmt in ('text', 'raw'):
        return values[0] if values else ''
    if fmt == 'doublequote':
        return ','.join('"' + v + '"' for v in values)
    if fmt == 'singlequote':
        return ','.join("'" + v + "'" for v in values)
    if fmt == 'glob':
        return '{' + ','.join(values) + '}' if len(values) > 1 else (values[0] if values else '')
    # the Prometheus / Loki default: a regex alternation for multi-value and All
    if not var.multi and not var.include_all:
        return values[0] if values else ''
    escaped = [regex_escape(v) for v in values]
    return escaped[0] if len(escaped) == 1 else '(' + '|'.join(escaped) + ')' if escaped else ''


def interpolate(value, variables):
    if isinstance(value, str):
        def sub(m):
            name = m.group(1) or m.group(2) or m.group(4)
            fmt = m.group(3) or m.group(5)
            var = variables.get(name)
            return m.group(0) if var is None else render(var, fmt)
        return VAR_RE.sub(sub, value)
    if isinstance(value, list):
        return [interpolate(v, variables) for v in value]
    if isinstance(value, dict):
        return {k: interpolate(v, variables) for k, v in value.items()}
    return value


def apply_regex(options, regex):
    if not regex:
        return options
    rx = re.compile(regex.strip('/').replace('(?<', '(?P<') if regex.startswith('/') else regex)
    out = []
    for o in options:
        m = rx.search(o)
        if m:
            groups = m.groupdict()
            out.append(groups.get('value') or groups.get('text') or (m.group(1) if m.groups() else o))
    return list(dict.fromkeys(out))


def prometheus_options(gf, ds, query, start, end):
    """The classic Prometheus variable query forms Grafana understands."""
    q = query.strip()
    window = {'start': start, 'end': end}
    m = re.fullmatch(r'label_values\((?:(.*),\s*)?(\w+)\)', q, re.S)
    if m:
        params = dict(window, **({'match[]': m.group(1)} if m.group(1) else {}))
        return gf.proxy(ds, f'api/v1/label/{m.group(2)}/values', params).get('data') or []
    m = re.fullmatch(r'label_names\((.*)\)', q, re.S)
    if m:
        params = dict(window, **({'match[]': m.group(1)} if m.group(1).strip() else {}))
        return gf.proxy(ds, 'api/v1/labels', params).get('data') or []
    m = re.fullmatch(r'metrics\((.*)\)', q, re.S)
    if m:
        names = gf.proxy(ds, 'api/v1/label/__name__/values', window).get('data') or []
        return [n for n in names if re.search(m.group(1), n)]
    m = re.fullmatch(r'query_result\((.*)\)', q, re.S)
    if m:
        res = gf.proxy(ds, 'api/v1/query', {'query': m.group(1), 'time': end})['data']['result']
        return [s['metric'].get('__name__', '') + ovq.labelset({k: v for k, v in s['metric'].items() if k != '__name__'}).replace(', ', ',')
                + f' {s["value"][1]} {int(float(s["value"][0]) * 1000)}' for s in res]
    if q:
        names = gf.proxy(ds, 'api/v1/series', {'match[]': q, **window}).get('data') or []
        return [s.get('__name__', '') for s in names]
    return []


def loki_options(gf, ds, query, start, end):
    m = re.fullmatch(r'label_values\((?:(.*),\s*)?(\w+)\)', query.strip(), re.S)
    if not m:
        return []
    params = {'start': start * 10**9, 'end': end * 10**9}
    if m.group(1):
        params['query'] = m.group(1)
    return gf.proxy(ds, f'loki/api/v1/label/{m.group(2)}/values', params).get('data') or []


def pick_datasource(gf, plugin, wanted):
    pool = sorted((d for d in gf.datasources() if d['type'] == plugin), key=lambda d: d['name'].lower())
    if wanted:
        for d in pool:
            if wanted in (d['uid'], d['name']):
                return d, ''
    default = next((d for d in pool if d.get('isDefault')), None)
    if default:
        return default, 'the default datasource'
    if pool:
        return pool[0], 'first by name: the board saves none'
    return None, f'no {plugin} datasource'


def current_values(current):
    value = (current or {}).get('value')
    if value is None or value == '':
        return []
    return value if isinstance(value, list) else [value]


def resolve(gf, kind, spec, overrides, start, end):
    """Variables in board order (later ones can read earlier ones)."""
    variables, datasources = {}, {}
    for v in (spec.get('variables', []) if kind == 'v2' else spec.get('templating', {}).get('list', [])):
        s = v['spec'] if kind == 'v2' else v
        vkind = v['kind'] if kind == 'v2' else {'query': 'QueryVariable', 'custom': 'CustomVariable', 'datasource': 'DatasourceVariable',
                                                 'constant': 'ConstantVariable', 'textbox': 'TextVariable', 'interval': 'IntervalVariable'}.get(v.get('type'), v.get('type'))
        var = Var(s['name'], vkind, s.get('multi'), s.get('includeAll'), s.get('allValue'))
        variables[var.name] = var
        saved = current_values(s.get('current'))
        override = overrides.get(var.name)
        if vkind == 'DatasourceVariable':
            plugin = s.get('pluginId') or s.get('query')
            ds, var.note = pick_datasource(gf, plugin, override[0] if override else (saved[0] if saved else None))
            var.values = [ds['name']] if ds else []
            var.options = var.values
            if ds:
                datasources[var.name] = ds
            continue
        query = s.get('query')
        if vkind == 'QueryVariable':
            qspec = (query.get('spec') or {}) if isinstance(query, dict) else {'query': query}
            # boards converted from v1 keep the classic query string as __legacyStringValue
            classic = qspec.get('query') or qspec.get('expr') or qspec.get('__legacyStringValue') or ''
            dsref = ((query.get('datasource') or {}).get('name') or (query.get('datasource') or {}).get('uid')) if isinstance(query, dict) else None
            dsref = dsref or ((s.get('datasource') or {}).get('uid') if isinstance(s.get('datasource'), dict) else s.get('datasource'))
            ds = resolve_ds(gf, dsref, variables, datasources, (query.get('group') if isinstance(query, dict) else None) or 'prometheus')
            try:
                if ds is None:
                    raise ovq.GrafanaError('no datasource')
                fetch = loki_options if ds['type'] == 'loki' else prometheus_options
                var.options = apply_regex(fetch(gf, ds, interpolate(classic, variables), start, end), s.get('regex') or '')
            except (ovq.GrafanaError, re.error) as e:
                var.note = f'options failed: {ovq.cut(str(e), 80)}'
        elif vkind == 'CustomVariable':
            for part in re.split(r'(?<!\\),', query or ''):
                part = part.strip()
                var.options.append(part.split(' : ', 1)[1].strip() if ' : ' in part else part)
        elif vkind in ('ConstantVariable', 'TextVariable'):
            var.options = [query if isinstance(query, str) else (saved[0] if saved else '')]
        elif vkind == 'IntervalVariable':
            var.options = [o.strip() for o in (query or '').split(',') if o.strip()]
        else:
            var.note = 'not evaluated'
        chosen = override or saved
        if chosen in (['$__all'], ['All']) and var.include_all:
            var.is_all = True
        elif chosen and (not var.options or all(c in var.options for c in chosen) or vkind in ('TextVariable', 'ConstantVariable')):
            var.values = chosen
        elif var.include_all and not override:
            var.is_all = True
        elif var.options:
            var.values = [var.options[0]]
        if var.is_all:
            var.values = list(var.options)
        if not var.values and not var.is_all and vkind == 'QueryVariable' and not var.note:
            var.note = 'empty'
    return variables, datasources


def resolve_ds(gf, ref, variables, datasources, group):
    if not ref:
        return pick_datasource(gf, group, None)[0]
    m = VAR_RE.fullmatch(ref)
    if m:
        name = m.group(1) or m.group(2) or m.group(4)
        return datasources.get(name)
    try:
        return gf.ds(ref)
    except ovq.GrafanaError:
        return None


def holds(cond, variables, has_data=None):
    """Whether a conditionalRendering group shows its section; None = depends on data not known yet."""
    if not cond:
        return True
    spec = cond.get('spec') or {}
    results = []
    for item in spec.get('items', []):
        s = item.get('spec') or {}
        if item.get('kind') == 'ConditionalRenderingVariable':
            var = variables.get(s.get('variable'))
            values = (var.options if var.is_all else var.values) if var else []
            op, want = s.get('operator', 'equals'), str(s.get('value', ''))
            values = values or ['']
            if op == 'equals':
                results.append(any(v == want for v in values))
            elif op == 'notEquals':
                results.append(all(v != want for v in values))
            elif op == 'matches':
                results.append(any(re.search(want, v) for v in values))
            elif op == 'notMatches':
                results.append(not any(re.search(want, v) for v in values))
        elif item.get('kind') == 'ConditionalRenderingData':
            results.append(None if has_data is None else has_data == s.get('value', True))
    if not results:
        return True
    if None in results:
        return None
    ok = all(results) if spec.get('condition', 'and') == 'and' else any(results)
    return ok if spec.get('visibility', 'show') == 'show' else not ok


def panels_of(kind, spec):
    """[(path, name, title, panel type, [(refId, ds ref, group, query spec, hidden)])]."""
    out = []
    if kind == 'v2':
        for path, name in ovq.v2_layout(spec['layout']):
            el = spec['elements'].get(name, {})
            es = el.get('spec', {})
            viz = (es.get('vizConfig') or {}).get('group') or (es.get('vizConfig') or {}).get('kind') or el.get('kind', '')
            out.append((path, name, es.get('title', ''), viz if el.get('kind') == 'Panel' else el.get('kind', '?'), ovq.v2_queries(el)))
    else:
        for path, p in ovq.v1_panels(spec):
            ds = p.get('datasource')
            queries = []
            for t in p.get('targets', []):
                tds = t.get('datasource') or ds
                ref = tds.get('uid') if isinstance(tds, dict) else tds
                group = (tds.get('type') if isinstance(tds, dict) else None) or 'prometheus'
                queries.append((t.get('refId', 'A'), ref, group, {k: v for k, v in t.items() if k not in ('datasource', 'refId')}, t.get('hide', False)))
            out.append((path, str(p.get('id')), p.get('title', ''), p.get('type', ''), queries))
    return out


def run_panel(gf, panel, variables, datasources, start, end, interval_ms):
    path, name, title, viz, queries = panel
    batch, skipped = [], []
    for ref, dsref, group, qspec, hidden in queries:
        if hidden:
            continue
        ds = resolve_ds(gf, dsref, variables, datasources, group)
        if ds is None:
            skipped.append(f'{ref}: datasource {dsref} not resolved')
            continue
        if ds['type'] in ('datasource', 'grafana') or ds.get('uid') in ('-- Dashboard --', 'grafana'):
            skipped.append(f'{ref}: reuses another panel')
            continue
        q = interpolate(dict(qspec), variables)
        q.update({'refId': ref, 'datasource': {'uid': ds['uid'], 'type': ds['type']},
                  'intervalMs': interval_ms, 'maxDataPoints': 300})
        batch.append(q)
    result = {'path': [f'{k} {t}'.strip() for k, t, _ in path if k != 'item'], 'name': name, 'title': title, 'type': viz,
              'queries': {}, 'skipped': skipped, 'seconds': 0.0}
    if not batch:
        result['status'] = 'no queries' if not skipped else 'skipped'
        return result
    t0 = time.time()
    try:
        res = gf.query(batch, start, end)
    except ovq.GrafanaError as e:
        res = {q['refId']: {'error': str(e)} for q in batch}
    result['seconds'] = round(time.time() - t0, 2)
    for q in batch:
        r = res.get(q['refId'], {})
        if r.get('error'):
            result['queries'][q['refId']] = {'status': 'error', 'error': ovq.cut(r['error'], 200)}
        else:
            series = sum(1 for _, pts in ovq.numeric_series({'x': r}) if any(v is not None for _, v in pts))
            rows = sum(max((len(v) for v in fr.get('data', {}).get('values', []) or [[]]), default=0) for fr in r.get('frames', []))
            result['queries'][q['refId']] = {'status': 'ok' if ovq.has_data(r) else 'empty', 'series': series, 'rows': rows}
    states = {q['status'] for q in result['queries'].values()}
    result['status'] = 'error' if 'error' in states else 'ok' if 'ok' in states else 'empty'
    return result


def main(argv=None):
    p = argparse.ArgumentParser(prog='board_check.py', description=__doc__.split('\n')[0])
    p.add_argument('uid')
    p.add_argument('--env', '--env-file', dest='env_file', help='as for ovq.py: a KEY=VALUE file or a profile name')
    p.add_argument('--var', action='append', default=[], help='NAME=VALUE[,VALUE] or NAME=All (repeatable)')
    p.add_argument('--from', dest='start', help='default: the board time range')
    p.add_argument('--to', dest='end')
    p.add_argument('--tab', help='only tabs (or top-level rows) whose title matches this regex')
    p.add_argument('--hidden', action='store_true', help='also run sections hidden by their conditions')
    p.add_argument('--jobs', type=int, default=4, help='panels queried in parallel (keep it small on a busy stack)')
    p.add_argument('--slow', type=float, default=5.0, help='seconds after which a panel counts as slow')
    p.add_argument('--strict', action='store_true', help='exit 1 when a visible panel is empty')
    p.add_argument('--json', action='store_true')
    a = p.parse_args(argv)
    try:
        if a.env_file:
            ovq.load_env(a.env_file)
        gf = ovq.Grafana()
        kind, spec, meta = gf.board(a.uid)
        settings = spec.get('timeSettings') or spec.get('time') or {}
        start, end = a.start or settings.get('from') or 'now-1h', a.end or settings.get('to') or 'now'
        span = ovq.seconds(start[4:]) if start.startswith('now-') and end == 'now' else 3600
        now = int(time.time())
        overrides = {k: v.split(',') for k, v in (kv.split('=', 1) for kv in a.var)}
        variables, datasources = resolve(gf, kind, spec, overrides, int(now - span), now)
    except ovq.GrafanaError as e:
        print(f'error: {e}', file=sys.stderr)
        return 2
    panels = panels_of(kind, spec)
    if a.tab:
        panels = [pn for pn in panels if pn[0] and re.search(a.tab, pn[0][0][1], re.I)]
    todo, hidden = [], []
    for pn in panels:
        verdicts = [holds(cond, variables) for _, _, cond in pn[0]]
        if False in verdicts and not a.hidden:
            why = next(ovq.condition_text(cond) for (_, _, cond), v in zip(pn[0], verdicts) if v is False)
            hidden.append((pn, why))
        else:
            todo.append(pn)
    interval_ms = int(max(15, span / 300) * 1000)
    with concurrent.futures.ThreadPoolExecutor(max_workers=max(1, a.jobs)) as pool:
        results = list(pool.map(lambda pn: run_panel(gf, pn, variables, datasources, start, end, interval_ms), todo))
    # sections shown only when they have data: empty ones are hidden, not broken
    for pn, r in zip(todo, results):
        for _, _, cond in pn[0]:
            scope = [rr for pp, rr in zip(todo, results) if any(c is cond for _, _, c in pp[0])]
            if holds(cond, variables, any(rr['status'] == 'ok' for rr in scope)) is False and r['status'] == 'empty':
                r['status'] = 'hidden (no data)'
    for pn, why in hidden:
        results.append({'path': [f'{k} {t}'.strip() for k, t, _ in pn[0] if k != 'item'], 'name': pn[1], 'title': pn[2],
                        'type': pn[3], 'status': 'hidden', 'why': why, 'queries': {}, 'seconds': 0.0})
    order = {id(pn): i for i, pn in enumerate(panels)}
    results.sort(key=lambda r: next((order[id(pn)] for pn in panels if pn[1] == r['name'] and [f'{k} {t}'.strip() for k, t, _ in pn[0] if k != 'item'] == r['path']), 0))
    if a.json:
        print(json.dumps({'uid': a.uid, 'title': spec.get('title'), 'from': start, 'to': end,
                          'variables': {n: {'values': v.values, 'all': v.is_all, 'options': len(v.options), 'note': v.note} for n, v in variables.items()},
                          'panels': results}, indent=1))
    else:
        print(f'{spec.get("title")}  uid={a.uid}  schema={kind}  {start} .. {end}')
        print('variables: ' + ' · '.join(v.describe() for v in variables.values()))
        last = None
        col = min(max((len(r['name']) for r in results), default=10), 40)
        for r in results:
            if r['path'] != last:
                for depth, part in enumerate(r['path']):
                    if last is None or last[:depth + 1] != r['path'][:depth + 1]:
                        print(f'{"  " * depth}[{part}]')
                last = r['path']
            ind = '  ' * len(r['path'])
            detail = ' '.join(f'{ref}:{q["status"] if q["status"] != "ok" else (q["series"] or q["rows"])}' for ref, q in r['queries'].items())
            errors = [f'{ref}: {q["error"]}' for ref, q in r['queries'].items() if q['status'] == 'error']
            slow = f'  SLOW {r["seconds"]} s' if r['seconds'] >= a.slow else ''
            status = r['status'].upper() if r['status'] in ('error', 'empty') else r['status']
            print(f'{ind}{ovq.cut(r["name"], col):{col}} {status:9} {ovq.cut(r["title"], 40):42} {detail}{slow}' + (f'  ({r["why"]})' if r.get('why') else ''))
            for e in errors + r.get('skipped', []):
                print(f'{ind}    {e}')
        counts = {}
        for r in results:
            counts[r['status']] = counts.get(r['status'], 0) + 1
        slow = [r for r in results if r['seconds'] >= a.slow]
        print('summary: ' + ', '.join(f'{n} {s}' for s, n in sorted(counts.items())) + (f'; {len(slow)} slow (>= {a.slow} s)' if slow else ''))
    failed = any(r['status'] == 'error' for r in results) or (a.strict and any(r['status'] == 'empty' for r in results))
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main())
